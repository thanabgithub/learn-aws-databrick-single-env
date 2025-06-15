# Terraform configuration to bootstrap AWS Organization units and initial accounts
# Generated based on design.md – single-environment Databricks architecture
# Last Updated: 2025-06-15

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# PROVIDERS
# -----------------------------------------------------------------------------
# This configuration is expected to run from the management (root) account with
# Administrator-level privileges so that it can administer AWS Organizations.
# Change the default region to whichever primary region you use.
provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# ORGANIZATION
# -----------------------------------------------------------------------------
data "aws_organizations_organization" "this" {}

# Convenience local for the Root ID
locals {
  root_id = data.aws_organizations_organization.this.roots[0].id
}

# -----------------------------------------------------------------------------
# ORGANIZATIONAL UNITS
# -----------------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "production" {
  name      = "Production"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "development" {
  name      = "Development"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = local.root_id
}

# -----------------------------------------------------------------------------
# ACCOUNTS
# -----------------------------------------------------------------------------
# Management/root account already exists inside the organization, so it is not
# created here.  The design currently has one workload account (Analytics) and
# leaves Development/Sandbox empty for future use.  The following resources
# create the Analytics account and *optionally* Dev & Sandbox accounts when e-
# mail addresses are supplied.

resource "aws_organizations_account" "analytics" {
  name                       = "Analytics"
  email                      = var.analytics_account_email
  parent_id                  = aws_organizations_organizational_unit.production.id
  # role_name is managed by AWS Organizations default behavior (OrganizationAccountAccessRole)
  # iam_user_access_to_billing defaults to ALLOW by AWS Organizations
  lifecycle {
    prevent_destroy = true # safeguard against accidental deletion
  }
}

# Optional – comment out if you do not want to create these accounts yet.
resource "aws_organizations_account" "development" {
  count                      = var.development_account_email == "" ? 0 : 1
  name                       = "Development"
  email                      = var.development_account_email
  parent_id                  = aws_organizations_organizational_unit.development.id
  role_name                  = var.account_role_name
  iam_user_access_to_billing = "ALLOW"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "sandbox" {
  count                      = var.sandbox_account_email == "" ? 0 : 1
  name                       = "Sandbox"
  email                      = var.sandbox_account_email
  parent_id                  = aws_organizations_organizational_unit.sandbox.id
  role_name                  = var.account_role_name
  iam_user_access_to_billing = "ALLOW"
  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to operate in (for provider configuration)"
  type        = string
  default     = "ap-northeast-1"
}

variable "account_role_name" {
  description = "The IAM role name that will be created in child accounts and assumed by the management account"
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "analytics_account_email" {
  description = "E-mail address for the Analytics (production workloads) account"
  type        = string
  default     = "thana.b.jpy+analytics@gmail.com"
}

variable "development_account_email" {
  description = "Optional – e-mail address for the Development account"
  type        = string
  default     = ""
}

variable "sandbox_account_email" {
  description = "Optional – e-mail address for the Sandbox account"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# SERVICE CONTROL POLICIES
# -----------------------------------------------------------------------------
# Production OU policy
resource "aws_organizations_policy" "production_guardrails" {
  name        = "ProductionGuardrails"
  description = "Production OU restrictions - Enforce MFA, tagging, single region"
  content     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceMFA",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        },
        "StringNotLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*"
        }
      }
    },
    {
      "Sid": "RequireResourceTags",
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "rds:CreateDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestTag/Environment": "true"
        }
      }
    },
    {
      "Sid": "EnforceSingleRegion",
      "Effect": "Deny",
      "NotAction": [
        "cloudfront:*",
        "iam:*",
        "route53:*",
        "support:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": "ap-northeast-1"
        }
      }
    }
  ]
}
EOF
  type        = "SERVICE_CONTROL_POLICY"
}

# Attach to Production OU
resource "aws_organizations_policy_attachment" "attach_production_policy" {
  policy_id = aws_organizations_policy.production_guardrails.id
  target_id = aws_organizations_organizational_unit.production.id
}

# Development OU policy - Block expensive resources
resource "aws_organizations_policy" "development_guardrails" {
  name        = "DevelopmentGuardrails"
  description = "Block expensive resources in development"
  content     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LimitExpensiveResources",
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "rds:CreateDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotLike": {
          "ec2:InstanceType": ["t3.micro", "t3.small"],
          "rds:DatabaseClass": ["db.t3.micro", "db.t3.small"]
        }
      }
    }
  ]
}
EOF
  type        = "SERVICE_CONTROL_POLICY"
}

# Attach to Development OU
resource "aws_organizations_policy_attachment" "attach_development_policy" {
  policy_id = aws_organizations_policy.development_guardrails.id
  target_id = aws_organizations_organizational_unit.development.id
}

# Sandbox OU policy - Heavy restrictions
resource "aws_organizations_policy" "sandbox_guardrails" {
  name        = "SandboxGuardrails"
  description = "Heavy restrictions for sandbox accounts"
  content     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyProductionServices",
      "Effect": "Deny",
      "Action": [
        "cloudformation:*",
        "dynamodb:*",
        "elasticache:*",
        "elasticbeanstalk:*",
        "elasticloadbalancing:*",
        "lambda:*",
        "rds:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LimitEC2Instances",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "ec2:InstanceType": "t3.micro"
        }
      }
    }
  ]
}
EOF
  type        = "SERVICE_CONTROL_POLICY"
}

# Attach to Sandbox OU
resource "aws_organizations_policy_attachment" "attach_sandbox_policy" {
  policy_id = aws_organizations_policy.sandbox_guardrails.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}

# Data sources for the existing S3 bucket and DynamoDB table created by the bootstrap process
data "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-organization-apne1"
}

data "aws_dynamodb_table" "terraform_state_lock" {
  name = "terraform-state-lock"
}

# Note: The actual S3 bucket and DynamoDB table resources are managed by the bootstrap configuration.
# See bootstrap/main.tf for the resource definitions.
# These data sources allow us to reference the existing resources in our configuration.

# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------
output "organization_id" {
  value = data.aws_organizations_organization.this.id
}

output "production_ou_id" {
  value = aws_organizations_organizational_unit.production.id
}

output "analytics_account_id" {
  value       = aws_organizations_account.analytics.id
  description = "ID of the Analytics account"
}

output "terraform_state_bucket" {
  value       = data.aws_s3_bucket.terraform_state.bucket
  description = "Name of the S3 bucket for Terraform state"
}

output "terraform_state_lock_table" {
  value       = data.aws_dynamodb_table.terraform_state_lock.name
  description = "Name of the DynamoDB table for Terraform state locking"
}
