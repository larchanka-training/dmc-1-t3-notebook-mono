output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "validation_url" {
  value = "https://${local.root_domain}"
}

output "api_base_url" {
  value = "https://${local.api_domain}/api/v1"
}

output "ui_bucket_name" {
  value = module.ui.bucket_name
}

output "ui_cloudfront_domain_name" {
  value = module.ui.cloudfront_domain_name
}

output "ui_cloudfront_distribution_id" {
  value = module.ui.cloudfront_distribution_id
}

output "database_secret_arn" {
  value = module.database.connection_secret_arn
}

output "api_config_secret_arn" {
  value       = aws_secretsmanager_secret.api_config.arn
  description = "ARN of the API configuration secret. Populate its value via AWS CLI before first deploy."
}
