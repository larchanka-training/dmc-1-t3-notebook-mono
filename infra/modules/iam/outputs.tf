output "task_execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = aws_iam_role.task_execution.arn
}

output "task_execution_role_name" {
  description = "ECS task execution role name."
  value       = aws_iam_role.task_execution.name
}

output "ui_task_role_arn" {
  description = "UI task role ARN."
  value       = aws_iam_role.ui_task.arn
}

output "api_task_role_arn" {
  description = "API task role ARN."
  value       = aws_iam_role.api_task.arn
}

output "api_task_role_name" {
  description = "API task role name."
  value       = aws_iam_role.api_task.name
}

output "proxy_task_role_arn" {
  description = "Proxy task role ARN."
  value       = aws_iam_role.proxy_task.arn
}
