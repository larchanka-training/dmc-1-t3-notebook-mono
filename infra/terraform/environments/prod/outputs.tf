output "api_prod_url" {
  description = "HTTPS URL of the production AppRunner service"
  value       = "https://${module.apprunner_prod.service_url}"
}

output "amplify_app_id" {
  description = "Amplify app ID — set as GitHub Variable AMPLIFY_APP_ID"
  value       = aws_amplify_app.ui.id
}

output "ui_prod_url" {
  description = "Production UI URL"
  value       = "https://main.${aws_amplify_app.ui.id}.amplifyapp.com"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "vpc_id" {
  description = "VPC ID — consumed by preview environment remote state"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — consumed by preview environment remote state"
  value       = module.network.private_subnet_ids
}
