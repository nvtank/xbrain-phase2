# AWS Web App Deployment using Terraform

This lab demonstrates how to deploy a basic, secure web application architecture on AWS using Terraform.

---

## 1. Architecture Overview

*   **VPC**: Custom VPC (`10.0.0.0/16`).
*   **Subnets**:
    *   2 Public Subnets (For EC2 Web Server, with Auto-assign Public IP enabled).
    *   2 Private Subnets (For RDS MySQL Database, isolated from the public internet).
*   **EC2 Instance**: Apache (httpd) web server in the Public Subnet displaying basic instance metadata.
*   **RDS Instance**: Private MySQL Database accessible only from the EC2 Security Group.
*   **S3 Bucket**: Private bucket for storing static assets.
*   **Remote State**: S3 bucket for storing state files, with a DynamoDB table for state locking.

---

## 2. Project Structure

```text
infra/
├── backend-bootstrap/      # Run first to bootstrap S3/DynamoDB for remote state
│   ├── main.tf
│   └── outputs.tf
├── modules/                # Reusable Infrastructure Modules
│   ├── vpc/                # VPC, Subnets, IGW, Route Tables
│   ├── ec2/                # EC2 Web Server & Security Group (with user-data.sh)
│   ├── rds/                # RDS MySQL DB Subnet Group & Security Group
│   └── s3/                 # S3 Static Assets Bucket
└── environments/
    └── dev/                # Dev Environment root configuration
        ├── providers.tf
        ├── backend.tf      # Configure Remote Backend (needs S3 bucket name from bootstrap)
        ├── main.tf         # Connects modules together
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

---

## 3. Deployment Steps

### Step 1: Bootstrap Remote State
Create the S3 bucket and DynamoDB table first using local state:
```bash
cd infra/backend-bootstrap
terraform init
terraform apply -auto-approve
```
*Note down the `s3_bucket_name` printed in the outputs.*

### Step 2: Configure Environment
1. Navigate to the dev environment:
   ```bash
   cd ../environments/dev
   ```
2. Open `backend.tf` and replace `cdo-terraform-state-PLACEHOLDER` with your actual S3 bucket name from Step 1.
3. Create your configuration variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
4. Edit `terraform.tfvars` and set your variables:
   *   `key_name`: The name of your AWS SSH Key Pair.
   *   `my_ip`: Your public IP (e.g., `203.0.113.50/32`) or `0.0.0.0/0` to allow access from anywhere.
   *   `db_password`: A strong database master password.

### Step 3: Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply -auto-approve
```
*Wait 3-5 minutes. Once finished, copy the `web_public_ip` from the outputs.*

---

## 4. Verification

1.  **Test Web Server**:
    Open `http://<WEB_PUBLIC_IP>` in your web browser. You should see a success page displaying the EC2 Instance ID and Availability Zone.
2.  **Verify DB Security**:
    SSH into your EC2 instance:
    ```bash
    ssh -i /path/to/your-key.pem ec2-user@<WEB_PUBLIC_IP>
    ```
    Inside the EC2 instance, install the MySQL client and test connection to the RDS endpoint (port 3306):
    ```bash
    sudo yum install -y mariadb
    mysql -h <RDS_ENDPOINT_WITHOUT_PORT> -u dbadmin -p
    ```
    *Connection should succeed. External connections directly to the RDS endpoint from your local machine will timeout (by design).*

---

## 5. Cleanup (Avoid AWS Charges)

Destroy the main infrastructure:
```bash
cd infra/environments/dev
terraform destroy -auto-approve
```

Destroy the backend state bootstrap infrastructure:
```bash
cd ../backend-bootstrap
terraform destroy -auto-approve
```
