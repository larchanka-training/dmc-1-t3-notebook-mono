output "address" {
  description = "Hostname of the RDS instance (without port)"
  value       = aws_db_instance.main.address
}

output "endpoint" {
  description = "Connection endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "port" {
  description = "Port the database listens on"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Master DB username"
  value       = aws_db_instance.main.username
}
