# modules/s3-vpc/main.tf

# Data sources
data "aws_region" "current" {}
data "aws_vpc" "selected" {
  id = var.vpc_id
}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_canonical_user_id" "this" {
  count = local.create_bucket && local.create_bucket_acl && try(var.owner["id"], null) == null ? 1 : 0
}

# Enhanced locals with official module patterns
locals {
  create_bucket = var.create_bucket

  # Preset configurations (like EC2 instance types) - Enhanced
  preset_configs = {
    standard = {
      endpoint_type                           = "gateway"
      encryption_type                         = "AES256"
      enable_versioning                       = true
      restrict_to_vpc                         = true
      create_instance_profile                 = true
      enable_access_logging                   = false
      attach_deny_insecure_transport_policy   = false
      attach_require_latest_tls_policy        = false
      attach_deny_unencrypted_object_uploads  = false
      object_lock_enabled                     = false
      control_object_ownership                = true
      object_ownership                        = "BucketOwnerEnforced"
    }
    secure = {
      endpoint_type                           = "interface"
      encryption_type                         = "aws:kms"
      enable_versioning                       = true
      restrict_to_vpc                         = true
      create_instance_profile                 = true
      enable_access_logging                   = false
      attach_deny_insecure_transport_policy   = true
      attach_require_latest_tls_policy        = true
      attach_deny_unencrypted_object_uploads  = true
      object_lock_enabled                     = false
      control_object_ownership                = true
      object_ownership                        = "BucketOwnerEnforced"
    }
    compliance = {
      endpoint_type                           = "interface"
      encryption_type                         = "aws:kms"
      enable_versioning                       = true
      restrict_to_vpc                         = true
      create_instance_profile                 = true
      enable_access_logging                   = true
      attach_deny_insecure_transport_policy   = true
      attach_require_latest_tls_policy        = true
      attach_deny_unencrypted_object_uploads  = true
      attach_deny_incorrect_encryption_headers = true
      object_lock_enabled                     = true
      control_object_ownership                = true
      object_ownership                        = "BucketOwnerEnforced"
    }
    cost-optimized = {
      endpoint_type                           = "gateway"
      encryption_type                         = "AES256"
      enable_versioning                       = false
      restrict_to_vpc                         = false
      create_instance_profile                 = false
      enable_access_logging                   = false
      attach_deny_insecure_transport_policy   = false
      attach_require_latest_tls_policy        = false
      attach_deny_unencrypted_object_uploads  = false
      object_lock_enabled                     = false
      control_object_ownership                = false
      object_ownership                        = "BucketOwnerEnforced"
    }
  }
  
  # Apply preset configuration, but allow variable overrides
  config = local.preset_configs[var.preset]
  
  # Final configuration with variable overrides
  final_endpoint_type                         = var.endpoint_type != "" ? var.endpoint_type : local.config.endpoint_type
  final_encryption_type                       = var.encryption_type != "AES256" ? var.encryption_type : local.config.encryption_type
  final_enable_versioning                     = var.enable_versioning != true ? var.enable_versioning : local.config.enable_versioning
  final_restrict_to_vpc                       = var.restrict_to_vpc != true ? var.restrict_to_vpc : local.config.restrict_to_vpc
  final_create_instance_profile               = var.create_instance_profile != true ? var.create_instance_profile : local.config.create_instance_profile
  final_enable_access_logging                 = var.enable_access_logging != false ? var.enable_access_logging : local.config.enable_access_logging
  final_attach_deny_insecure_transport_policy = var.attach_deny_insecure_transport_policy != false ? var.attach_deny_insecure_transport_policy : local.config.attach_deny_insecure_transport_policy
  final_attach_require_latest_tls_policy      = var.attach_require_latest_tls_policy != false ? var.attach_require_latest_tls_policy : local.config.attach_require_latest_tls_policy
  final_attach_deny_unencrypted_object_uploads = var.attach_deny_unencrypted_object_uploads != false ? var.attach_deny_unencrypted_object_uploads : local.config.attach_deny_unencrypted_object_uploads
  final_object_lock_enabled                   = var.object_lock_enabled != false ? var.object_lock_enabled : local.config.object_lock_enabled
  final_control_object_ownership              = var.control_object_ownership != false ? var.control_object_ownership : local.config.control_object_ownership
  final_object_ownership                      = var.object_ownership != "BucketOwnerEnforced" ? var.object_ownership : local.config.object_ownership
  
  # Generate unique bucket name if not provided
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.name_prefix}-${random_string.bucket_suffix[0].result}"
  
  # Determine endpoint type
  use_gateway_endpoint = local.final_endpoint_type == "gateway" || local.final_endpoint_type == "auto"
  use_interface_endpoint = local.final_endpoint_type == "interface"
  
  # Generate instance profile name
  instance_profile_name = var.instance_profile_name != "" ? var.instance_profile_name : "${var.name_prefix}-ec2-s3-profile"

  # ACL and policy management (from official module)
  create_bucket_acl = (var.acl != null && var.acl != "null") || length(local.grants) > 0
  grants = try(jsondecode(var.grant), var.grant)
  cors_rules = try(jsondecode(var.cors_rule), var.cors_rule)
  lifecycle_rules = try(jsondecode(var.lifecycle_rule), var.lifecycle_rule)
  intelligent_tiering = try(jsondecode(var.intelligent_tiering), var.intelligent_tiering)
  metric_configuration = try(jsondecode(var.metric_configuration), var.metric_configuration)

  # Enhanced policy attachment logic
  attach_policy = (
    local.final_attach_deny_insecure_transport_policy ||
    local.final_attach_require_latest_tls_policy ||
    local.final_attach_deny_unencrypted_object_uploads ||
    var.attach_deny_incorrect_encryption_headers ||
    var.attach_deny_incorrect_kms_key_sse ||
    var.attach_policy ||
    local.final_restrict_to_vpc
  )
}

