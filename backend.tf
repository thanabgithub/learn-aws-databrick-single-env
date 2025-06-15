# This file defines the backend configuration for Terraform state management.
# The S3 bucket and DynamoDB table are created by the setup-terraform-backend.sh script.
#
# To set up the backend for the first time:
# 1. Run: ./setup-terraform-backend.sh
# 2. Then run: terraform init

terraform {
  backend "s3" {
    bucket         = "terraform-state-organization-apne1"
    key            = "terraform/state/organization.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    # dynamodb_table = "terraform-state-lock" # Re-enabled for state locking
    dynamodb_table = "terraform-state-lock"
  }
}
