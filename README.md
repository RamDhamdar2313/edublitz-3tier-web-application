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
User → S3 Static Hosting frontend ->
HTML Form → EC2 Java API → RDS MySQL Database
```

| Tier | AWS Service | Role |
|------|-------------|------|
| **Web Tier** | S3 | Serves frontend (enquiry form) |
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
   - **Availability Zone**: Pick one (e.g. `ap-south-1a`).
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - Click **Add new subnet**.
4. **Second subnet (Private – for RDS):**
   - **Subnet name**: `edublitz-private1a-subnet`
   - **Availability Zone**: Same as above (e.g. `ap-south-1b`).
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - Click **Create subnet**.
5. **Third subnet (Private – for RDS):**
   - **Subnet name**: `edublitz-private1b-subnet`
   - **Availability Zone**: Pick one except of the other private subnet az (e.g. `ap-south-1c`).
   - **IPv4 CIDR block**: `10.0.3.0/24`
   - Click **Create subnet**.

6. Select **edublitz-public-subnet** → **Actions** → **Edit subnet settings**.
7. Check **Enable auto-assign public IPv4 address** → **Save**.

**What you did:** Public subnet for EC2; private subnets for RDS.

![](images/image2026-02-15-11-54-29.png)


---

## SECTION 3: Create Internet Gateway

1. In the left menu, click **Internet gateways**.
2. Click **Create internet gateway**.
3. **Name**: `edublitz-igw` → **Create internet gateway**.
4. Select the new gateway → **Actions** → **Attach to VPC**.
5. Choose **edublitz-vpc** → **Attach**.

**What you did:** The internet gateway lets the public subnet (EC2) reach the internet and receive traffic from users.

---

## SECTION 4: Create Route Tables

### Public-RT Creation

1. In the left menu, click **Route tables**.
2. Click **Create route table**.
3. **Name**: `edublitz-public-rt`
4. **VPC**: Select **edublitz-vpc**.
5. Click **Create route table**.
6. Select **edublitz-public-rt** → **Routes** tab → **Edit routes** → **Add route**:
   - **Destination**: `0.0.0.0/0`
   - **Target**: **Internet gateway** → select **edublitz-igw**
   - **Save changes**.
   ![](images/image2026-02-15-12-12-32.png)
7. **Subnet associations** tab → **Edit subnet associations** → check **edublitz-public-subnet** → **Save associations**.
![](images/image2026-02-15-12-11-38.png)

**What you did:** Traffic from the public subnet goes to the internet via the internet gateway.

![](images/image2026-02-15-12-11-02.png)

### Private-RT Creation

1. In the left menu, click **Route tables**.
2. Click **Create route table**.
3. **Name**: `edublitz-private-rt`
4. **VPC**: Select **edublitz-vpc**.
5. Click **Create route table**.
6. **Subnet associations** tab → **Edit subnet associations** → check two of **edublitz-private-subnets** → **Save associations**.
   ![](images/image2026-02-15-12-16-35.png)

**What you did:** Traffic from the public subnet goes to the internet via the internet gateway.


![](images/image2026-02-15-12-14-46.png)
![](images/image2026-02-15-12-15-48.png)
---

## SECTION 5: Create Security Groups

### 5.1 Frontend (optional – for reference)

1. **Security groups** → **Create security group**.
2. **Name**: `edublitz-frontend-sg`
3. **VPC**: **edublitz-vpc**.
4. **Inbound rules**: Add **HTTP**, Port **80**, Source `0.0.0.0/0`.
5. **Create security group**.


### 5.2 App Tier Security Group (EC2)

1. **Create security group**.
2. **Name**: `edublitz-app-sg`
3. **VPC**: **edublitz-vpc**.
4. **Inbound rules**:
   - **Custom TCP** – Port **8080** – Source: `0.0.0.0/0` (so the form can call the backend).
   - **SSH** – Port **22** – Source: **My IP** (so only you can SSH).
5. **Create security group**.
6. Note the **Security group ID** (e.g. `sg-0abc123`). You will use it for the DB security group.
   ![](images/image2026-02-15-12-26-15.png)


### 5.3 Database Security Group (RDS)

1. **Create security group**.
2. **Name**: `edublitz-db-sg`
3. **VPC**: **edublitz-vpc**.
4. **Inbound rules**:
   - **MySQL/Aurora** – Port **3306** – **Source**: **edublitz-app-sg** (select the App Tier security group).
   - This means only the EC2 instance can connect to RDS.
5. **Create security group**.

**What you did:** Only the app tier can reach the database; the database is not open to the internet.
   ![](images/image2026-02-15-12-28-01.png)

![](images/image2026-02-15-12-31-18.png)
---

## SECTION 6: Create RDS MySQL

### Step 1: Create DB Subnet Group
1. Log in to the AWS Console and navigate to **RDS** > **Subnet groups** (left navigation).
2. Click **Create DB Subnet group**.
3. Enter **Name**: `edublitz-db-subnet-group`.
4. Add a **Description** (optional, e.g., "Subnet group for edublitz DB").
5. Select your **VPC**.
6. Under **Add subnets**, choose your two private subnets (e.g., `private_subnet_1a` in us-east-1a and `private_subnet_1b` in us-east-1b)—at least one per AZ.
7. Add **Tags** if desired (e.g., `Name: edublitz-db-subnet-group`).
8. Click **Create**. 

![](images/image2026-02-15-14-44-54.png)


## Step 2: Create RDS DB Instance
1. In the RDS console, click **Databases** > **Create database**.
2. Choose **Standard create** > **MySQL**.
3. Set **Engine version**: 8.4.7 (or latest compatible if unavailable).
4. **Templates**: Free tier (matches db.t3.micro).
5. **Settings**:
   - **DB instance identifier**: `edublitz-db`.
   - **Master username**: your  (e.g., `admin`).
   - **Master password**: your  (must meet complexity rules; confirm it).
6. **DB instance class**: `db.t3.micro`.
7. **Storage**:
   - **Allocated storage**: 20 GiB.
   - Defaults for type (gp3) and scaling are fine.
8. **Connectivity**:
   - **Virtual private cloud (VPC)**: Your VPC.
   - **Subnet group**: Select `edublitz-db-subnet-group`.
   - **VPC security groups**: Add `db_sg`.
9. **Database authentication**: Password authentication.
10. **Database creation**:
    - **Database name**: `edublitz` (creates initial DB).
11. **Additional configuration**:
    - **Initial database name**: Already set above.
    - Set **Backup**, **Monitoring**, etc., as needed (defaults ok).
    - **Deletion protection**: Off.
    - Under **Final snapshot**, check **Create final snapshot?** No (matches `skip_final_snapshot = true`).
12. Review and click **Create database**. Wait 5-10 minutes for it to be Available.
13. Wait until status is **Available**. Copy the **Endpoint** (e.g. `edublitz-db.xxxxx.us-east-1.rds.amazonaws.com`).

**What you did:** MySQL runs in a private subnet. Only EC2 (with app tier SG) can connect. The Java app will create the `enquiries` table on first request if it does not exist.

![](images/image2026-02-15-14-52-40.png)

---
![](images/image2026-02-15-14-54-09.png)

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
7. **User data** (important) :
   1. Paste the below script in the user-data script --> Advanced Details
   2. you can get this file in /backend/user-data.sh
   3. **Modify** these first before copying
      1. from line no. 28  onwards
      2. ```bash
          sudo -u ec2-user bash -c "
            /home/ec2-user/install.sh \
            --db-host edublitz-db.cx2ce82ykg2g.ap-south-1.rds.amazonaws.com \
            --db-user root \
            --db-password 'admin#12345'
            "   
         ```
      3. here replace `edublitz-db.cx2ce82ykg2g.ap-south-1.rds.` with your RDS endpoint
      4. Replace `root` with your db master username
      5. Replace `admin#12345` with your master passwords
   4. Here is the full script **MODIFY IT BEFORE PASTING OTHERWIAE IT WILL NOT WORK**
   



