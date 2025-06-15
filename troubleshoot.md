# Terraform Troubleshooting Guide

## DynamoDB State Lock Issues

### Problem: State Checksum Mismatch

If you encounter an error like this when running `terraform init`:

```
Error: Error refreshing state: state data in S3 does not have the expected content.

The checksum calculated for the state stored in S3 does not match the checksum
stored in DynamoDB.

Bucket: terraform-state-organization-apne1
Key:    terraform/state/organization.tfstate
Calculated checksum: 89d0e6e5e21cf75a2c15d0442c031e28
Stored checksum:     e64c00b2d2a1e27f9930157252752211
```

### Solution: Update DynamoDB Digest

Use the AWS CLI to update the digest value in the DynamoDB lock table:

```bash
aws dynamodb update-item --table-name terraform-state-lock --key '{"LockID":{"S":"terraform-state-organization-apne1/terraform/state/organization.tfstate-md5"}}' --update-expression 'SET Digest = :val' --expression-attribute-values '{":val":{"S":"89d0e6e5e21cf75a2c15d0442c031e28"}}' --region ap-northeast-1
```

Replace the following values with those from your error message:
- `terraform-state-lock`: Your DynamoDB lock table name
- `terraform-state-organization-apne1/terraform/state/organization.tfstate-md5`: Your lock ID (based on S3 bucket and key)
- `89d0e6e5e21cf75a2c15d0442c031e28`: The calculated checksum from the error message
- `ap-northeast-1`: Your AWS region

### After Fixing

Run `terraform init -reconfigure` again to reinitialize with the corrected state lock.

## AWS SSO Access Issues

### Problem: SSO Users Cannot Access Resources

SSO users may be blocked from accessing resources due to Service Control Policies (SCPs) that enforce MFA, which doesn't apply correctly to SSO sessions.

### Solution: Modify SCP to Exempt SSO Sessions

Add a `StringNotLike` condition to the MFA enforcement policy to exempt SSO roles:

```json
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
}
```
