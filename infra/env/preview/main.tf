data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

locals {
  environment        = "pr-${var.pr_number}"
  preview_path       = "/pr-${var.pr_number}"
  route_priority     = 10000 + var.pr_number
  ui_service_name    = "t3-notebook-pr-${var.pr_number}-ui"
  api_service_name   = "t3-notebook-pr-${var.pr_number}-api"
  proxy_service_name = "t3-notebook-pr-${var.pr_number}-proxy"
  namespace_name     = data.terraform_remote_state.shared.outputs.service_discovery_namespace_name
  ui_discovery_fqdn  = "${local.ui_service_name}.${local.namespace_name}"
  api_discovery_fqdn = "${local.api_service_name}.${local.namespace_name}"
  proxy_command      = <<-EOT
    cat <<'EOF' >/etc/nginx/conf.d/default.conf
    server {
      listen 8080;

      location = /healthz {
        return 200;
      }

      location ~ ^${local.preview_path}/api/?(.*)$ {
        proxy_pass http://${local.api_discovery_fqdn}:8000/api/$1$is_args$args;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }

      location ~ ^${local.preview_path}/?(.*)$ {
        proxy_pass http://${local.ui_discovery_fqdn}:80/$1$is_args$args;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
    EOF
    nginx -g 'daemon off;'
  EOT
  tags = {
    Project     = "dmc-1-t3-notebook"
    Repository  = var.repository
    ManagedBy   = "terraform"
    Owner       = "t3"
    Environment = local.environment
  }
}

module "db" {
  source = "../../modules/rds"

  identifier              = "t3-notebook-pr-${var.pr_number}"
  db_name                 = "notebook"
  vpc_id                  = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_db_subnet_ids
  allowed_cidr_blocks     = [data.terraform_remote_state.shared.outputs.vpc_cidr]
  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = 0

  tags = local.tags
}

module "ui_service" {
  source = "../../modules/ecs-service"

  name                    = local.ui_service_name
  cluster_arn             = data.terraform_remote_state.shared.outputs.ecs_cluster_arn
  task_execution_role_arn = data.terraform_remote_state.shared.outputs.task_execution_role_arn
  task_role_arn           = data.terraform_remote_state.shared.outputs.ui_task_role_arn
  cpu                     = 256
  memory                  = 512
  desired_count           = 1
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_app_subnet_ids
  vpc_id                  = data.terraform_remote_state.shared.outputs.vpc_id
  ingress_cidr_blocks     = [data.terraform_remote_state.shared.outputs.vpc_cidr]
  container_definitions = [
    {
      name  = "ui"
      image = var.ui_image
      environment = {
        DEPLOY_NONCE = var.deploy_nonce
      }
      port_mappings = [{
        container_port = 80
      }]
    }
  ]
  service_discovery = {
    namespace_id   = data.terraform_remote_state.shared.outputs.service_discovery_namespace_id
    namespace_name = local.namespace_name
    discovery_name = local.ui_service_name
    container_name = "ui"
    container_port = 80
  }
  tags = local.tags
}

module "api_service" {
  source = "../../modules/ecs-service"

  name                    = local.api_service_name
  cluster_arn             = data.terraform_remote_state.shared.outputs.ecs_cluster_arn
  task_execution_role_arn = data.terraform_remote_state.shared.outputs.task_execution_role_arn
  task_role_arn           = data.terraform_remote_state.shared.outputs.api_task_role_arn
  cpu                     = 512
  memory                  = 1024
  desired_count           = 1
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_app_subnet_ids
  vpc_id                  = data.terraform_remote_state.shared.outputs.vpc_id
  ingress_cidr_blocks     = [data.terraform_remote_state.shared.outputs.vpc_cidr]
  container_definitions = [
    {
      name  = "api"
      image = var.api_image
      environment = {
        ENVIRONMENT          = "staging"
        LOG_LEVEL            = var.log_level
        BACKEND_CORS_ORIGINS = "http://${data.terraform_remote_state.shared.outputs.preview_alb_dns_name}"
        DEPLOY_NONCE         = var.deploy_nonce
      }
      secrets = {
        DATABASE_URL = "${module.db.connection_secret_arn}:url::"
      }
      port_mappings = [{
        container_port = 8000
      }]
    }
  ]
  service_discovery = {
    namespace_id   = data.terraform_remote_state.shared.outputs.service_discovery_namespace_id
    namespace_name = local.namespace_name
    discovery_name = local.api_service_name
    container_name = "api"
    container_port = 8000
  }
  tags = local.tags
}

module "proxy_service" {
  source = "../../modules/ecs-service"

  name                       = local.proxy_service_name
  cluster_arn                = data.terraform_remote_state.shared.outputs.ecs_cluster_arn
  task_execution_role_arn    = data.terraform_remote_state.shared.outputs.task_execution_role_arn
  task_role_arn              = data.terraform_remote_state.shared.outputs.proxy_task_role_arn
  cpu                        = 256
  memory                     = 512
  desired_count              = 1
  subnet_ids                 = data.terraform_remote_state.shared.outputs.private_app_subnet_ids
  vpc_id                     = data.terraform_remote_state.shared.outputs.vpc_id
  ingress_security_group_ids = [data.terraform_remote_state.shared.outputs.preview_alb_security_group_id]
  container_definitions = [
    {
      name    = "proxy"
      image   = var.preview_proxy_image
      command = ["/bin/sh", "-c", trimspace(local.proxy_command)]
      environment = {
        DEPLOY_NONCE = var.deploy_nonce
      }
      port_mappings = [{
        container_port = 8080
      }]
    }
  ]
  load_balancer = {
    listener_arn      = data.terraform_remote_state.shared.outputs.preview_alb_listener_arn
    priority          = local.route_priority
    path_patterns     = [local.preview_path, "${local.preview_path}/*"]
    container_name    = "proxy"
    container_port    = 8080
    health_check_path = "/healthz"
  }
  tags = local.tags
}
