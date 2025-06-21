# modules/s3-vpc/outputs.tf

# Basic S3 outputs
output "bucket_id" {
  description = "The name of the bucket"
  value       = local.create_bucket ? aws_s3_bucket.this[0].id : ""
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = local.create_bucket ? aws_s3_bucket.this[0].arn : ""
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = local.create_bucket ? aws_s3_bucket.this[0].bucket_domain_name : ""
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = local.create_bucket ? aws_s3_bucket.this[0].bucket_regional_domain_name : ""
}

output "bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = local.create_bucket ? aws_s3_bucket.this[0].region : ""
}

output "bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region"
  value       = local.create_bucket ? aws_s3_bucket.this[0].hosted_zone_id : ""
}

# VPC Endpoint outputs
output "vpc_endpoint_id" {
  description = "The ID of the VPC endpoint"
  value       = local.use_gateway_endpoint ? aws_vpc_endpoint.s3_gateway[0].id : (local.use_interface_endpoint ? aws_vpc_endpoint.s3_interface[0].id : "")
}

output "vpc_endpoint_type" {
  description = "The type of VPC endpoint created"
  value       = local.use_gateway_endpoint ? "gateway" : (local.use_interface_endpoint ? "interface" : "none")
}

output "vpc_endpoint_dns_entries" {
  description = "DNS entries for the VPC endpoint (interface endpoints only)"
  value       = local.use_interface_endpoint ? aws_vpc_endpoint.s3_interface[0].dns_entry : []
}

output "vpc_endpoint_network_interface_ids" {
  description = "One or more network interfaces for the VPC Endpoint for S3"
  value       = local.use_interface_endpoint ? aws_vpc_endpoint.s3_interface[0].network_interface_ids : []
}

# EC2-like outputs for easy integration
output "instance_profile_name" {
  description = "IAM instance profile name for EC2 instances (like EC2 key pair)"
  value       = local.final_create_instance_profile ? aws_iam_instance_profile.ec2_s3_access[0].name : ""
}

output "instance_profile_arn" {
  description = "IAM instance profile ARN for EC2 instances"
  value       = local.final_create_instance_profile ? aws_iam_instance_profile.ec2_s3_access[0].arn : ""
}

output "iam_role_name" {
  description = "IAM role name for the instance profile"
  value       = local.final_create_instance_profile ? aws_iam_role.ec2_s3_access[0].name : ""
}

output "iam_role_arn" {
  description = "IAM role ARN for the instance profile"
  value       = local.final_create_instance_profile ? aws_iam_role.ec2_s3_access[0].arn : ""
}

output "iam_role_unique_id" {
  description = "Unique ID of the IAM role"
  value       = local.final_create_instance_profile ? aws_iam_role.ec2_s3_access[0].unique_id : ""
}

output "subnet_ids" {
  description = "Subnet IDs where the endpoint is deployed (like EC2 placement)"
  value       = local.selected_subnet_ids
}

output "route_table_ids" {
  description = "Route table IDs used for gateway endpoint"
  value       = local.selected_route_table_ids
}

output "security_group_id" {
  description = "Security group ID for interface endpoint"
  value       = var.create_security_group && local.use_interface_endpoint ? aws_security_group.vpc_endpoint[0].id : ""
}

output "security_group_ids" {
  description = "All security group IDs attached to interface endpoint"
  value       = local.use_interface_endpoint ? local.interface_security_group_ids : []
}

# Advanced S3 Configuration Outputs (from official module)
output "bucket_versioning_status" {
  description = "The versioning state of the bucket"
  value       = local.create_bucket && (local.final_enable_versioning || length(keys(var.versioning)) > 0) ? aws_s3_bucket_versioning.this[0].versioning_configuration[0].status : ""
}

output "bucket_server_side_encryption_configuration" {
  description = "The server-side encryption configuration of the bucket"
  value       = local.create_bucket ? aws_s3_bucket_server_side_encryption_configuration.this[0].rule : []
}

