# AWS Organization with Terraform

This repository contains Terraform configurations for managing an AWS Organization with a single environment setup.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.6.0
- AWS IAM permissions to create organizations, S3 buckets, and DynamoDB tables

## Initial Setup

1. **Set up Terraform backend** (one-time setup):
   ```bash
   ./setup-terraform-backend.sh
   ```
   This will create the required AWS resources:
   - S3 bucket for storing Terraform state
   - DynamoDB table for state locking

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Review and apply changes**:
   ```bash
   terraform plan
   terraform apply
   ```

## Directory Structure

- `main.tf` - Main Terraform configuration
- `backend.tf` - Remote backend configuration
- `bootstrap.sh` - One-time setup script for the Terraform backend
- `README.md` - This file

## Cleanup

To destroy all resources:

1. First, remove the S3 bucket contents:
   ```bash
   aws s3 rm s3://terraform-state-organization-apne1 --recursive
   ```

2. Then run Terraform destroy:
   ```bash
   terraform destroy
   ```

3. Finally, delete the S3 bucket and DynamoDB table:
   ```bash
   aws s3api delete-bucket --bucket terraform-state-organization-apne1 --region ap-northeast-1
   aws dynamodb delete-table --table-name terraform-state-lock --region ap-northeast-1
   ```
# learn-aws-databrick-single-env
