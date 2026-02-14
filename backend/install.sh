#!/bin/bash
set -e

echo "=== EduBlitz 3-Tier - Installing Backend ==="

# ----------- Parse Arguments -----------
while [[ $# -gt 0 ]]; do
  case $1 in
    --db-host)
      DB_HOST="$2"
      shift 2
      ;;
    --db-user)
      DB_USER="$2"
      shift 2
      ;;
    --db-password)
      DB_PASSWORD="$2"
      shift 2
      ;;
    --db-name)
      DB_NAME="$2"
      shift 2
      ;;
    --db-port)
      DB_PORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ----------- Validation -----------
if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASSWORD" ]]; then
  echo "ERROR: --db-host, --db-user and --db-password are required"
  exit 1
fi

DB_NAME=${DB_NAME:-edublitz}
DB_PORT=${DB_PORT:-3306}

INSTALL_DIR="/home/ec2-user"
MYSQL_JAR="mysql-connector-j-8.0.33.jar"

# ----------- Install Java -----------
echo "Installing Java..."
sudo yum update -y
sudo yum install -y java-11-amazon-corretto-devel wget

# ----------- Install MySQL client -----------
sudo yum install -y mariadb || true

# ----------- Download JDBC -----------
cd "$INSTALL_DIR"
if [ ! -f "$MYSQL_JAR" ]; then
  wget -q "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar" -O "$MYSQL_JAR"
fi

# ----------- Compile -----------
if [ ! -f App.java ]; then
  echo "App.java not found."
  exit 1
fi

javac -cp ".:${MYSQL_JAR}" App.java
echo "Compilation successful."

# ----------- Create systemd service -----------
sudo tee /etc/systemd/system/edublitz-backend.service > /dev/null << SVC
[Unit]
Description=EduBlitz 3-Tier Backend
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$INSTALL_DIR
Environment=DB_HOST=$DB_HOST
Environment=DB_PORT=$DB_PORT
Environment=DB_NAME=$DB_NAME
Environment=DB_USER=$DB_USER
Environment=DB_PASSWORD=$DB_PASSWORD
ExecStart=/usr/bin/java -cp "$INSTALL_DIR:$INSTALL_DIR/$MYSQL_JAR" App
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

sudo systemctl daemon-reload
sudo systemctl enable edublitz-backend
sudo systemctl restart edublitz-backend

echo "Backend started via systemd."

echo "Test using:"
echo "curl -X POST http://localhost:8080/enquiry -d 'name=Test&email=test@test.com&course=AWS&message=Hello'"
echo "=== Install Complete ==="
