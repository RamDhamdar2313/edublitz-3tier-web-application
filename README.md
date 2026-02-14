# EduBlitz 3-Tier Web Application

A beginner-friendly AWS project: a **3-tier web application** where students submit an **enquiry form** and data is stored in **Amazon RDS MySQL**.

## Repository

- **GitHub:** [https://github.com/atulyw/edublitz-3tier-web-application](https://github.com/atulyw/edublitz-3tier-web-application)
- **Clone:**
  ```bash
  git clone https://github.com/atulyw/edublitz-3tier-web-application.git
  cd edublitz-3tier-web-application
  ```

---

## Architecture Overview

```
User → CloudFront → S3 (HTML Form)
HTML Form → EC2 Java API → RDS MySQL Database
```

| Tier | AWS Service | Role |
|------|-------------|------|
| **Web Tier** | CloudFront + S3 | Serves frontend (enquiry form) |
| **App Tier** | EC2 | Java backend API on port 8080 |
| **Database Tier** | RDS MySQL | Stores enquiries in private subnet |

---

## Project Folder Structure

```
edublitz-3tier-web-application/
│
├── frontend/
│   ├── index.html
│   ├── style.css
│   └── script.js
│
├── backend/
│   ├── App.java
│   ├── install.sh
│   └── schema.sql
│
└── README.md
```

---

## Database Table SQL

Run this in MySQL (or let the Java app create the table on first request):

```sql
CREATE TABLE enquiries (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100),
  course VARCHAR(100),
  message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

The Java backend creates this table automatically if it does not exist (database name: **edublitz**).

---

# Step-by-Step AWS Deployment Guide

Follow these sections in order. Use the **AWS Console** in your chosen region.

---

## SECTION 1: Create VPC

1. In the AWS Console, go to **VPC** (search "VPC" in the top search bar).
2. Click **Create VPC**.
3. Choose **VPC only**.
4. **Name**: `edublitz-vpc`
5. **IPv4 CIDR block**: `10.0.0.0/16`
6. Leave the rest as default.
7. Click **Create VPC**.
8. Note your **VPC ID** (e.g. `vpc-0abc123def456`).

**What you did:** You created a VPC with address space `10.0.0.0/16`. All other resources will live inside this VPC.

---

## SECTION 2: Create Subnets

1. In the left menu, click **Subnets**.
2. Click **Create subnet**.
3. **First subnet (Public – for EC2):**
   - **VPC**: Select `edublitz-vpc`.
   - **Subnet name**: `edublitz-public-subnet`
   - **Availability Zone**: Pick one (e.g. `us-east-1a`).
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - Click **Add new subnet**.
4. **Second subnet (Private – for RDS):**
   - **Subnet name**: `edublitz-private-subnet`
   - **Availability Zone**: Same as above (e.g. `us-east-1a`).
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - Click **Create subnet**.
5. Select **edublitz-public-subnet** → **Actions** → **Edit subnet settings**.
6. Check **Enable auto-assign public IPv4 address** → **Save**.

**What you did:** Public subnet for EC2; private subnet for RDS.

---

## SECTION 3: Create Internet Gateway

1. In the left menu, click **Internet gateways**.
2. Click **Create internet gateway**.
3. **Name**: `edublitz-igw` → **Create internet gateway**.
4. Select the new gateway → **Actions** → **Attach to VPC**.
5. Choose **edublitz-vpc** → **Attach**.

**What you did:** The internet gateway lets the public subnet (EC2) reach the internet and receive traffic from users.

---

## SECTION 4: Create Route Table

1. In the left menu, click **Route tables**.
2. Click **Create route table**.
3. **Name**: `edublitz-public-rt`
4. **VPC**: Select **edublitz-vpc**.
5. Click **Create route table**.
6. Select **edublitz-public-rt** → **Routes** tab → **Edit routes** → **Add route**:
   - **Destination**: `0.0.0.0/0`
   - **Target**: **Internet gateway** → select **edublitz-igw**
   - **Save changes**.
7. **Subnet associations** tab → **Edit subnet associations** → check **edublitz-public-subnet** → **Save associations**.

**What you did:** Traffic from the public subnet goes to the internet via the internet gateway.

---

## SECTION 5: Create Security Groups

### 5.1 Frontend (optional – for reference)

1. **Security groups** → **Create security group**.
2. **Name**: `edublitz-frontend-sg`
3. **VPC**: **edublitz-vpc**.
4. **Inbound rules**: Add **HTTP**, Port **80**, Source `0.0.0.0/0`.
5. **Create security group**.

*(Frontend is served by CloudFront from S3; this SG is optional.)*

### 5.2 App Tier Security Group (EC2)

1. **Create security group**.
2. **Name**: `edublitz-app-sg`
3. **VPC**: **edublitz-vpc**.
4. **Inbound rules**:
   - **Custom TCP** – Port **8080** – Source: `0.0.0.0/0` (so the form can call the backend).
   - **SSH** – Port **22** – Source: **My IP** (so only you can SSH).
5. **Create security group**.
6. Note the **Security group ID** (e.g. `sg-0abc123`). You will use it for the DB security group.

### 5.3 Database Security Group (RDS)

1. **Create security group**.
2. **Name**: `edublitz-db-sg`
3. **VPC**: **edublitz-vpc**.
4. **Inbound rules**:
   - **MySQL/Aurora** – Port **3306** – **Source**: **edublitz-app-sg** (select the App Tier security group).
   - This means only the EC2 instance can connect to RDS.
5. **Create security group**.

**What you did:** Only the app tier can reach the database; the database is not open to the internet.

---

## SECTION 6: Create RDS MySQL

1. Go to **RDS** → **Create database**.
2. **Engine**: **MySQL** (e.g. MySQL 8.0).
3. **Templates**: **Free tier** (if available).
4. **Settings**:
   - **DB instance identifier**: `edublitz-db`
   - **Master username**: `admin`
   - **Master password**: Choose a strong password and **write it down** (needed for the Java backend).
5. **Instance configuration**: **Burstable** – **db.t3.micro** (or smallest).
6. **Storage**: Leave default (e.g. 20 GiB).
7. **Connectivity**:
   - **VPC**: **edublitz-vpc**.
   - **Subnet**: **edublitz-private-subnet** (or your private subnet).
   - **Public access**: **No**.
   - **VPC security group**: **edublitz-db-sg**.
8. **Database name**: `edublitz`
9. Click **Create database**.
10. Wait until status is **Available**. Copy the **Endpoint** (e.g. `edublitz-db.xxxxx.us-east-1.rds.amazonaws.com`).

**What you did:** MySQL runs in a private subnet. Only EC2 (with app tier SG) can connect. The Java app will create the `enquiries` table on first request if it does not exist.

---

## SECTION 7: Launch EC2 Instance

1. Go to **EC2** → **Launch instance**.
2. **Name**: `edublitz-app`.
3. **AMI**: **Amazon Linux 2**.
4. **Instance type**: **t2.micro** (free tier).
5. **Key pair**: Create or select one. **Download and save the .pem file** for SSH.
6. **Network settings**:
   - **VPC**: **edublitz-vpc**.
   - **Subnet**: **edublitz-public-subnet**.
   - **Auto-assign public IP**: **Enable**.
   - **Security group**: **edublitz-app-sg**.
7. **User data** (optional): You can paste the contents of **backend/install.sh** here so the first boot runs the script.  
   **Note:** For the script to compile and run, **App.java** must be on the instance. So either:
   - **Option A:** Leave User Data empty. After the instance is running, copy **App.java** and **install.sh** to the instance (see below) and run **install.sh** manually.
   - **Option B:** Paste **install.sh** in User Data; after the instance is up, copy **App.java** to `/home/ec2-user` and run:  
     `sudo bash /home/ec2-user/install.sh`
8. Click **Launch instance**.
9. After it is running, note the **Public IPv4 address** (e.g. `54.123.45.67`).

**Configure backend and RDS:**

10. Copy backend files to EC2 (from your computer, in the project folder):
    ```bash
    scp -i your-key.pem backend/App.java backend/install.sh ec2-user@YOUR_EC2_PUBLIC_IP:/home/ec2-user/
    ```
11. SSH into the instance:
    ```bash
    ssh -i your-key.pem ec2-user@YOUR_EC2_PUBLIC_IP
    ```
12. Run the install script:
    ```bash
    chmod +x install.sh
    sudo bash install.sh
    ```
13. Edit the systemd service to set RDS endpoint and password:
    ```bash
    sudo nano /etc/systemd/system/edublitz-backend.service
    ```
    Replace:
    - `REPLACE_WITH_RDS_ENDPOINT` → your RDS endpoint (e.g. `edublitz-db.xxxxx.us-east-1.rds.amazonaws.com`).
    - `REPLACE_WITH_DB_PASSWORD` → the RDS master password you set.
    Save and exit.
14. Start the backend (if not already running):
    ```bash
    sudo systemctl start edublitz-backend
    ```
15. Test from the instance:
    ```bash
    curl -X POST http://localhost:8080/enquiry -d "name=Test&email=test@test.com&course=AWS&message=Hello"
    ```
    You should see: `{"message":"Enquiry submitted successfully"}`.

**What you did:** The Java backend runs on EC2 on port 8080 and inserts enquiries into RDS.

---

## SECTION 8: Create S3 Bucket

1. Go to **S3** → **Create bucket**.
2. **Bucket name**: e.g. `edublitz-frontend-YOUR-NAME` (must be globally unique).
3. **Region**: Same as your VPC/EC2/RDS.
4. **Block Public Access**: You can leave block public access **on** and use CloudFront to serve the site (recommended). For a quick test you can allow public read (not recommended for production).
5. Click **Create bucket**.
6. Open the bucket → **Upload**.
7. Upload **index.html**, **style.css**, and **script.js** from the **frontend/** folder.
8. **Important:** Before or after upload, edit **script.js** and replace `YOUR_EC2_PUBLIC_IP` in `BACKEND_URL` with your EC2 public IP (e.g. `http://54.123.45.67:8080`). Then upload **script.js** again.

**What you did:** The frontend (enquiry form) is stored in S3. Users will get it via CloudFront.

---

## SECTION 9: Create CloudFront

1. Go to **CloudFront** → **Create distribution**.
2. **Origin**:
   - **Origin domain**: Select your S3 bucket (e.g. `edublitz-frontend-xxx.s3.us-east-1.amazonaws.com`).
   - If you use Origin Access Control (OAC), create it and attach to the origin; then add a bucket policy that allows CloudFront to read (CloudFront often provides a policy to copy).
3. **Default cache behavior**: Leave default (e.g. GET, HEAD, OPTIONS).
4. **Settings**:
   - **Default root object**: `index.html`
   - You can use the default CloudFront domain (e.g. `d123abc.cloudfront.net`) which supports HTTPS.
5. Click **Create distribution**.
6. Wait until **Status** is **Enabled**. Copy the **Distribution domain name** (e.g. `d123abc.cloudfront.net`).

**What you did:** CloudFront serves your frontend from S3. Users open the CloudFront URL to see the enquiry form.

---

## SECTION 10: Test Application

1. Open your browser and go to: **https://YOUR_CLOUDFRONT_DOMAIN** (e.g. `https://d123abc.cloudfront.net`).
2. You should see the **enquiry form** with fields: Name, Email, Course, Message, and Submit.
3. Fill the form and click **Submit**.
4. You should see: **"Enquiry submitted successfully"**.
5. If you see an error:
   - Check that **script.js** has the correct EC2 public IP in **BACKEND_URL** (and that you re-uploaded script.js to S3).
   - Check that the EC2 security group allows **port 8080** from `0.0.0.0/0`.
   - Check that the backend is running: `sudo systemctl status edublitz-backend` and `curl http://localhost:8080/` on the EC2 instance.

**What you did:** You verified the full flow: User → CloudFront → S3 (form) → Browser sends form to EC2 → EC2 inserts into RDS.

---

## SECTION 11: Verify Database

1. SSH into your EC2 instance:
   ```bash
   ssh -i your-key.pem ec2-user@YOUR_EC2_PUBLIC_IP
   ```
2. Connect to RDS from EC2 using the MySQL client (use your RDS endpoint and password):
   ```bash
   mysql -h YOUR_RDS_ENDPOINT -u admin -p edublitz
   ```
   Enter the RDS master password when prompted.
3. Run:
   ```sql
   SELECT * FROM enquiries;
   ```
4. You should see the enquiry you submitted (id, name, email, course, message, created_at).
5. Type `exit` to leave the MySQL client.

**What you did:** You confirmed that form data is stored in the RDS MySQL database.

---

## SECTION 12: Architecture Explanation (VERY SIMPLE)

- **CloudFront** = Frontend delivery. It serves your HTML form (from S3) quickly and with HTTPS.
- **EC2** = Backend processing. The Java app receives the form data (POST /enquiry), validates it, and inserts it into the database.
- **RDS** = Data storage. MySQL stores all enquiries in the `enquiries` table in a private subnet.

**Flow:** User opens CloudFront URL → sees form (from S3) → fills form and clicks Submit → browser sends data to EC2 Java API → Java inserts into RDS MySQL → user sees "Enquiry submitted successfully".

---

## SECTION 13: Learning Outcomes

By completing this project, you practice:

- **Real 3-tier architecture**: Web (CloudFront + S3), App (EC2), Database (RDS).
- **CloudFront frontend hosting**: Serving static content and using HTTPS.
- **Java backend deployment**: Simple HTTP server, POST handler, form parsing, JDBC to MySQL.
- **RDS database storage**: MySQL in a private subnet, secure connectivity from EC2 only.
- **Secure VPC architecture**: Public subnet for EC2, private subnet for RDS, security groups restricting access.

---

## SECTION 14: Cleanup Steps

Delete resources in this order:

1. **CloudFront**: Open your distribution → **Disable** → wait until deployed → **Delete**.
2. **S3 bucket**: Empty the bucket (delete all objects) → **Delete bucket**.
3. **EC2 instance**: **Terminate** the **edublitz-app** instance.
4. **RDS instance**: **Delete** the **edublitz-db** instance (uncheck "Create final snapshot" if you do not need a backup).
5. **Security groups**: Delete **edublitz-app-sg**, **edublitz-db-sg**, and **edublitz-frontend-sg** (if created). You may need to wait for network interfaces to detach.
6. **Subnets**: Delete **edublitz-public-subnet** and **edublitz-private-subnet** (after EC2 and RDS are gone).
7. **Route table**: Delete the custom route table (e.g. **edublitz-public-rt**); do not delete the default one.
8. **Internet gateway**: **Detach** from VPC → **Delete**.
9. **VPC**: **Delete VPC**.

---

## Quick Reference

| Item | Value |
|------|--------|
| VPC CIDR | `10.0.0.0/16` |
| Public subnet (EC2) | `10.0.1.0/24` |
| Private subnet (RDS) | `10.0.2.0/24` |
| Backend port | `8080` |
| MySQL port | `3306` |
| Database name | `edublitz` |
| Table name | `enquiries` |
| Backend URL in script.js | `http://YOUR_EC2_PUBLIC_IP:8080` |

---

**EduBlitz 3-Tier Web Application** – Beginner-friendly AWS project: enquiry form → EC2 Java API → RDS MySQL.
