# example/main.tf

# Example usage of the S3 VPC module with official S3 module features
# Notice how the interface is similar to EC2 configuration but with advanced S3 features

# Your VPC configuration (prerequisite)
data "aws_vpc" "main" {
  id = "vpc-12345678"  # Your VPC ID
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  tags = {
    Type = "private"
  }
}

data "aws_route_tables" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  tags = {
    Type = "private"
  }
}

# ===================================================================
# EXAMPLE 1: Super Simple - Like launching a t3.micro EC2 instance
# ===================================================================

module "s3_simple" {
  source = "../modules/s3-vpc"
  
  # Minimal configuration - everything else is automatic
  name_prefix = "my-app"
  vpc_id      = "vpc-12345678"  # Your VPC ID
  
  # That's it! Uses "standard" preset by default
  # - Automatically selects private subnets
  # - Creates gateway endpoint (FREE)
  # - Creates IAM instance profile for EC2
  # - Enables encryption and versioning
}

# Use with EC2 instance - super simple!
resource "aws_instance" "app_simple" {
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = "t3.micro"
  subnet_id            = module.s3_simple.subnet_ids[0]
  iam_instance_profile = module.s3_simple.instance_profile_name
  
  user_data = <<-EOF
    #!/bin/bash
    # S3 access works immediately!
    aws s3 ls s3://${module.s3_simple.bucket_id}/
    echo "Hello from EC2" | aws s3 cp - s3://${module.s3_simple.bucket_id}/hello.txt
  EOF
  
  tags = {
    Name = "simple-app-server"
  }
}

# ===================================================================
# EXAMPLE 2: Advanced Web Application with CORS and Website Hosting
# ===================================================================

module "s3_web_app" {
  source = "../modules/s3-vpc"
  
  name_prefix = "web-app"
  vpc_id      = var.vpc_id
  preset      = "secure"  # Interface endpoint with enhanced security
  
  # Website configuration
  website = {
    index_document = "index.html"
    error_document = "error.html"
  }
  
  # CORS configuration for web applications
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "PUT", "POST"]
      allowed_origins = ["https://example.com", "https://www.example.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
  
  # Lifecycle rules for cost optimization
  lifecycle_rule = [
    {
      id      = "log_files"
      enabled = true
      
      filter = {
        prefix = "logs/"
      }
      
      expiration = {
        days = 90
      }
      
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
      
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 60
          storage_class = "GLACIER"
        }
      ]
    }
  ]
  
  tags = {
    Application = "WebApp"
    Environment = "Production"
  }
}

