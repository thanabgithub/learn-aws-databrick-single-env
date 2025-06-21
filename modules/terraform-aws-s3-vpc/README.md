# S3 VPC Module - EC2-like Interface with Enterprise Features

This Terraform module provides an **EC2-like interface** for managing S3 buckets with VPC integration, enhanced with **all official AWS S3 module features**. It encapsulates S3 bucket creation with VPC endpoints, making S3 feel like a VPC-native service similar to EC2, while providing enterprise-grade features for production workloads.

> **📚 Built on Official Foundation**: This module is polished and enhanced based on the official [terraform-aws-modules/terraform-aws-s3-bucket](https://github.com/terraform-aws-modules/terraform-aws-s3-bucket/tree/master) **v4.11.0** release, adding VPC integration and EC2-like interface while maintaining full compatibility with all official module features.

## 🚀 Key Features

- **🔧 EC2-like Configuration**: Specify VPC, subnets, and network settings just like EC2 instances
- **⚡ Preset Configurations**: Choose from predefined setups like EC2 instance types
- **🤖 Auto-Configuration**: Automatically selects subnets and creates IAM profiles
- **🛡️ Security by Default**: Automatic encryption, versioning, and public access blocking
- **💰 Cost-Aware**: Clear distinction between free (gateway) and paid (interface) endpoints
- **🔗 Easy Integration**: Built-in IAM instance profiles for seamless EC2 integration
- **🏢 Enterprise Ready**: All official S3 module features for production workloads

## 🎯 Enhanced Features (New!)

### Advanced S3 Features
- **📊 CORS Support**: Cross-origin resource sharing for web applications
- **⏰ Lifecycle Management**: Advanced rules for cost optimization and compliance
- **🌍 Cross-Region Replication**: Disaster recovery and data distribution
- **🔒 Object Lock**: Compliance-grade immutable storage
- **🚀 Transfer Acceleration**: Global content delivery optimization
- **🧠 Intelligent Tiering**: Automatic cost optimization based on access patterns
- **📈 Analytics & Inventory**: Data governance and usage analytics
- **🌐 Website Hosting**: Static website configuration with routing rules
- **📊 CloudWatch Metrics**: Detailed monitoring and alerting

### Advanced Security Features
- **🔐 Enhanced Encryption**: Support for customer-managed KMS keys
- **🚫 Policy Enforcement**: Deny insecure transport, unencrypted uploads, incorrect headers
- **🛡️ TLS Requirements**: Enforce latest TLS versions
- **👥 Object Ownership**: Advanced ACL and ownership controls
- **🔍 Access Logging**: Comprehensive audit trails
- **📋 Public Access Block**: Granular public access prevention

## 📋 Preset Configurations (Like EC2 Instance Types)

| Preset | Endpoint Type | Encryption | Security | Features | Cost | Use Case |
|--------|---------------|------------|----------|----------|------|----------|
| `cost-optimized` | Gateway | AES256 | Basic | Minimal | **FREE** | Development (like t3.nano) |
| `standard` | Gateway | AES256 | Standard | Basic | **FREE** | General purpose (like t3.medium) |
| `secure` | Interface | KMS | Enhanced | Advanced | Paid | Production (like c5.large) |
| `compliance` | Interface | KMS | Maximum | Enterprise | Paid | Regulated (like m5.xlarge) |

## 🎯 Quick Start Examples

### Super Simple (Like launching t3.micro)
```hcl
module "s3_simple" {
  source = "./modules/s3-vpc"
  
  # Minimal configuration - everything else is automatic
  name_prefix = "my-app"
  vpc_id      = "vpc-12345678"
  
  # Uses "standard" preset by default
  # - Automatically selects private subnets
  # - Creates gateway endpoint (FREE)
  # - Creates IAM instance profile for EC2
}

# Use with EC2 - super simple!
resource "aws_instance" "app" {
  ami                  = "ami-12345678"
  instance_type        = "t3.micro"
  subnet_id            = module.s3_simple.subnet_ids[0]
  iam_instance_profile = module.s3_simple.instance_profile_name
  
  user_data = <<-EOF
    #!/bin/bash
    # S3 access works immediately!
    aws s3 ls s3://${module.s3_simple.bucket_id}/
  EOF
}
```

### Web Application with CORS and Website Hosting
```hcl
module "s3_web_app" {
  source = "./modules/s3-vpc"
  
  name_prefix = "web-app"
  vpc_id      = var.vpc_id
  preset      = "secure"
  
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
      allowed_origins = ["https://example.com"]
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
}
```

### Enterprise Data Lake with Advanced Analytics
```hcl
module "s3_data_lake" {
  source = "./modules/s3-vpc"
  
  name_prefix = "data-lake"
  vpc_id      = var.vpc_id
  preset      = "compliance"
  
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
      }
      optional_fields = [
        "Size", "LastModifiedDate", "StorageClass", 
        "ETag", "IsMultipartUploaded", "ReplicationStatus"
      ]
    }
  }
}
```

### Multi-Region Replication for Disaster Recovery
```hcl
module "s3_primary" {
  source = "./modules/s3-vpc"
  
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
        replica_kms_key_id = aws_kms_key.replica_region.arn
      }
    }
  }
}
```

### Enterprise Compliance with Maximum Security
```hcl
module "s3_enterprise" {
  source = "./modules/s3-vpc"
  
  name_prefix = "enterprise-data"
  vpc_id      = var.vpc_id
  preset      = "compliance"
  
  # Advanced security policies
  attach_deny_insecure_transport_policy   = true
  attach_require_latest_tls_policy        = true
  attach_deny_unencrypted_object_uploads  = true
  attach_deny_incorrect_encryption_headers = true
  attach_deny_incorrect_kms_key_sse       = true
  allowed_kms_key_arn                     = aws_kms_key.enterprise.arn
  
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
}
```

## 📊 Module Interface Comparison

### Traditional S3
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}
# No native VPC integration
# Complex setup for VPC endpoints
# Manual security configuration
# Manual IAM setup
# No advanced features
```

### S3 with This Module (EC2-like + Enterprise)
```hcl
module "s3_vpc" {
  source = "./modules/s3-vpc"
  
