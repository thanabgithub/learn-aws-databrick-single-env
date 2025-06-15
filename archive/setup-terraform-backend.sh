#!/bin/bash
set -e

# This is a one-time bootstrap script to set up the Terraform backend
# Run this script only once during initial setup

# Configuration
STATE_BUCKET="terraform-state-organization-apne1"
DYNAMODB_TABLE="terraform-state-lock"
REGION="ap-northeast-1"

# Create S3 bucket for Terraform state
echo "Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
  --bucket "$STATE_BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

# Enable versioning
echo "Enabling versioning on the S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Block public access
echo "Blocking public access to the S3 bucket..."
aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --region "$REGION" \
  --table-name "$DYNAMODB_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags "Key=Name,Value=Terraform State Lock" "Key=Environment,Value=Management" "Key=Terraform,Value=true" "Key=Critical,Value=true"

echo "\nBootstrap complete!"
echo "S3 bucket: $STATE_BUCKET"
echo "DynamoDB table: $DYNAMODB_TABLE"