# CloudFront distribution for the web app
resource "aws_cloudfront_distribution" "web_app" {
  origin {
    domain_name = module.s3_web_app.bucket_domain_name
    origin_id   = "S3-${module.s3_web_app.bucket_id}"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.web_app.cloudfront_access_identity_path
    }
  }
  
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${module.s3_web_app.bucket_id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "web_app" {
  comment = "OAI for ${module.s3_web_app.bucket_id}"
}

# ===================================================================
# EXAMPLE 3: Data Lake with Advanced Analytics and Monitoring
# ===================================================================

module "s3_data_lake" {
  source = "../modules/s3-vpc"
  
  name_prefix = "data-lake"
  vpc_id      = var.vpc_id
  preset      = "compliance"  # Maximum security for sensitive data
  
  # Advanced encryption with customer-managed KMS key
  encryption_type = "aws:kms"
  kms_key_id     = aws_kms_key.data_lake.id
  
  # Object lock for compliance
  object_lock_enabled = true
  object_lock_configuration = {
    rule = {
      default_retention = {
        mode = "GOVERNANCE"
        days = 365
      }
    }
  }
  
  # Intelligent tiering for cost optimization
  intelligent_tiering = {
    general_purpose = {
      status = "Enabled"
      filter = {
        prefix = "analytics/"
      }
      tiering = {
        ARCHIVE_ACCESS = {
          days = 90
        }
        DEEP_ARCHIVE_ACCESS = {
          days = 180
        }
      }
    }
  }
  
  # Inventory configuration for data governance
  inventory_configuration = {
    analytics_inventory = {
      included_object_versions = "All"
      frequency               = "Daily"
      destination = {
        bucket_arn = aws_s3_bucket.inventory_reports.arn
        format     = "CSV"
        prefix     = "inventory-reports/"
        encryption = {
          encryption_type = "sse_s3"
        }
      }
      optional_fields = [
        "Size", "LastModifiedDate", "StorageClass", 
        "ETag", "IsMultipartUploaded", "ReplicationStatus"
      ]
    }
  }
  
  # Analytics configuration
  analytics_configuration = {
    data_analytics = {
      storage_class_analysis = {
        output_schema_version = "V_1"
        destination_bucket_arn = aws_s3_bucket.analytics_reports.arn
        export_format         = "CSV"
        export_prefix         = "analytics-reports/"
      }
    }
  }
  
  # Metrics configuration
  metric_configuration = [
    {
      name = "data_lake_metrics"
      filter = {
        prefix = "raw-data/"
      }
    }
  ]
  
  # Advanced lifecycle rules for data lake
  lifecycle_rule = [
    {
      id      = "raw_data_lifecycle"
      enabled = true
      
      filter = {
        prefix = "raw-data/"
      }
      
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
    },
    {
      id      = "processed_data_lifecycle"
      enabled = true
      
      filter = {
        prefix = "processed-data/"
      }
      
      transition = [
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      
      expiration = {
        days = 2555  # 7 years for compliance
      }
    }
  ]
  
  tags = {
    DataClassification = "Sensitive"
    Compliance        = "Required"
    CostCenter        = "Analytics"
  }
}

# KMS key for data lake encryption
resource "aws_kms_key" "data_lake" {
  description             = "KMS key for data lake encryption"
  deletion_window_in_days = 7
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name = "data-lake-encryption-key"
  }
}

resource "aws_kms_alias" "data_lake" {
  name          = "alias/data-lake"
  target_key_id = aws_kms_key.data_lake.key_id
}

# Supporting buckets for analytics
resource "aws_s3_bucket" "inventory_reports" {
  bucket = "inventory-reports-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "analytics_reports" {
  bucket = "analytics-reports-${data.aws_caller_identity.current.account_id}"
}

# ===================================================================
# EXAMPLE 4: Multi-Region Replication for Disaster Recovery
# ===================================================================

module "s3_primary" {
  source = "../modules/s3-vpc"
  
  name_prefix = "primary-data"
  vpc_id      = var.primary_vpc_id
  preset      = "secure"
  
  # Enable versioning (required for replication)
  enable_versioning = true
  
  # Replication configuration
  replication_configuration = {
    role = aws_iam_role.replication.arn
    
    rule = {
      id       = "disaster_recovery"
      status   = "Enabled"
      priority = 1
      
      destination = {
        bucket        = module.s3_replica.bucket_arn
        storage_class = "STANDARD_IA"
        
        # Replicate to different region for DR
        replica_kms_key_id = aws_kms_key.replica_region.arn
      }
      
      source_selection_criteria = {
        sse_kms_encrypted_objects = {
          status = "Enabled"
        }
      }
    }
  }
  
  tags = {
    Region = "Primary"
    DR     = "Source"
  }
}

module "s3_replica" {
  source = "../modules/s3-vpc"
  
  providers = {
    aws = aws.replica_region
  }
  
  name_prefix = "replica-data"
  vpc_id      = var.replica_vpc_id
  preset      = "secure"
  
  # Enable versioning for replica
  enable_versioning = true
  
  tags = {
    Region = "Replica"
    DR     = "Target"
  }
}

# IAM role for replication
resource "aws_iam_role" "replication" {
  name = "s3-replication-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "s3-replication-policy"
  role = aws_iam_role.replication.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = "${module.s3_primary.bucket_arn}/*"
      },
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = module.s3_primary.bucket_arn
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = "${module.s3_replica.bucket_arn}/*"
      }
    ]
  })
}

# KMS key for replica region
resource "aws_kms_key" "replica_region" {
  provider                = aws.replica_region
  description             = "KMS key for replica region"
  deletion_window_in_days = 7
}

# ===================================================================
# EXAMPLE 5: Content Delivery with Transfer Acceleration
# ===================================================================

