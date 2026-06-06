output "endpoint" {
  description = "RDS endpoint hostname."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS port."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Primary database name."
  value       = var.db_name
}

output "connection_secret_arn" {
  description = "Secrets Manager ARN containing connection details and DATABASE_URL."
  value       = aws_secretsmanager_secret.connection.arn
}

output "security_group_id" {
  description = "Database security group ID."
  value       = aws_security_group.this.id
}