# Auto-discovery of subnets and route tables (EC2-like behavior)
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "private" {
  count = length(var.subnet_ids) == 0 && var.auto_select_subnets ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private", "Private"]
  }
}

data "aws_route_tables" "private" {
  count = length(var.route_table_ids) == 0 && var.auto_select_route_tables ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private", "Private"]
  }
}

locals {
  # EC2-like automatic subnet and route table selection
  selected_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : (
    var.auto_select_subnets && length(data.aws_subnets.private) > 0 ? data.aws_subnets.private[0].ids : []
  )
  
  selected_route_table_ids = length(var.route_table_ids) > 0 ? var.route_table_ids : (
    var.auto_select_route_tables && length(data.aws_route_tables.private) > 0 ? data.aws_route_tables.private[0].ids : []
  )
}

# Random string for bucket naming
resource "random_string" "bucket_suffix" {
  count   = var.bucket_name == "" ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket (Enhanced from official module)
resource "aws_s3_bucket" "this" {
  count = local.create_bucket ? 1 : 0

  bucket        = var.bucket_name != "" ? var.bucket_name : null
  bucket_prefix = var.bucket_prefix != "" ? var.bucket_prefix : "${var.name_prefix}-"

  force_destroy       = var.force_destroy
  object_lock_enabled = local.final_object_lock_enabled
  
  tags = merge(
    var.tags,
    {
      Name        = local.bucket_name
      VPC         = var.vpc_id
      Environment = var.environment
      Preset      = var.preset
    }
  )
}

# Bucket versioning (Enhanced)
resource "aws_s3_bucket_versioning" "this" {
  count = local.create_bucket && (local.final_enable_versioning || length(keys(var.versioning)) > 0) ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner
  mfa                   = try(var.versioning["mfa"], null)

  versioning_configuration {
    status = local.final_enable_versioning ? "Enabled" : try(
      var.versioning["enabled"] ? "Enabled" : "Suspended", 
      tobool(var.versioning["status"]) ? "Enabled" : "Suspended", 
      title(lower(var.versioning["status"])), 
      "Enabled"
    )
    mfa_delete = try(
      tobool(var.versioning["mfa_delete"]) ? "Enabled" : "Disabled", 
      title(lower(var.versioning["mfa_delete"])), 
      var.mfa_delete ? "Enabled" : "Disabled",
      null
    )
  }
}

# Bucket encryption (Enhanced)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = local.create_bucket ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner

  dynamic "rule" {
    for_each = length(keys(var.server_side_encryption_configuration)) > 0 ? 
      try(flatten([var.server_side_encryption_configuration["rule"]]), []) : 
      [{}]

    content {
      bucket_key_enabled = try(rule.value.bucket_key_enabled, var.bucket_key_enabled, null)

      apply_server_side_encryption_by_default {
        sse_algorithm     = try(rule.value.apply_server_side_encryption_by_default.sse_algorithm, local.final_encryption_type)
        kms_master_key_id = try(
          rule.value.apply_server_side_encryption_by_default.kms_master_key_id,
          local.final_encryption_type == "aws:kms" ? var.kms_key_id : null
        )
      }
    }
  }
}