  # EC2-like network configuration
  name_prefix = "my-app"
  vpc_id      = "vpc-12345678"
  preset      = "standard"
  
  # Advanced features with simple configuration
  cors_rule = [...]
  lifecycle_rule = [...]
  replication_configuration = {...}
  
  # Everything else is automatic!
}
```

## 🔧 Advanced Configuration Options

### Security Configuration Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `attach_deny_insecure_transport_policy` | Deny non-SSL transport | `false` |
| `attach_require_latest_tls_policy` | Require latest TLS version | `false` |
| `attach_deny_unencrypted_object_uploads` | Deny unencrypted uploads | `false` |
| `attach_deny_incorrect_encryption_headers` | Deny incorrect encryption headers | `false` |
| `attach_deny_incorrect_kms_key_sse` | Deny incorrect KMS key | `false` |
| `control_object_ownership` | Manage object ownership controls | `false` |
| `object_ownership` | Object ownership setting | `"BucketOwnerEnforced"` |

### Advanced Features Variables
| Variable | Description | Type |
|----------|-------------|------|
| `cors_rule` | CORS configuration | `list(object)` |
| `lifecycle_rule` | Lifecycle management rules | `list(object)` |
| `website` | Static website configuration | `map(string)` |
| `replication_configuration` | Cross-region replication | `map(any)` |
| `object_lock_configuration` | Object lock settings | `map(any)` |
| `intelligent_tiering` | Intelligent tiering config | `map(any)` |
| `inventory_configuration` | Inventory reporting | `map(any)` |
| `analytics_configuration` | Storage analytics | `map(any)` |
| `metric_configuration` | CloudWatch metrics | `list(any)` |
| `acceleration_status` | Transfer acceleration | `string` |

### Auto-Configuration Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `auto_select_subnets` | Auto-select private subnets | `true` |
| `auto_select_route_tables` | Auto-select private route tables | `true` |
| `create_instance_profile` | Create IAM profile for EC2 | `true` |
| `create_security_group` | Create security group for interface endpoints | `true` |
| `create_bucket` | Whether to create the S3 bucket | `true` |
| `force_destroy` | Force destroy bucket with objects | `false` |

## 📤 Enhanced Module Outputs

### Basic Outputs
- `bucket_id`, `bucket_arn`, `bucket_domain_name`
- `instance_profile_name`, `iam_role_arn`
- `vpc_endpoint_id`, `security_group_ids`

### Advanced Feature Outputs
- `bucket_website_endpoint`, `bucket_website_domain`
- `bucket_cors_configuration`, `bucket_lifecycle_configuration`
- `bucket_replication_configuration`, `bucket_object_lock_configuration`
- `bucket_intelligent_tiering_configuration`, `bucket_inventory_configuration`
- `bucket_analytics_configuration`, `bucket_metric_configuration`
- `bucket_acceleration_status`, `bucket_versioning_status`
- `bucket_server_side_encryption_configuration`

### Enhanced Summary Outputs
```hcl
output "configuration_summary" {
  value = {
    # Basic configuration
    preset = "secure"
    endpoint_type = "interface"
    
    # Advanced security features
    deny_insecure_transport = true
    require_latest_tls = true
    object_lock_enabled = true
    
    # Additional features
    cors_enabled = true
    lifecycle_enabled = true
    website_enabled = true
    replication_enabled = true
    acceleration_enabled = true
    intelligent_tiering_enabled = true
    # ... and more
  }
}
```

## 💡 Usage Patterns

### Pattern 1: Simple Application Storage
```hcl
module "app_storage" {
  source = "./modules/s3-vpc"
  
