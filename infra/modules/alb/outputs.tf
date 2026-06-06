output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID for DNS aliases."
  value       = aws_lb.this.zone_id
}

output "listener_arn" {
  description = "Primary listener ARN."
  value       = aws_lb_listener.this.arn
}

output "security_group_id" {
  description = "ALB security group ID."
  value       = aws_security_group.this.id
}