module "s3_cdn" {
  source = "../modules/s3-vpc"
  
  name_prefix = "cdn-content"
  vpc_id      = var.vpc_id
  preset      = "standard"
  
  # Enable transfer acceleration for global content delivery
  acceleration_status = "Enabled"
  
  # Website configuration for static content
  website = {
    index_document = "index.html"
    error_document = "404.html"
    
    routing_rules = [
      {
        condition = {
          key_prefix_equals = "docs/"
        }
        redirect = {
          replace_key_prefix_with = "documents/"
        }
      }
    ]
  }
  
  # CORS for global access
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["*"]
      max_age_seconds = 86400
    }
  ]
  
  # Lifecycle for content optimization
  lifecycle_rule = [
    {
      id      = "content_optimization"
      enabled = true
      
      filter = {
        prefix = "assets/"
      }
      
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
    }
  ]
  
  tags = {
    Purpose = "CDN"
    Global  = "true"
  }
}

# ===================================================================
# EXAMPLE 6: Enterprise Compliance with Advanced Security
# ===================================================================

module "s3_enterprise" {
  source = "../modules/s3-vpc"
  
  name_prefix = "enterprise-data"
  vpc_id      = var.vpc_id
  preset      = "compliance"
  
  # Force destroy for demo (NEVER use in production)
  force_destroy = false
  
  # Advanced security policies
  attach_deny_insecure_transport_policy   = true
  attach_require_latest_tls_policy        = true
  attach_deny_unencrypted_object_uploads  = true
  attach_deny_incorrect_encryption_headers = true
  attach_deny_incorrect_kms_key_sse       = true
  allowed_kms_key_arn                     = aws_kms_key.enterprise.arn
  
  # Custom bucket policy
  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireSSLRequestsOnly"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::enterprise-data-*",
          "arn:aws:s3:::enterprise-data-*/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
  
  # Object ownership controls
  control_object_ownership = true
  object_ownership        = "BucketOwnerEnforced"
  
  # Access logging for audit
  enable_access_logging = true
  access_log_bucket    = aws_s3_bucket.audit_logs.id
  
  # Advanced logging configuration
  logging = {
    target_bucket = aws_s3_bucket.audit_logs.id
    target_prefix = "enterprise-access-logs/"
    target_object_key_format = {
      partitioned_prefix = {
        partition_date_source = "EventTime"
      }
    }
  }
  
  tags = {
    Compliance     = "SOX"
    DataRetention  = "7years"
    SecurityLevel  = "Maximum"
  }
}

# KMS key for enterprise encryption
resource "aws_kms_key" "enterprise" {
  description             = "Enterprise encryption key"
  deletion_window_in_days = 30
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name = "enterprise-encryption-key"
  }
}

# ===================================================================
# Supporting Resources
# ===================================================================

# Audit logs bucket for compliance
resource "aws_s3_bucket" "audit_logs" {
  bucket = "audit-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "prod_audit_logs" {
  bucket = "prod-audit-logs-${data.aws_caller_identity.current.account_id}"
}