```bash
#!/bin/bash
set -e

# Switch to ec2-user home
cd /home/ec2-user

# -------- Update System --------
yum update -y

# -------- Install Git --------
yum install -y git

# -------- Clone Repository --------
if [ ! -d "edublitz-3tier-web-application" ]; then
  git clone https://github.com/RamDhamdar2313/edublitz-3tier-web-application.git
fi 

# -------- Copy Backend Files --------
cp -r edublitz-3tier-web-application/backend/* /home/ec2-user/

# -------- Fix Ownership --------
chown -R ec2-user:ec2-user /home/ec2-user

# --  ------ Make Install Executable --------
chmod +x /home/ec2-user/install.sh

# -------- Run Install Script --------
sudo -u ec2-user bash -c "
/home/ec2-user/install.sh \
  --db-host edublitz-db.cx2ce82ykg2g.ap-south-1.rds.amazonaws.com \
  --db-user root \
  --db-password 'admin#12345'
"

# -------- Ensure Service Running --------
systemctl daemon-reload
systemctl enable edublitz-backend
systemctl restart edublitz-backend

echo "User-data setup completed successfully."


```
8. Click **Launch instance**.
9.  After it is running, note the **Public IPv4 address** (e.g. `54.123.45.67`).
    ![](images/image2026-02-15-15-17-23.png)