# Public Access Block (Enhanced)
resource "aws_s3_bucket_public_access_block" "this" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# Object Ownership Controls (New from official module)
resource "aws_s3_bucket_ownership_controls" "this" {
  count = local.create_bucket && local.final_control_object_ownership ? 1 : 0

  bucket = local.attach_policy ? aws_s3_bucket_policy.combined[0].id : aws_s3_bucket.this[0].id

  rule {
    object_ownership = local.final_object_ownership
  }

  depends_on = [
    aws_s3_bucket_policy.combined,
    aws_s3_bucket_public_access_block.this,
    aws_s3_bucket.this
  ]
}

# ACL Configuration (New from official module)
resource "aws_s3_bucket_acl" "this" {
  count = local.create_bucket && local.create_bucket_acl ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner
  acl                   = var.acl == "null" ? null : var.acl

  dynamic "access_control_policy" {
    for_each = length(local.grants) > 0 ? [true] : []

    content {
      dynamic "grant" {
        for_each = local.grants

        content {
          permission = grant.value.permission

          grantee {
            type          = grant.value.type
            id            = try(grant.value.id, null)
            uri           = try(grant.value.uri, null)
            email_address = try(grant.value.email, null)
          }
        }
      }

      owner {
        id           = try(var.owner["id"], data.aws_canonical_user_id.this[0].id)
        display_name = try(var.owner["display_name"], null)
      }
    }
  }

  depends_on = [aws_s3_bucket_ownership_controls.this]
}

# CORS Configuration (New from official module)
resource "aws_s3_bucket_cors_configuration" "this" {
  count = local.create_bucket && length(local.cors_rules) > 0 ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner

  dynamic "cors_rule" {
    for_each = local.cors_rules

    content {
      id              = try(cors_rule.value.id, null)
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = try(cors_rule.value.allowed_headers, null)
      expose_headers  = try(cors_rule.value.expose_headers, null)
      max_age_seconds = try(cors_rule.value.max_age_seconds, null)
    }
  }
}

