# modules/s3-vpc/variables.tf

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "s3-vpc"
}

variable "bucket_name" {
  description = "Name of the S3 bucket (optional, will be auto-generated if not provided)"
  type        = string
  default     = ""
}

variable "bucket_prefix" {
  description = "Prefix for auto-generated bucket names"
  type        = string
  default     = ""
}

variable "create_bucket" {
  description = "Whether to create the S3 bucket"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Force destroy bucket even if it contains objects"
  type        = bool
  default     = false
}

# VPC Configuration (similar to EC2)
variable "vpc_id" {
  description = "VPC ID where the S3 endpoint will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for interface endpoint (similar to EC2 subnet placement)"
  type        = list(string)
  default     = []
}

variable "route_table_ids" {
  description = "List of route table IDs for gateway endpoint"
  type        = list(string)
  default     = []
}

# Auto-configuration (EC2-like behavior)
variable "auto_select_subnets" {
  description = "Automatically select private subnets if subnet_ids not provided (like EC2 default behavior)"
  type        = bool
  default     = true
}

variable "auto_select_route_tables" {
  description = "Automatically select private route tables if route_table_ids not provided"
  type        = bool
  default     = true
}

# Preset Configuration (like EC2 instance types)
variable "preset" {
  description = "Predefined configuration preset (like EC2 instance types)"
  type        = string
  default     = "standard"
  
  validation {
    condition = contains([
      "standard",      # Gateway endpoint, basic security
      "secure",        # Interface endpoint, enhanced security
      "compliance",    # Interface endpoint, maximum security
      "cost-optimized" # Gateway endpoint, minimal features
    ], var.preset)
    error_message = "Preset must be one of: standard, secure, compliance, cost-optimized"
  }
}

# Endpoint Configuration
variable "endpoint_type" {
  description = "Type of VPC endpoint: 'gateway' (free), 'interface' (charged), or 'auto' (defaults to gateway)"
  type        = string
  default     = ""  # Will be set by preset if not specified
  
  validation {
    condition     = var.endpoint_type == "" || contains(["gateway", "interface", "auto"], var.endpoint_type)
    error_message = "Endpoint type must be 'gateway', 'interface', or 'auto'"
  }
}

variable "private_dns_enabled" {
  description = "Enable private DNS for interface endpoint"
  type        = bool
  default     = true
}

variable "endpoint_policy" {
  description = "Custom endpoint policy (JSON). If not provided, allows full access"
  type        = string
  default     = ""
}

# Security Group Configuration (EC2-like)
variable "security_group_ids" {
  description = "Existing security group IDs to attach to interface endpoint (like EC2)"
  type        = list(string)
  default     = []
}

variable "create_security_group" {
  description = "Create a new security group for the endpoint (like EC2 default behavior)"
  type        = bool
  default     = true
}

variable "security_group_rules" {
  description = "Custom security group rules (like EC2 security group rules)"
  type = list(object({
    type                     = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
    description              = optional(string)
  }))
  default = []
}

# IAM Configuration (EC2-like instance profile)
variable "create_instance_profile" {
  description = "Create IAM instance profile for EC2 instances to access S3 (like EC2 key pair)"
  type        = bool
  default     = true
}

variable "instance_profile_name" {
  description = "Custom name for the instance profile (auto-generated if not provided)"
  type        = string
  default     = ""
}

# Security Configuration
variable "restrict_to_vpc" {
  description = "Restrict bucket access to VPC endpoint only (similar to EC2 security groups)"
  type        = bool
  default     = true
}

variable "allowed_actions" {
  description = "List of allowed S3 actions when accessing through VPC endpoint"
  type        = list(string)
  default = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket",
    "s3:GetBucketLocation"
  ]
}

# Advanced Security Policies (from official module)
variable "attach_deny_insecure_transport_policy" {
  description = "Controls if S3 bucket should have deny non-SSL transport policy attached"
  type        = bool
  default     = false
}

variable "attach_require_latest_tls_policy" {
  description = "Controls if S3 bucket should require the latest version of TLS"
  type        = bool
  default     = false
}

variable "attach_deny_unencrypted_object_uploads" {
  description = "Controls if S3 bucket should deny unencrypted object uploads"
  type        = bool
  default     = false
}

variable "attach_deny_incorrect_encryption_headers" {
  description = "Controls if S3 bucket should deny incorrect encryption headers"
  type        = bool
  default     = false
}

variable "attach_deny_incorrect_kms_key_sse" {
  description = "Controls if S3 bucket should deny incorrect KMS key SSE"
  type        = bool
  default     = false
}

variable "allowed_kms_key_arn" {
  description = "The KMS key ARN that is allowed for SSE-KMS encryption"
  type        = string
  default     = ""
}

variable "attach_policy" {
  description = "Controls if S3 bucket should have bucket policy attached"
  type        = bool
  default     = false
}

variable "policy" {
  description = "Text of the policy"
  type        = string
  default     = ""
}

