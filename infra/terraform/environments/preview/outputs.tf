output "preview_api_url" {
  description = "Preview API URL for PR-${var.pr_number} (without https:// prefix, as expected by preview.yml)"
  value       = module.apprunner_preview.service_url
}

output "preview_api_arn" {
  description = "AppRunner service ARN for PR-${var.pr_number}"
  value       = module.apprunner_preview.service_arn
}
