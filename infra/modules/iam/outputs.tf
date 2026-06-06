output "task_execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = aws_iam_role.task_execution.arn
}

output "ui_task_role_arn" {
  description = "UI task role ARN."
  value       = aws_iam_role.ui_task.arn
}

output "api_task_role_arn" {
  description = "API task role ARN."
  value       = aws_iam_role.api_task.arn
}

output "proxy_task_role_arn" {
  description = "Proxy task role ARN."
  value       = aws_iam_role.proxy_task.arn
}
