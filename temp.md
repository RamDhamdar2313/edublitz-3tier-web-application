To create the equivalent of your Terraform `aws_db_subnet_group` and `aws_db_instance` resources manually in the AWS Management Console, follow these step-by-step instructions. These replicate the private MySQL RDS setup with the specified names, engine (MySQL 8.4.7), instance class (db.t3.micro), storage (20 GB), and other attributes, assuming your private subnets (e.g., `private_subnet_1a` and `private_subnet_1b`), DB security group (`db_sg`), and variables like `db_username`/`db_password` already exist. [aws-core-services.ws.kabits](https://aws-core-services.ws.kabits.com/two-tier-application-linux/rds/create-db-subnet-group/)

## Prerequisites
Ensure you have:
- A VPC with at least two private subnets in different Availability Zones (AZs) for high availability.
- A security group (`db_sg`) allowing inbound traffic (e.g., port 3306 from app servers).
- Master username/password ready (replace placeholders below).

## Step 1: Create DB Subnet Group
1. Log in to the AWS Console and navigate to **RDS** > **Subnet groups** (left navigation).
2. Click **Create DB Subnet group**.
3. Enter **Name**: `edublitz-db-subnet-group`.
4. Add a **Description** (optional, e.g., "Subnet group for edublitz DB").
5. Select your **VPC**.
6. Under **Add subnets**, choose your two private subnets (e.g., `private_subnet_1a` in us-east-1a and `private_subnet_1b` in us-east-1b)—at least one per AZ.
7. Add **Tags** if desired (e.g., `Name: edublitz-db-subnet-group`).
8. Click **Create**. [youtube](https://www.youtube.com/watch?v=7qoodL6yFCU)

## Step 2: Create RDS DB Instance
1. In the RDS console, click **Databases** > **Create database**.
2. Choose **Standard create** > **MySQL**.
3. Set **Engine version**: 8.4.7 (or latest compatible if unavailable).
4. **Templates**: Free tier (matches db.t3.micro).
5. **Settings**:
   - **DB instance identifier**: `edublitz-db`.
   - **Master username**: your `var.db_username` (e.g., `admin`).
   - **Master password**: your `var.db_password` (must meet complexity rules; confirm it).
6. **DB instance class**: `db.t3.micro`.
7. **Storage**:
   - **Allocated storage**: 20 GiB.
   - Defaults for type (gp3) and scaling are fine.
8. **Connectivity**:
   - **Virtual private cloud (VPC)**: Your VPC.
   - **Subnet group**: Select `edublitz-db-subnet-group`.
   - **Public access**: No (matches `publicly_accessible = false`).
   - **VPC security groups**: Add `db_sg`.
9. **Database authentication**: Password authentication.
10. **Database creation**:
    - **Database name**: `edublitz` (creates initial DB).
11. **Additional configuration**:
    - **Initial database name**: Already set above.
    - Set **Backup**, **Monitoring**, etc., as needed (defaults ok).
    - **Deletion protection**: Off.
    - Under **Final snapshot**, check **Create final snapshot?** No (matches `skip_final_snapshot = true`).
12. Review and click **Create database**. Wait 5-10 minutes for it to be Available. [spacelift](https://spacelift.io/blog/terraform-aws-rds)

The DB endpoint will appear under **Connectivity & security** once ready—use it to connect from your app in the VPC. Test connectivity via EC2 or SSM. [spacelift](https://spacelift.io/blog/terraform-aws-rds)