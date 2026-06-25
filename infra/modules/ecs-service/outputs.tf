output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ECS service ARN."
  value       = aws_ecs_service.this.id
}

output "security_group_id" {
  description = "Security group attached to the ECS service."
  value       = aws_security_group.this.id
}

output "target_group_arn" {
  description = "Target group ARN if ALB integration is enabled."
  value       = try(aws_lb_target_group.this[0].arn, null)
}

output "service_discovery_fqdn" {
  description = "Cloud Map DNS name if service discovery is enabled."
  value       = var.service_discovery == null ? null : "${var.service_discovery.discovery_name}.${var.service_discovery.namespace_name}"
}

output "service_discovery_service_arn" {
  description = "Cloud Map service ARN when service discovery is enabled."
  value       = try(aws_service_discovery_service.this[0].arn, null)
}

output "task_definition_arn" {
  description = "Task definition ARN."
  value       = aws_ecs_task_definition.this.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for the service."
  value       = aws_cloudwatch_log_group.this.name
}