output "bucket_public_access_block" {
  description = "The public access block configuration of the bucket"
  value = local.create_bucket ? {
    block_public_acls       = aws_s3_bucket_public_access_block.this[0].block_public_acls
    block_public_policy     = aws_s3_bucket_public_access_block.this[0].block_public_policy
    ignore_public_acls      = aws_s3_bucket_public_access_block.this[0].ignore_public_acls
    restrict_public_buckets = aws_s3_bucket_public_access_block.this[0].restrict_public_buckets
  } : {}
}

output "bucket_ownership_controls" {
  description = "The ownership controls of the bucket"
  value       = local.create_bucket && local.final_control_object_ownership ? aws_s3_bucket_ownership_controls.this[0].rule[0].object_ownership : ""
}

output "bucket_acl" {
  description = "The ACL of the bucket"
  value       = local.create_bucket && local.create_bucket_acl ? aws_s3_bucket_acl.this[0].acl : ""
}

output "bucket_cors_configuration" {
  description = "The CORS configuration of the bucket"
  value       = local.create_bucket && length(local.cors_rules) > 0 ? aws_s3_bucket_cors_configuration.this[0].cors_rule : []
}

output "bucket_lifecycle_configuration" {
  description = "The lifecycle configuration of the bucket"
  value       = local.create_bucket && length(local.lifecycle_rules) > 0 ? aws_s3_bucket_lifecycle_configuration.this[0].rule : []
}

output "bucket_object_lock_configuration" {
  description = "The object lock configuration of the bucket"
  value       = local.create_bucket && local.final_object_lock_enabled && try(var.object_lock_configuration.rule.default_retention, null) != null ? aws_s3_bucket_object_lock_configuration.this[0].rule : []
}

output "bucket_website_configuration" {
  description = "The website configuration of the bucket"
  value       = local.create_bucket && length(keys(var.website)) > 0 ? {
    index_document = try(aws_s3_bucket_website_configuration.this[0].index_document, [])
    error_document = try(aws_s3_bucket_website_configuration.this[0].error_document, [])
    routing_rules  = try(aws_s3_bucket_website_configuration.this[0].routing_rule, [])
  } : {}
}

output "bucket_website_endpoint" {
  description = "The website endpoint, if the bucket is configured with a website"
  value       = local.create_bucket && length(keys(var.website)) > 0 ? aws_s3_bucket_website_configuration.this[0].website_endpoint : ""
}

output "bucket_website_domain" {
  description = "The domain of the website endpoint"
  value       = local.create_bucket && length(keys(var.website)) > 0 ? aws_s3_bucket_website_configuration.this[0].website_domain : ""
}

output "bucket_acceleration_status" {
  description = "The acceleration status of the bucket"
  value       = local.create_bucket && var.acceleration_status != null ? aws_s3_bucket_accelerate_configuration.this[0].status : ""
}

output "bucket_request_payment_configuration" {
  description = "The request payment configuration of the bucket"
  value       = local.create_bucket && var.request_payer != null ? aws_s3_bucket_request_payment_configuration.this[0].payer : ""
}

output "bucket_replication_configuration" {
  description = "The replication configuration of the bucket"
  value       = local.create_bucket && length(keys(var.replication_configuration)) > 0 ? {
    role  = aws_s3_bucket_replication_configuration.this[0].role
    rules = aws_s3_bucket_replication_configuration.this[0].rule
  } : {}
}

output "bucket_intelligent_tiering_configuration" {
  description = "The intelligent tiering configuration of the bucket"
  value       = { for k, v in aws_s3_bucket_intelligent_tiering_configuration.this : k => v }
}

output "bucket_metric_configuration" {
  description = "The metric configuration of the bucket"
  value       = { for k, v in aws_s3_bucket_metric.this : k => v }
}

output "bucket_inventory_configuration" {
  description = "The inventory configuration of the bucket"
  value       = { for k, v in aws_s3_bucket_inventory.this : k => v }
}

output "bucket_analytics_configuration" {
  description = "The analytics configuration of the bucket"
  value       = { for k, v in aws_s3_bucket_analytics_configuration.this : k => v }
}

