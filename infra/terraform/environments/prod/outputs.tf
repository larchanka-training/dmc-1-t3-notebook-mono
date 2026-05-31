output "api_prod_url" {
  description = "Production API URL (AppRunner)"
  value       = "https://${module.apprunner_prod.service_url}"
}

output "api_prod_arn" {
  description = "Production AppRunner service ARN"
  value       = module.apprunner_prod.service_arn
}

output "ui_amplify_app_id" {
  description = "Amplify app ID — set this as GitHub Variable AMPLIFY_APP_ID"
  value       = aws_amplify_app.ui.id
}

output "ui_prod_url" {
  description = "Production UI URL (Amplify main branch)"
  value       = "https://main.${aws_amplify_app.ui.id}.amplifyapp.com"
}

output "ecr_repository_url" {
  description = "ECR repository URL for tagging API images"
  value       = module.ecr.repository_url
}

# ---------------------------------------------------------------------------
# Outputs consumed by the preview environment via terraform_remote_state
# ---------------------------------------------------------------------------
output "vpc_connector_arn" {
  description = "AppRunner VPC connector ARN (shared with preview)"
  value       = aws_apprunner_vpc_connector.main.arn
}

output "apprunner_ecr_role_arn" {
  description = "IAM role ARN for AppRunner ECR access (shared with preview)"
  value       = aws_iam_role.apprunner_ecr_access.arn
}

output "apprunner_instance_role_arn" {
  description = "IAM instance role ARN for AppRunner services (shared with preview)"
  value       = aws_iam_role.apprunner_instance.arn
}

output "preview_db_url_secret_arn" {
  description = "Secrets Manager ARN for the preview database URL (shared with preview)"
  value       = aws_secretsmanager_secret.preview_db_url.arn
}