### **Testing backend backend and RDS:**

1. You can see the status of the launch user-data-script that have ran into the server by 
   1. Going to Instances --> Actions --> Monitoring and troubleshoot --> Get System logs
   2. See if any error message or fail message is popping into the system log window
   3. like this
   ![](images/image2026-02-15-15-19-07.png)
   4. Any error: Mess~age should be resolved and in the instance itself ~/user-data.sh is modified accordingly to handle that error
   5. You can edit and change permission of ~/user-data.sh 
   6. Modify it and rerun it using `.~/user-data.sh` in non root user to reconfigure the backend
   
2. If everything looks fine ssh into the instance using public ip and then try to run these cmd and see their expected output 
   ```bash
   sudo systemctl status edublitz-backend

   # Expected output active(running)
   ```
3. If these commands are not working try to run the individual cmds in user-data.sh and /backend/install.sh or try to find the `ERROR:` message 
   
4.  Start the backend (if not already running):
    ```bash
    sudo systemctl restart edublitz-backend
    ```
5. Test from the instance:
    ```bash
    curl -X POST http://localhost:8080/enquiry -d "name=Test&email=test@test.com&course=AWS&message=Hello"
    ```
    You should see: `{"message":"Enquiry submitted successfully"}`.
6. Test from the browser 
   ![](images/image2026-02-15-15-25-23.png)
7. 

**What you did:** The Java backend runs on EC2 on port 8080 and inserts enquiries into RDS.

---

## SECTION 8: Create S3 Bucket

1. Go to **S3** → **Create bucket**.
2. **Bucket name**: e.g. `edublitz-frontend-YOUR-NAME` (must be globally unique).
3. **Region**: Same as your VPC/EC2/RDS.
4. **Block Public Access**: You can leave block public access **on** and use CloudFront to serve the site (recommended). For a quick test you can allow public read (not recommended for production).
5. Click **Create bucket**.
6. Open the bucket → **Upload**.
7. **Important:** Before or after upload, edit **script.js** and replace `YOUR_EC2_PUBLIC_IP` in `BACKEND_URL` with your EC2 public IP (e.g. `http://54.123.45.67:8080`). Then upload **script.js** again.
8. Upload **index.html**, **style.css**, and **script.js** from the **frontend/** folder.

**What you did:** The frontend (enquiry form) is stored in S3. Users will get it via CloudFront.

**Bucket Policy**
![](images/image2026-02-15-15-22-54.png)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicRead",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::ngp-bucket-14-jan-2026/*"
        }
    ]
}
```

### **Testing the Full Website from S3 Static Routing**

1. Go to S3--> Buckets--> Bucket-name --> Properties --> **Static website hosting**
2. Copy the url and try to run it on browser 
3. Expected Output
   ![](images/image2026-02-15-15-29-14.png)
4. Fill the form and try submit
5. Successful submission and retrieval output
   ![](images/image2026-02-15-15-32-23.png)
6. Click the refresh button ***below*** to show the enquiries
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
