output "ecs_cluster_name" {
  description = "Shared ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  description = "Shared ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}
