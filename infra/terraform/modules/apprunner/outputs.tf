output "service_url" {
  description = "HTTPS URL of the AppRunner service (without https:// prefix)"
  value       = aws_apprunner_service.this.service_url
}

output "service_arn" {
  description = "ARN of the AppRunner service"
  value       = aws_apprunner_service.this.arn
}

output "vpc_connector_sg_id" {
  description = "Security group ID of the AppRunner VPC connector"
  value       = aws_security_group.apprunner_vpc_connector.id
}