output "bucket_logging_configuration" {
  description = "The logging configuration of the bucket"
  value = local.create_bucket && (local.final_enable_access_logging || length(keys(var.logging)) > 0) ? {
    target_bucket = aws_s3_bucket_logging.this[0].target_bucket
    target_prefix = aws_s3_bucket_logging.this[0].target_prefix
  } : {}
}

output "bucket_policy" {
  description = "The policy of the bucket"
  value       = local.create_bucket && local.attach_policy ? aws_s3_bucket_policy.combined[0].policy : ""
}

# Connection information for applications
output "endpoint_url" {
  description = "S3 endpoint URL for applications (like EC2 public DNS)"
  value       = local.use_interface_endpoint ? (
    length(aws_vpc_endpoint.s3_interface[0].dns_entry) > 0 ? 
    "https://${aws_vpc_endpoint.s3_interface[0].dns_entry[0].dns_name}" : 
    "https://s3.${data.aws_region.current.name}.amazonaws.com"
  ) : "https://s3.${data.aws_region.current.name}.amazonaws.com"
}

output "connection_info" {
  description = "Complete connection information for applications"
  value = {
    bucket_name     = local.create_bucket ? aws_s3_bucket.this[0].id : ""
    bucket_arn      = local.create_bucket ? aws_s3_bucket.this[0].arn : ""
    bucket_domain_name = local.create_bucket ? aws_s3_bucket.this[0].bucket_domain_name : ""
    bucket_regional_domain_name = local.create_bucket ? aws_s3_bucket.this[0].bucket_regional_domain_name : ""
    endpoint_url    = local.use_interface_endpoint ? (
      length(aws_vpc_endpoint.s3_interface[0].dns_entry) > 0 ? 
      "https://${aws_vpc_endpoint.s3_interface[0].dns_entry[0].dns_name}" : 
      "https://s3.${data.aws_region.current.name}.amazonaws.com"
    ) : "https://s3.${data.aws_region.current.name}.amazonaws.com"
    region          = data.aws_region.current.name
    vpc_endpoint_id = local.use_gateway_endpoint ? aws_vpc_endpoint.s3_gateway[0].id : (local.use_interface_endpoint ? aws_vpc_endpoint.s3_interface[0].id : "")
    endpoint_type   = local.use_gateway_endpoint ? "gateway" : (local.use_interface_endpoint ? "interface" : "none")
    preset          = var.preset
    website_endpoint = local.create_bucket && length(keys(var.website)) > 0 ? aws_s3_bucket_website_configuration.this[0].website_endpoint : ""
  }
}

# Configuration summary (Enhanced)
output "configuration_summary" {
  description = "Summary of the applied configuration"
  value = {
    # Basic configuration
    preset                = var.preset
    endpoint_type         = local.final_endpoint_type
    encryption_type       = local.final_encryption_type
    versioning_enabled    = local.final_enable_versioning
    vpc_restricted        = local.final_restrict_to_vpc
    instance_profile_created = local.final_create_instance_profile
    access_logging_enabled   = local.final_enable_access_logging
    auto_subnet_selection    = var.auto_select_subnets
    auto_route_table_selection = var.auto_select_route_tables
    
    # Advanced security features
    deny_insecure_transport = local.final_attach_deny_insecure_transport_policy
    require_latest_tls      = local.final_attach_require_latest_tls_policy
    deny_unencrypted_uploads = local.final_attach_deny_unencrypted_object_uploads
    object_lock_enabled     = local.final_object_lock_enabled
    object_ownership        = local.final_object_ownership
    
    # Additional features
    cors_enabled           = length(local.cors_rules) > 0
    lifecycle_enabled      = length(local.lifecycle_rules) > 0
    website_enabled        = length(keys(var.website)) > 0
    replication_enabled    = length(keys(var.replication_configuration)) > 0
    acceleration_enabled   = var.acceleration_status != null
    intelligent_tiering_enabled = length(local.intelligent_tiering) > 0
    metrics_enabled        = length(local.metric_configuration) > 0
    inventory_enabled      = length(var.inventory_configuration) > 0
    analytics_enabled      = length(var.analytics_configuration) > 0
  }
}