# Security group for custom example
resource "aws_security_group" "app_servers" {
  name_prefix = "app-servers-"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

# Data sources
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

data "aws_caller_identity" "current" {}

# Provider for replica region
provider "aws" {
  alias  = "replica_region"
  region = "us-west-2"  # Different region for DR
}

# ===================================================================
# Outputs - Show the power of the enhanced module
# ===================================================================

output "simple_example" {
  description = "Simple example - ready to use immediately"
  value = {
    bucket_name          = module.s3_simple.bucket_id
    instance_profile     = module.s3_simple.instance_profile_name
    endpoint_type        = module.s3_simple.vpc_endpoint_type
    cost                = module.s3_simple.quick_start.cost_info
    test_command        = "aws s3 ls s3://${module.s3_simple.bucket_id}/"
  }
}

output "web_app_example" {
  description = "Web application with CORS and website hosting"
  value = {
    bucket_name       = module.s3_web_app.bucket_id
    website_endpoint  = module.s3_web_app.bucket_website_endpoint
    cors_enabled      = module.s3_web_app.configuration_summary.cors_enabled
    lifecycle_enabled = module.s3_web_app.configuration_summary.lifecycle_enabled
    cloudfront_domain = aws_cloudfront_distribution.web_app.domain_name
  }
}

output "data_lake_example" {
  description = "Enterprise data lake with advanced features"
  value = {
    bucket_name           = module.s3_data_lake.bucket_id
    object_lock_enabled   = module.s3_data_lake.configuration_summary.object_lock_enabled
    intelligent_tiering   = module.s3_data_lake.configuration_summary.intelligent_tiering_enabled
    inventory_enabled     = module.s3_data_lake.configuration_summary.inventory_enabled
    analytics_enabled     = module.s3_data_lake.configuration_summary.analytics_enabled
    encryption_key        = aws_kms_key.data_lake.id
  }
}

output "replication_example" {
  description = "Multi-region replication for disaster recovery"
  value = {
    primary_bucket   = module.s3_primary.bucket_id
    replica_bucket   = module.s3_replica.bucket_id
    replication_role = aws_iam_role.replication.arn
  }
}

output "cdn_example" {
  description = "Content delivery with transfer acceleration"
  value = {
    bucket_name         = module.s3_cdn.bucket_id
    website_endpoint    = module.s3_cdn.bucket_website_endpoint
    acceleration_status = module.s3_cdn.bucket_acceleration_status
    cors_enabled        = module.s3_cdn.configuration_summary.cors_enabled
  }
}

output "enterprise_example" {
  description = "Enterprise compliance with maximum security"
  value = {
    bucket_name       = module.s3_enterprise.bucket_id
    security_level    = module.s3_enterprise.quick_start.security_level
    compliance_features = {
      object_lock       = module.s3_enterprise.configuration_summary.object_lock_enabled
      access_logging    = module.s3_enterprise.configuration_summary.access_logging_enabled
      encryption        = "Customer-managed KMS"
      policy_enforcement = "Maximum"
    }
  }
}

output "comprehensive_features" {
  description = "Comprehensive overview of all implemented features"
  value = {
    basic_features = {
      vpc_integration    = "✅ Gateway and Interface endpoints"
      ec2_integration   = "✅ Automatic IAM instance profiles"
      auto_configuration = "✅ Subnet and route table selection"
      presets           = "✅ standard, secure, compliance, cost-optimized"
    }
    
    advanced_s3_features = {
      versioning           = "✅ Enhanced versioning control"
      encryption          = "✅ AES256 and KMS encryption"
      lifecycle_management = "✅ Advanced lifecycle rules"
      cors_support        = "✅ Cross-origin resource sharing"
      website_hosting     = "✅ Static website configuration"
      replication         = "✅ Cross-region replication"
      object_lock         = "✅ Compliance-grade retention"
      transfer_acceleration = "✅ Global content delivery"
      intelligent_tiering = "✅ Automatic cost optimization"
      inventory_analytics = "✅ Data governance and analytics"
      metrics_monitoring  = "✅ CloudWatch metrics"
      access_logging      = "✅ Audit trail"
    }
    
    security_features = {
      public_access_block = "✅ Comprehensive public access prevention"
      bucket_policies     = "✅ Advanced policy enforcement"
      encryption_enforcement = "✅ Mandatory encryption policies"
      tls_enforcement     = "✅ Secure transport requirements"
      object_ownership    = "✅ ACL and ownership controls"
      vpc_only_access     = "✅ Network-level isolation"
    }
  }
}

output "migration_guide" {
  description = "Guide for migrating from standard S3 to VPC-integrated S3"
  value = {
    step_1 = "Choose appropriate preset based on requirements"
    step_2 = "Configure VPC and subnet parameters"
    step_3 = "Set up advanced features (CORS, lifecycle, etc.) as needed"
    step_4 = "Update EC2 instances to use generated instance profile"
    step_5 = "Test connectivity and adjust security groups if needed"
    
    presets_guide = {
      cost_optimized = "Development environments, minimal features"
      standard      = "General purpose applications, gateway endpoint"
      secure        = "Production applications, interface endpoint + KMS"
      compliance    = "Regulated environments, maximum security + audit"
    }
  }
}