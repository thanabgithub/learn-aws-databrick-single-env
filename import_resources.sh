#!/bin/bash

# Script to import existing AWS resources into Terraform state

# IMPORTANT: Replace <YOUR_ANALYTICS_ACCOUNT_ID> with the actual AWS Account ID
# of your existing "Analytics" account before running this script.
ANALYTICS_ACCOUNT_ID="390149883940"

echo "Importing Analytics Account..."
terraform import aws_organizations_account.analytics "$ANALYTICS_ACCOUNT_ID"

echo "Importing Production Policy Attachment..."
terraform import aws_organizations_policy_attachment.attach_production_policy ou-proy-1wowawha:p-jyhlye0w

echo "Importing Development Policy Attachment..."
terraform import aws_organizations_policy_attachment.attach_development_policy ou-proy-xgwzbp8w:p-sk13txch

echo "Importing Sandbox Policy Attachment..."
terraform import aws_organizations_policy_attachment.attach_sandbox_policy ou-proy-rlkhoy4l:p-b6anzez0

echo "Import process complete. Please run 'terraform plan' to verify."
