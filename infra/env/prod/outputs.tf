output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "validation_url" {
  value = "https://${module.ui.cloudfront_domain_name}"
}

output "api_base_url" {
  value = "http://${module.alb.alb_dns_name}/api/v1"
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
