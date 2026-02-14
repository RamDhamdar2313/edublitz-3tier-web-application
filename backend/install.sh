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

# ----------- Install Dependencies -----------
echo "Installing dependencies..."
sudo yum update -y
sudo yum install -y java-11-amazon-corretto-devel wget
sudo dnf install -y mariadb105

# ----------- Download JDBC Driver -----------
cd "$INSTALL_DIR"
if [ ! -f "$MYSQL_JAR" ]; then
  echo "Downloading MySQL JDBC driver..."
  wget -q "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/$MYSQL_JAR"
fi

# ----------- Compile Application -----------
if [ ! -f App.java ]; then
  echo "ERROR: App.java not found in $INSTALL_DIR"
  exit 1
fi

echo "Compiling App.java..."
javac -cp ".:${MYSQL_JAR}" App.java

if [ ! -f App.class ]; then
  echo "ERROR: Compilation failed. App.class not created."
  exit 1
fi

echo "Compilation successful."

# ----------- Test RDS Connectivity -----------
echo "Testing RDS connection..."
if ! mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
  echo "ERROR: Cannot connect to RDS. Check credentials or security group."
  exit 1
fi

echo "RDS connection successful."

# ----------- Stop Existing Service -----------
sudo systemctl stop edublitz-backend 2>/dev/null || true

# ----------- Create systemd Service -----------
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

# ----------- Start Service -----------
sudo systemctl daemon-reload
sudo systemctl enable edublitz-backend
sudo systemctl restart edublitz-backend

echo ""
echo "Backend started."
echo "Check status:"
echo "  sudo systemctl status edublitz-backend"
echo ""
echo "Test locally:"
echo "  curl http://localhost:8080/"
echo ""
echo "=== Install Complete ==="
