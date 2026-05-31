output "service_url" {
  description = "AppRunner service URL (without https:// prefix)"
  value       = aws_apprunner_service.main.service_url
}

output "service_arn" {
  description = "ARN of the AppRunner service"
  value       = aws_apprunner_service.main.arn
}