  name_prefix = "myapp"
  vpc_id      = var.vpc_id
  preset      = "standard"  # FREE
}
```

### Pattern 2: Web Application with CDN
```hcl
module "web_app" {
  source = "./modules/s3-vpc"
  
  name_prefix = "webapp"
  vpc_id      = var.vpc_id
  preset      = "secure"
  
  website = {
    index_document = "index.html"
    error_document = "error.html"
  }
  
  cors_rule = [
    {
      allowed_methods = ["GET", "POST"]
      allowed_origins = ["https://example.com"]
      allowed_headers = ["*"]
    }
  ]
  
  acceleration_status = "Enabled"
}
```

### Pattern 3: Data Lake with Analytics
```hcl
module "data_lake" {
  source = "./modules/s3-vpc"
  
  name_prefix = "datalake"
  vpc_id      = var.vpc_id
  preset      = "compliance"
  
  intelligent_tiering = {
    analytics = {
      status = "Enabled"
      tiering = {
        ARCHIVE_ACCESS = { days = 90 }
        DEEP_ARCHIVE_ACCESS = { days = 180 }
      }
    }
  }
  
  inventory_configuration = {
    daily_inventory = {
      included_object_versions = "All"
      frequency = "Daily"
      destination = {
        bucket_arn = aws_s3_bucket.reports.arn
        format = "CSV"
      }
    }
  }
}
```

### Pattern 4: Multi-Environment with Different Presets
```hcl
module "s3_dev" {
  source = "./modules/s3-vpc"
  
  name_prefix = "myapp-dev"
  vpc_id      = var.dev_vpc_id
  preset      = "cost-optimized"  # Minimal cost
  environment = "development"
}

module "s3_prod" {
  source = "./modules/s3-vpc"
  
  name_prefix = "myapp-prod"
  vpc_id      = var.prod_vpc_id
  preset      = "compliance"  # Maximum security
  environment = "production"
  
  # Production-specific advanced features
  object_lock_enabled = true
  replication_configuration = {
    role = aws_iam_role.replication.arn
    rule = {
      id = "backup"
      status = "Enabled"
      destination = {
        bucket = module.s3_backup.bucket_arn
        storage_class = "GLACIER"
      }
    }
  }
}
```

## 💰 Cost Optimization

### Free Features
- **Gateway Endpoints**: No additional charges
- **Basic encryption (AES256)**: No additional charges
- **Lifecycle transitions**: Reduce storage costs automatically
- **Intelligent Tiering**: Automatic cost optimization

### Paid Features (Interface Endpoints)
- **Interface Endpoints**: $0.01/hour per AZ + data transfer
- **Transfer Acceleration**: Additional data transfer charges
- **Cross-Region Replication**: Storage and transfer charges in destination region

### Cost Optimization Strategies
```hcl
# Use lifecycle rules for automatic cost reduction
lifecycle_rule = [
  {
    id = "cost_optimization"
    enabled = true
    
    transition = [
      {
        days = 30
        storage_class = "STANDARD_IA"  # 40% cost reduction
      },
      {
        days = 90
        storage_class = "GLACIER"      # 80% cost reduction
      },
      {
        days = 365
        storage_class = "DEEP_ARCHIVE" # 95% cost reduction
      }
    ]
  }
]

