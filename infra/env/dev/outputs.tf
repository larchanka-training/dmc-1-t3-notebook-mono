output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "application_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "api_base_url" {
  value = "http://${module.alb.alb_dns_name}/api/v1"
}

output "database_secret_arn" {
  value = module.database.connection_secret_arn
}
