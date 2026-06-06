output "vpc_id" {
  description = "Dedicated VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Dedicated VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by internet-facing load balancers."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_app_subnet_ids" {
  description = "Private subnet IDs used by ECS services."
  value       = [for subnet in aws_subnet.private_app : subnet.id]
}

output "private_db_subnet_ids" {
  description = "Private subnet IDs used by database resources."
  value       = [for subnet in aws_subnet.private_db : subnet.id]
}

output "availability_zones" {
  description = "Availability zones backing the VPC layout."
  value       = var.availability_zones
}