# Lifecycle Configuration (New from official module)
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = local.create_bucket && length(local.lifecycle_rules) > 0 ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = try(rule.value.id, null)
      status = try(rule.value.enabled ? "Enabled" : "Disabled", tobool(rule.value.status) ? "Enabled" : "Disabled", title(lower(rule.value.status)))

      dynamic "abort_incomplete_multipart_upload" {
        for_each = try([rule.value.abort_incomplete_multipart_upload_days], [])
        content {
          days_after_initiation = try(rule.value.abort_incomplete_multipart_upload_days, null)
        }
      }

      dynamic "expiration" {
        for_each = try(flatten([rule.value.expiration]), [])
        content {
          date                         = try(expiration.value.date, null)
          days                         = try(expiration.value.days, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      dynamic "transition" {
        for_each = try(flatten([rule.value.transition]), [])
        content {
          date          = try(transition.value.date, null)
          days          = try(transition.value.days, null)
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = try(flatten([rule.value.noncurrent_version_expiration]), [])
        content {
          newer_noncurrent_versions = try(noncurrent_version_expiration.value.newer_noncurrent_versions, null)
          noncurrent_days           = try(noncurrent_version_expiration.value.days, noncurrent_version_expiration.value.noncurrent_days, null)
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = try(flatten([rule.value.noncurrent_version_transition]), [])
        content {
          newer_noncurrent_versions = try(noncurrent_version_transition.value.newer_noncurrent_versions, null)
          noncurrent_days           = try(noncurrent_version_transition.value.days, noncurrent_version_transition.value.noncurrent_days, null)
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      # Filter configurations
      dynamic "filter" {
        for_each = length(try(flatten([rule.value.filter]), [])) == 0 ? [true] : []
        content {}
      }

      dynamic "filter" {
        for_each = [for v in try(flatten([rule.value.filter]), []) : v if max(length(keys(v)), length(try(rule.value.filter.tags, rule.value.filter.tag, []))) == 1]
        content {
          object_size_greater_than = try(filter.value.object_size_greater_than, null)
          object_size_less_than    = try(filter.value.object_size_less_than, null)
          prefix                   = try(filter.value.prefix, null)

          dynamic "tag" {
            for_each = try(filter.value.tags, filter.value.tag, [])
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      dynamic "filter" {
        for_each = [for v in try(flatten([rule.value.filter]), []) : v if max(length(keys(v)), length(try(rule.value.filter.tags, rule.value.filter.tag, []))) > 1]
        content {
          and {
            object_size_greater_than = try(filter.value.object_size_greater_than, null)
            object_size_less_than    = try(filter.value.object_size_less_than, null)
            prefix                   = try(filter.value.prefix, null)
            tags                     = try(filter.value.tags, filter.value.tag, null)
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# Object Lock Configuration (New from official module)
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = local.create_bucket && local.final_object_lock_enabled && try(var.object_lock_configuration.rule.default_retention, null) != null ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner
  token                 = try(var.object_lock_configuration.token, null)

  rule {
    default_retention {
      mode  = var.object_lock_configuration.rule.default_retention.mode
      days  = try(var.object_lock_configuration.rule.default_retention.days, null)
      years = try(var.object_lock_configuration.rule.default_retention.years, null)
    }
  }
}

# Website Configuration (New from official module)
resource "aws_s3_bucket_website_configuration" "this" {
  count = local.create_bucket && length(keys(var.website)) > 0 ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner

  dynamic "index_document" {
    for_each = try([var.website["index_document"]], [])
    content {
      suffix = index_document.value
    }
  }

  dynamic "error_document" {
    for_each = try([var.website["error_document"]], [])
    content {
      key = error_document.value
    }
  }

  dynamic "redirect_all_requests_to" {
    for_each = try([var.website["redirect_all_requests_to"]], [])
    content {
      host_name = redirect_all_requests_to.value.host_name
      protocol  = try(redirect_all_requests_to.value.protocol, null)
    }
  }

  dynamic "routing_rule" {
    for_each = try(flatten([var.website["routing_rules"]]), [])
    content {
      dynamic "condition" {
        for_each = try([routing_rule.value.condition], [])
        content {
          http_error_code_returned_equals = try(routing_rule.value.condition["http_error_code_returned_equals"], null)
          key_prefix_equals               = try(routing_rule.value.condition["key_prefix_equals"], null)
        }
      }

      redirect {
        host_name               = try(routing_rule.value.redirect["host_name"], null)
        http_redirect_code      = try(routing_rule.value.redirect["http_redirect_code"], null)
        protocol                = try(routing_rule.value.redirect["protocol"], null)
        replace_key_prefix_with = try(routing_rule.value.redirect["replace_key_prefix_with"], null)
        replace_key_with        = try(routing_rule.value.redirect["replace_key_with"], null)
      }
    }
  }
}

# Transfer Acceleration (New from official module)
resource "aws_s3_bucket_accelerate_configuration" "this" {
  count = local.create_bucket && var.acceleration_status != null ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner
  status                = title(lower(var.acceleration_status))
}

# Request Payment Configuration (New from official module)
resource "aws_s3_bucket_request_payment_configuration" "this" {
  count = local.create_bucket && var.request_payer != null ? 1 : 0

  bucket                = aws_s3_bucket.this[0].id
  expected_bucket_owner = var.expected_bucket_owner
  payer                 = lower(var.request_payer) == "requester" ? "Requester" : "BucketOwner"
}

# Replication Configuration (New from official module)
resource "aws_s3_bucket_replication_configuration" "this" {
  count = local.create_bucket && length(keys(var.replication_configuration)) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  role   = var.replication_configuration["role"]

  dynamic "rule" {
    for_each = flatten(try([var.replication_configuration["rule"]], [var.replication_configuration["rules"]], []))

    content {
      id       = try(rule.value.id, null)
      priority = try(rule.value.priority, null)
      status   = try(tobool(rule.value.status) ? "Enabled" : "Disabled", title(lower(rule.value.status)), "Enabled")

      dynamic "destination" {
        for_each = try(flatten([rule.value.destination]), [])
        content {
          bucket        = destination.value.bucket
          storage_class = try(destination.value.storage_class, null)
          account       = try(destination.value.account_id, destination.value.account, null)

          dynamic "encryption_configuration" {
            for_each = flatten([try(destination.value.encryption_configuration.replica_kms_key_id, destination.value.replica_kms_key_id, [])])
            content {
              replica_kms_key_id = encryption_configuration.value
            }
          }
        }
      }

      # Filter configurations for replication
      dynamic "filter" {
        for_each = length(try(flatten([rule.value.filter]), [])) == 0 ? [true] : []
        content {}
      }

      dynamic "filter" {
        for_each = [for v in try(flatten([rule.value.filter]), []) : v if max(length(keys(v)), length(try(rule.value.filter.tags, rule.value.filter.tag, []))) == 1]
        content {
          prefix = try(filter.value.prefix, null)
          dynamic "tag" {
            for_each = try(filter.value.tags, filter.value.tag, [])
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# Intelligent Tiering (New from official module)
resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = { for k, v in local.intelligent_tiering : k => v if local.create_bucket }

  name   = each.key
  bucket = aws_s3_bucket.this[0].id
  status = try(tobool(each.value.status) ? "Enabled" : "Disabled", title(lower(each.value.status)), null)

  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]
    content {
      prefix = try(each.value.filter.prefix, null)
      tags   = try(each.value.filter.tags, null)
    }
  }

  dynamic "tiering" {
    for_each = each.value.tiering
    content {
      access_tier = tiering.key
      days        = tiering.value.days
    }
  }
}

# Metrics Configuration (New from official module)
resource "aws_s3_bucket_metric" "this" {
  for_each = { for k, v in local.metric_configuration : k => v if local.create_bucket }

  name   = each.value.name
  bucket = aws_s3_bucket.this[0].id

  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]
    content {
      prefix = try(each.value.filter.prefix, null)
      tags   = try(each.value.filter.tags, null)
    }
  }
}

# Inventory Configuration (New from official module)
resource "aws_s3_bucket_inventory" "this" {
  for_each = { for k, v in var.inventory_configuration : k => v if local.create_bucket }

  name                     = each.key
  bucket                   = try(each.value.bucket, aws_s3_bucket.this[0].id)
  included_object_versions = each.value.included_object_versions
  enabled                  = try(each.value.enabled, true)
  optional_fields          = try(each.value.optional_fields, null)

  destination {
    bucket {
      bucket_arn = try(each.value.destination.bucket_arn, aws_s3_bucket.this[0].arn)
      format     = try(each.value.destination.format, null)
      account_id = try(each.value.destination.account_id, null)
      prefix     = try(each.value.destination.prefix, null)

      dynamic "encryption" {
        for_each = length(try(flatten([each.value.destination.encryption]), [])) == 0 ? [] : [true]
        content {
          dynamic "sse_kms" {
            for_each = each.value.destination.encryption.encryption_type == "sse_kms" ? [true] : []
            content {
              key_id = try(each.value.destination.encryption.kms_key_id, null)
            }
          }

          dynamic "sse_s3" {
            for_each = each.value.destination.encryption.encryption_type == "sse_s3" ? [true] : []
            content {}
          }
        }
      }
    }
  }

  schedule {
    frequency = each.value.frequency
  }

  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]
    content {
      prefix = try(each.value.filter.prefix, null)
    }
  }
}

# Analytics Configuration (New from official module)
resource "aws_s3_bucket_analytics_configuration" "this" {
  for_each = { for k, v in var.analytics_configuration : k => v if local.create_bucket }

  bucket = aws_s3_bucket.this[0].id
  name   = each.key

  dynamic "filter" {
    for_each = length(try(flatten([each.value.filter]), [])) == 0 ? [] : [true]
    content {
      prefix = try(each.value.filter.prefix, null)
      tags   = try(each.value.filter.tags, null)
    }
  }

  dynamic "storage_class_analysis" {
    for_each = length(try(flatten([each.value.storage_class_analysis]), [])) == 0 ? [] : [true]
    content {
      data_export {
        output_schema_version = try(each.value.storage_class_analysis.output_schema_version, null)
        destination {
          s3_bucket_destination {
            bucket_arn        = try(each.value.storage_class_analysis.destination_bucket_arn, aws_s3_bucket.this[0].arn)
            bucket_account_id = try(each.value.storage_class_analysis.destination_account_id, data.aws_caller_identity.current.id)
            format            = try(each.value.storage_class_analysis.export_format, "CSV")
            prefix            = try(each.value.storage_class_analysis.export_prefix, null)
          }
        }
      }
    }
  }
}

# Access logging (Enhanced)
resource "aws_s3_bucket_logging" "this" {
  count = local.create_bucket && (local.final_enable_access_logging || length(keys(var.logging)) > 0) ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  target_bucket = try(var.logging["target_bucket"], var.access_log_bucket)
  target_prefix = try(var.logging["target_prefix"], "s3-access-logs/${local.bucket_name}/")

  dynamic "target_object_key_format" {
    for_each = try([var.logging["target_object_key_format"]], [])
    content {
      dynamic "partitioned_prefix" {
        for_each = try(target_object_key_format.value["partitioned_prefix"], [])
        content {
          partition_date_source = try(partitioned_prefix.value, null)
        }
      }

      dynamic "simple_prefix" {
        for_each = length(try(target_object_key_format.value["partitioned_prefix"], [])) == 0 || can(target_object_key_format.value["simple_prefix"]) ? [true] : []
        content {}
      }
    }
  }
}

# Gateway VPC Endpoint (Enhanced)
resource "aws_vpc_endpoint" "s3_gateway" {
  count = local.use_gateway_endpoint ? 1 : 0
  
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.selected_route_table_ids
  
  policy = var.endpoint_policy != "" ? var.endpoint_policy : null
  
  tags = merge(
    var.tags,
    {
      Name   = "${var.name_prefix}-s3-gateway-endpoint"
      Type   = "Gateway"
      Preset = var.preset
    }
  )
}

# Interface VPC Endpoint (Enhanced)
resource "aws_vpc_endpoint" "s3_interface" {
  count = local.use_interface_endpoint ? 1 : 0
  
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.selected_subnet_ids
  security_group_ids  = local.interface_security_group_ids
  private_dns_enabled = var.private_dns_enabled
  
  policy = var.endpoint_policy != "" ? var.endpoint_policy : null
  
  tags = merge(
    var.tags,
    {
      Name   = "${var.name_prefix}-s3-interface-endpoint"
      Type   = "Interface"
      Preset = var.preset
    }
  )
}

# Security group management (EC2-like)
locals {
  # Combine existing and new security groups
  interface_security_group_ids = concat(
    var.security_group_ids,
    var.create_security_group && local.use_interface_endpoint ? [aws_security_group.vpc_endpoint[0].id] : []
  )
}

# Security group for interface endpoint
resource "aws_security_group" "vpc_endpoint" {
  count = var.create_security_group && local.use_interface_endpoint ? 1 : 0
  
  name_prefix = "${var.name_prefix}-s3-endpoint-"
  description = "Security group for S3 VPC interface endpoint"
  vpc_id      = var.vpc_id
  
  # Default rule: HTTPS from VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }
  
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    var.tags,
    {
      Name   = "${var.name_prefix}-s3-endpoint-sg"
      Preset = var.preset
    }
  )
}

# Custom security group rules (EC2-like)
resource "aws_security_group_rule" "custom" {
  count = var.create_security_group && local.use_interface_endpoint ? length(var.security_group_rules) : 0
  
  type                     = var.security_group_rules[count.index].type
  from_port                = var.security_group_rules[count.index].from_port
  to_port                  = var.security_group_rules[count.index].to_port
  protocol                 = var.security_group_rules[count.index].protocol
  cidr_blocks              = var.security_group_rules[count.index].cidr_blocks
  source_security_group_id = var.security_group_rules[count.index].source_security_group_id
  description              = var.security_group_rules[count.index].description
  security_group_id        = aws_security_group.vpc_endpoint[0].id
}

# IAM Instance Profile (EC2-like)
resource "aws_iam_role" "ec2_s3_access" {
  count = local.final_create_instance_profile ? 1 : 0
  name  = "${var.name_prefix}-ec2-s3-access"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  
  tags = merge(
    var.tags,
    {
      Name   = "${var.name_prefix}-ec2-s3-role"
      Preset = var.preset
    }
  )
}

resource "aws_iam_role_policy" "ec2_s3_access" {
  count = local.final_create_instance_profile ? 1 : 0
  name  = "${var.name_prefix}-s3-access"
  role  = aws_iam_role.ec2_s3_access[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = var.allowed_actions
      Resource = [
        aws_s3_bucket.this[0].arn,
        "${aws_s3_bucket.this[0].arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_access" {
  count = local.final_create_instance_profile ? 1 : 0
  name  = local.instance_profile_name
  role  = aws_iam_role.ec2_s3_access[0].name
  
  tags = merge(
    var.tags,
    {
      Name   = local.instance_profile_name
      Preset = var.preset
    }
  )
}

# Enhanced Bucket Policy (Combined from official module patterns)
resource "aws_s3_bucket_policy" "combined" {
  count = local.create_bucket && local.attach_policy ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  policy = data.aws_iam_policy_document.combined[0].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# Combined policy document (Enhanced from official module)
data "aws_iam_policy_document" "combined" {
  count = local.create_bucket && local.attach_policy ? 1 : 0

  source_policy_documents = compact([
    local.final_restrict_to_vpc ? data.aws_iam_policy_document.vpc_only[0].json : "",
    local.final_attach_deny_insecure_transport_policy ? data.aws_iam_policy_document.deny_insecure_transport[0].json : "",
    local.final_attach_require_latest_tls_policy ? data.aws_iam_policy_document.require_latest_tls[0].json : "",
    local.final_attach_deny_unencrypted_object_uploads ? data.aws_iam_policy_document.deny_unencrypted_object_uploads[0].json : "",
    var.attach_deny_incorrect_encryption_headers ? data.aws_iam_policy_document.deny_incorrect_encryption_headers[0].json : "",
    var.attach_deny_incorrect_kms_key_sse ? data.aws_iam_policy_document.deny_incorrect_kms_key_sse[0].json : "",
    var.attach_policy ? var.policy : "",
  ])
}

# VPC-only access policy
data "aws_iam_policy_document" "vpc_only" {
  count = local.final_restrict_to_vpc ? 1 : 0

  statement {
    sid    = "DenyAllExceptVPCEndpoint"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this[0].arn,
      "${aws_s3_bucket.this[0].arn}/*"
    ]
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = local.use_gateway_endpoint ? [aws_vpc_endpoint.s3_gateway[0].id] : [aws_vpc_endpoint.s3_interface[0].id]
    }
  }

  statement {
    sid    = "AllowVPCEndpointAccess"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = var.allowed_actions
    resources = [
      aws_s3_bucket.this[0].arn,
      "${aws_s3_bucket.this[0].arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = local.use_gateway_endpoint ? [aws_vpc_endpoint.s3_gateway[0].id] : [aws_vpc_endpoint.s3_interface[0].id]
    }
  }
}

# Security policy documents (From official module)
data "aws_iam_policy_document" "deny_insecure_transport" {
  count = local.final_attach_deny_insecure_transport_policy ? 1 : 0

  statement {
    sid    = "denyInsecureTransport"
    effect = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this[0].arn,
      "${aws_s3_bucket.this[0].arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_iam_policy_document" "require_latest_tls" {
  count = local.final_attach_require_latest_tls_policy ? 1 : 0

  statement {
    sid    = "denyOutdatedTLS"
    effect = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this[0].arn,
      "${aws_s3_bucket.this[0].arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

data "aws_iam_policy_document" "deny_unencrypted_object_uploads" {
  count = local.final_attach_deny_unencrypted_object_uploads ? 1 : 0

  statement {
    sid    = "denyUnencryptedObjectUploads"
    effect = "Deny"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this[0].arn}/*"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = [true]
    }
  }
}

data "aws_iam_policy_document" "deny_incorrect_encryption_headers" {
  count = var.attach_deny_incorrect_encryption_headers ? 1 : 0

  statement {
    sid    = "denyIncorrectEncryptionHeaders"
    effect = "Deny"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this[0].arn}/*"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = local.final_encryption_type == "aws:kms" ? ["aws:kms"] : ["AES256"]
    }
  }
}

data "aws_iam_policy_document" "deny_incorrect_kms_key_sse" {
  count = var.attach_deny_incorrect_kms_key_sse ? 1 : 0

  statement {
    sid    = "denyIncorrectKmsKeySse"
    effect = "Deny"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this[0].arn}/*"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [var.allowed_kms_key_arn]
    }
  }
}