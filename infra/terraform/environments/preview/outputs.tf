output "preview_api_url" {
  description = "HTTPS URL of the preview AppRunner service (without https:// prefix)"
  value       = module.apprunner_preview.service_url
}