# Quick start information (Enhanced)
output "quick_start" {
  description = "Quick start information for using this S3 bucket with EC2"
  value = {
    # Basic usage
    ec2_instance_profile = local.final_create_instance_profile ? aws_iam_instance_profile.ec2_s3_access[0].name : "Create manually or set create_instance_profile=true"
    example_user_data    = "aws s3 ls s3://${local.create_bucket ? aws_s3_bucket.this[0].id : "BUCKET_NAME"}/"
    
    # CLI commands
    cli_commands = {
      list_bucket    = "aws s3 ls s3://${local.create_bucket ? aws_s3_bucket.this[0].id : "BUCKET_NAME"}/"
      upload_file    = "aws s3 cp file.txt s3://${local.create_bucket ? aws_s3_bucket.this[0].id : "BUCKET_NAME"}/"
      download_file  = "aws s3 cp s3://${local.create_bucket ? aws_s3_bucket.this[0].id : "BUCKET_NAME"}/file.txt ."
      sync_directory = "aws s3 sync ./local-folder s3://${local.create_bucket ? aws_s3_bucket.this[0].id : "BUCKET_NAME"}/remote-folder/"
    }
    
    # Cost and security information
    cost_info = local.use_gateway_endpoint ? "FREE - Gateway endpoint has no charges" : "PAID - Interface endpoint has hourly and data transfer charges"
    security_level = var.preset == "compliance" ? "MAXIMUM - Compliance-grade security" : (
      var.preset == "secure" ? "HIGH - Enhanced security policies" : (
        var.preset == "standard" ? "STANDARD - Basic security" : "MINIMAL - Cost-optimized"
      )
    )
    
    # Feature availability
    features_enabled = {
      vpc_endpoint      = local.use_gateway_endpoint || local.use_interface_endpoint
      encryption        = true
      versioning        = local.final_enable_versioning
      access_logging    = local.final_enable_access_logging
      object_lock       = local.final_object_lock_enabled
      cors              = length(local.cors_rules) > 0
      lifecycle         = length(local.lifecycle_rules) > 0
      website           = length(keys(var.website)) > 0
      replication       = length(keys(var.replication_configuration)) > 0
      acceleration      = var.acceleration_status != null
    }
    
    # Next steps
    next_steps = [
      "1. Use instance_profile_name in your EC2 instances",
      "2. Configure application to use endpoint_url if using interface endpoint",
      "3. Set up lifecycle rules for cost optimization (if needed)",
      "4. Configure CORS if serving web content",
      "5. Enable CloudTrail for audit logging (compliance environments)"
    ]
  }
}

# Terraform module compatibility
output "s3_bucket_id" {
  description = "The name of the bucket (for compatibility with other modules)"
  value       = local.create_bucket ? aws_s3_bucket.this[0].id : ""
}

output "s3_bucket_arn" {
  description = "The ARN of the bucket (for compatibility with other modules)"
  value       = local.create_bucket ? aws_s3_bucket.this[0].arn : ""
}

output "s3_bucket_domain_name" {
  description = "The bucket domain name (for compatibility with other modules)"
  value       = local.create_bucket ? aws_s3_bucket.this[0].bucket_domain_name : ""
}

output "s3_bucket_regional_domain_name" {
  description = "The bucket regional domain name (for compatibility with other modules)"
  value       = local.create_bucket ? aws_s3_bucket.this[0].bucket_regional_domain_name : ""
}

output "s3_bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region (for compatibility with other modules)"
  value       = local.create_bucket ? aws_s3_bucket.this[0].hosted_zone_id : ""
}

output "s3_bucket_region" {
  description = "The AWS region this bucket resides in (for compatibility with other modules)"
  value       = local.create_bucket ? aws_s3_bucket.this[0].region : ""
}

output "s3_bucket_website_endpoint" {
  description = "The website endpoint (for compatibility with other modules)"
  value       = local.create_bucket && length(keys(var.website)) > 0 ? aws_s3_bucket_website_configuration.this[0].website_endpoint : ""
}

output "s3_bucket_website_domain" {
  description = "The domain of the website endpoint (for compatibility with other modules)"
  value       = local.create_bucket && length(keys(var.website)) > 0 ? aws_s3_bucket_website_configuration.this[0].website_domain : ""
}