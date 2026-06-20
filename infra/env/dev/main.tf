data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

locals {
  runtime_environment = "staging"
  tags = {
    Project     = "dmc-1-t3-notebook"
    Repository  = var.repository
    ManagedBy   = "terraform"
    Owner       = "t3"
    Environment = var.environment
  }
}

module "alb" {
  source = "../../modules/alb"

  name       = "t3-notebook-${var.environment}-alb"
  vpc_id     = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.shared.outputs.public_subnet_ids
  tags       = local.tags
}

module "database" {
  source = "../../modules/rds"

  identifier          = "t3-notebook-${var.environment}-db"
  db_name             = var.db_name
  instance_class      = var.db_instance_class
  vpc_id              = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids          = data.terraform_remote_state.shared.outputs.private_db_subnet_ids
  allowed_cidr_blocks = [data.terraform_remote_state.shared.outputs.vpc_cidr]
  deletion_protection = false
  skip_final_snapshot = true
  tags                = local.tags
}

module "ui" {
  source = "../../modules/static-site"

  name              = "t3-notebook-${var.environment}-ui"
  bucket_name       = "t3-notebook-${var.environment}-ui"
  api_origin_domain = module.alb.alb_dns_name
  tags              = local.tags
}

module "api_service" {
  source = "../../modules/ecs-service"

  name                       = "t3-notebook-${var.environment}-api"
  cluster_arn                = data.terraform_remote_state.shared.outputs.ecs_cluster_arn
  task_execution_role_arn    = data.terraform_remote_state.shared.outputs.task_execution_role_arn
  task_role_arn              = data.terraform_remote_state.shared.outputs.api_task_role_arn
  cpu                        = 512
  memory                     = 1024
  desired_count              = 1
  subnet_ids                 = data.terraform_remote_state.shared.outputs.private_app_subnet_ids
  vpc_id                     = data.terraform_remote_state.shared.outputs.vpc_id
  ingress_security_group_ids = [module.alb.security_group_id]
  container_definitions = [
    {
      name  = "api"
      image = var.api_image
      environment = {
        ENVIRONMENT          = local.runtime_environment
        LOG_LEVEL            = var.log_level
        BACKEND_CORS_ORIGINS = "https://${module.ui.cloudfront_domain_name}"
        DEPLOY_NONCE         = var.deploy_nonce
      }
      secrets = {
        DATABASE_URL = "${module.database.connection_secret_arn}:url::"
      }
      port_mappings = [{
        container_port = 8000
      }]
    }
  ]
  load_balancer = {
    listener_arn      = module.alb.listener_arn
    priority          = 100
    path_patterns     = ["/api/*"]
    container_name    = "api"
    container_port    = 8000
    health_check_path = "/api/v1/health"
  }
  tags = local.tags
}
