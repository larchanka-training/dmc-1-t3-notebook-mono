output "vpc_id" {
  value = module.network.vpc_id
}

output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.network.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  value = module.network.private_db_subnet_ids
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "task_execution_role_arn" {
  value = module.iam.task_execution_role_arn
}

output "task_execution_role_name" {
  value = module.iam.task_execution_role_name
}

output "ui_task_role_arn" {
  value = module.iam.ui_task_role_arn
}

output "api_task_role_arn" {
  value = module.iam.api_task_role_arn
}

output "api_task_role_name" {
  value = module.iam.api_task_role_name
}

output "proxy_task_role_arn" {
  value = module.iam.proxy_task_role_arn
}

output "ecs_cluster_name" {
  value = module.observability.ecs_cluster_name
}

output "ecs_cluster_arn" {
  value = module.observability.ecs_cluster_arn
}

output "preview_alb_dns_name" {
  value = module.preview_alb.alb_dns_name
}

output "preview_alb_listener_arn" {
  value = module.preview_alb.listener_arn
}

output "preview_alb_security_group_id" {
  value = module.preview_alb.security_group_id
}

output "route53_zone_id" {
  value = aws_route53_zone.t3_jsnb_org.zone_id
}

output "route53_name_servers" {
  value = aws_route53_zone.t3_jsnb_org.name_servers
}

output "service_discovery_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.preview.id
}

output "service_discovery_namespace_name" {
  value = aws_service_discovery_private_dns_namespace.preview.name
}