# Use intelligent tiering for automatic optimization
intelligent_tiering = {
  cost_optimization = {
    status = "Enabled"
    tiering = {
      ARCHIVE_ACCESS = { days = 90 }
      DEEP_ARCHIVE_ACCESS = { days = 180 }
    }
  }
}
```

## 🚀 Migration Guide

### From Standard S3 to VPC-Integrated S3

1. **Replace existing S3 resources**:
   ```hcl
   # Before
   resource "aws_s3_bucket" "app" {
     bucket = "my-app-bucket"
   }
   
   # After
   module "s3_app" {
     source = "./modules/s3-vpc"
     
     name_prefix = "my-app"
     vpc_id      = var.vpc_id
     preset      = "standard"
   }
   ```

2. **Add advanced features gradually**:
   ```hcl
   module "s3_app" {
     source = "./modules/s3-vpc"
     
     name_prefix = "my-app"
     vpc_id      = var.vpc_id
     preset      = "standard"
     
     # Add features as needed
     cors_rule = [...]           # For web applications
     lifecycle_rule = [...]      # For cost optimization
     replication_configuration = {...}  # For disaster recovery
   }
   ```

3. **Update EC2 instances**:
   ```hcl
   resource "aws_instance" "app" {
     # ... other configuration ...
     iam_instance_profile = module.s3_app.instance_profile_name
   }
   ```

### From Official S3 Module to S3-VPC Module

This module is **fully compatible** with the official AWS S3 module variables:

```hcl
# Official S3 module variables work directly
module "s3_vpc" {
  source = "./modules/s3-vpc"
  
  # VPC-specific (new)
  vpc_id = var.vpc_id
  preset = "secure"
  
  # Official S3 module variables (compatible)
  versioning = {
    enabled = true
    mfa_delete = false
  }
  
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "aws:kms"
        kms_master_key_id = aws_kms_key.example.arn
      }
    }
  }
  
  cors_rule = [...]
  lifecycle_rule = [...]
  # ... all other official module variables
}
```

## 🔍 Troubleshooting

### Common Issues

1. **Access Denied**: Check VPC endpoint policy and bucket policy
2. **Connection Timeout**: Verify route tables (gateway) or security groups (interface)
3. **DNS Resolution**: Ensure private DNS is enabled for interface endpoints
4. **CORS Errors**: Verify CORS configuration matches your application's origin
5. **Lifecycle Not Working**: Check IAM permissions and rule syntax

### Debug Commands
```bash
# Test S3 access from EC2
aws s3 ls s3://BUCKET_NAME/

# Check endpoint connectivity
aws s3 ls s3://BUCKET_NAME/ --endpoint-url ENDPOINT_URL

# Verify IAM permissions
aws sts get-caller-identity

# Test website endpoint
curl -I http://BUCKET_NAME.s3-website-REGION.amazonaws.com/

# Check CORS configuration
curl -H "Origin: https://example.com" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS \
     https://BUCKET_NAME.s3.amazonaws.com/
```

## 📚 Complete Feature Matrix

| Feature | Standard | Secure | Compliance | Notes |
|---------|----------|--------|------------|-------|
| **VPC Endpoint** | Gateway (FREE) | Interface (Paid) | Interface (Paid) | Network isolation |
| **Encryption** | AES256 | KMS | KMS | Customer-managed keys |
| **Versioning** | ✅ | ✅ | ✅ | Required for replication |
| **Public Access Block** | ✅ | ✅ | ✅ | Security by default |
| **Instance Profile** | ✅ | ✅ | ✅ | EC2 integration |
| **Access Logging** | ❌ | ❌ | ✅ | Compliance requirement |
| **Object Lock** | ❌ | ❌ | ✅ | Immutable storage |
| **Deny Insecure Transport** | ❌ | ✅ | ✅ | HTTPS enforcement |
| **TLS Version Enforcement** | ❌ | ✅ | ✅ | Latest TLS only |
| **Encryption Enforcement** | ❌ | ✅ | ✅ | Mandatory encryption |
| **CORS Support** | ✅ | ✅ | ✅ | Web application support |
| **Lifecycle Management** | ✅ | ✅ | ✅ | Cost optimization |
| **Website Hosting** | ✅ | ✅ | ✅ | Static website support |
| **Cross-Region Replication** | ✅ | ✅ | ✅ | Disaster recovery |
| **Transfer Acceleration** | ✅ | ✅ | ✅ | Global performance |
| **Intelligent Tiering** | ✅ | ✅ | ✅ | Automatic cost optimization |
| **Inventory & Analytics** | ✅ | ✅ | ✅ | Data governance |
| **CloudWatch Metrics** | ✅ | ✅ | ✅ | Monitoring and alerting |

## 📄 License

MIT

---

**Ready to get started?** Choose your preset and deploy enterprise-grade S3 with VPC integration in minutes! 🚀