# Public Access Block
variable "block_public_acls" {
  description = "Whether Amazon S3 should block public ACLs for this bucket"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Whether Amazon S3 should block public bucket policies for this bucket"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Whether Amazon S3 should ignore public ACLs for this bucket"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Whether Amazon S3 should restrict public bucket policies for this bucket"
  type        = bool
  default     = true
}

# Bucket Configuration
variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "versioning" {
  description = "Map containing versioning configuration"
  type        = map(string)
  default     = {}
}

variable "mfa_delete" {
  description = "Enable MFA delete for versioned objects"
  type        = bool
  default     = false
}

# Server-side encryption
variable "encryption_type" {
  description = "Server-side encryption type: 'AES256' or 'aws:kms'"
  type        = string
  default     = "AES256"
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (required if encryption_type is 'aws:kms')"
  type        = string
  default     = ""
}

variable "server_side_encryption_configuration" {
  description = "Map containing server-side encryption configuration"
  type        = any
  default     = {}
}

variable "bucket_key_enabled" {
  description = "Whether or not to use Amazon S3 Bucket Keys for SSE-KMS"
  type        = bool
  default     = false
}

# Object Lock
variable "object_lock_enabled" {
  description = "Whether S3 bucket should have an Object Lock configuration enabled"
  type        = bool
  default     = false
}

variable "object_lock_configuration" {
  description = "Map containing S3 object lock configuration"
  type        = any
  default     = {}
}

# Access Logging
variable "enable_access_logging" {
  description = "Enable S3 access logging (compliance feature)"
  type        = bool
  default     = false
}

variable "access_log_bucket" {
  description = "S3 bucket for access logs (required if enable_access_logging is true)"
  type        = string
  default     = ""
}

variable "logging" {
  description = "Map containing access bucket logging configuration"
  type        = map(string)
  default     = {}
}

# CORS Configuration
variable "cors_rule" {
  description = "List of maps containing rules for Cross-Origin Resource Sharing"
  type        = any
  default     = []
}

# Lifecycle Configuration
variable "lifecycle_rule" {
  description = "List of maps containing configuration of object lifecycle management"
  type        = any
  default     = []
}

# Website Configuration
variable "website" {
  description = "Map containing static web-site hosting or redirect configuration"
  type        = map(string)
  default     = {}
}

# Replication Configuration
variable "replication_configuration" {
  description = "Map containing cross-region replication configuration"
  type        = any
  default     = {}
}

# Transfer Acceleration
variable "acceleration_status" {
  description = "Sets the accelerate configuration of an existing bucket. Can be Enabled or Suspended"
  type        = string
  default     = null
}

# Request Payment
variable "request_payer" {
  description = "Specifies who should bear the cost of Amazon S3 data transfer. Can be BucketOwner or Requester"
  type        = string
  default     = null
}

# ACL
variable "acl" {
  description = "The canned ACL to apply. Conflicts with `grant`"
  type        = string
  default     = null
}

variable "grant" {
  description = "An ACL policy grant. Conflicts with `acl`"
  type        = any
  default     = []
}

variable "owner" {
  description = "Bucket owner's display name and ID. Conflicts with `acl`"
  type        = map(string)
  default     = {}
}

variable "expected_bucket_owner" {
  description = "The account ID of the expected bucket owner"
  type        = string
  default     = ""
}

# Object Ownership
variable "control_object_ownership" {
  description = "Whether to manage S3 Bucket Ownership Controls on this bucket"
  type        = bool
  default     = false
}

variable "object_ownership" {
  description = "Object ownership. Valid values: BucketOwnerEnforced, BucketOwnerPreferred or ObjectWriter"
  type        = string
  default     = "BucketOwnerEnforced"
}

# Intelligent Tiering
variable "intelligent_tiering" {
  description = "Map containing intelligent tiering configuration"
  type        = any
  default     = {}
}

# Metrics Configuration
variable "metric_configuration" {
  description = "Map containing bucket metric configuration"
  type        = any
  default     = []
}

# Inventory Configuration
variable "inventory_configuration" {
  description = "Map containing S3 inventory configuration"
  type        = any
  default     = {}
}

variable "inventory_source_account_id" {
  description = "The ID of the source account for S3 inventory"
  type        = string
  default     = ""
}

variable "inventory_source_bucket_arn" {
  description = "The S3 bucket ARN for inventory source"
  type        = string
  default     = ""
}

variable "inventory_self_source_destination" {
  description = "Whether S3 inventory report buckets are the same"
  type        = bool
  default     = false
}

# Analytics Configuration
variable "analytics_configuration" {
  description = "Map containing bucket analytics configuration"
  type        = any
  default     = {}
}

variable "analytics_source_account_id" {
  description = "The ID of the source account for S3 analytics"
  type        = string
  default     = ""
}

variable "analytics_source_bucket_arn" {
  description = "The S3 bucket ARN for analytics source"
  type        = string
  default     = ""
}

variable "analytics_self_source_destination" {
  description = "Whether S3 analytics report buckets are the same"
  type        = bool
  default     = false
}

# Notification Configuration
variable "notification_configuration" {
  description = "Map containing S3 notification configuration"
  type        = any
  default     = {}
}

# Additional Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}