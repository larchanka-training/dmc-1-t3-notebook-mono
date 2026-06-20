data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

locals {
  runtime_environment = "production"
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

  name                       = "t3-notebook-${var.environment}-alb"
  vpc_id                     = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids                 = data.terraform_remote_state.shared.outputs.public_subnet_ids
  enable_deletion_protection = true
  tags                       = local.tags
}

module "database" {
  source = "../../modules/rds"

  identifier              = "t3-notebook-${var.environment}-db"
  db_name                 = var.db_name
  instance_class          = var.db_instance_class
  vpc_id                  = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_db_subnet_ids
  allowed_cidr_blocks     = [data.terraform_remote_state.shared.outputs.vpc_cidr]
  multi_az                = true
  deletion_protection     = true
  skip_final_snapshot     = false
  backup_retention_period = 14
  tags                    = local.tags
}

module "ui" {
  source = "../../modules/static-site"

  name              = "t3-notebook-${var.environment}-ui"
  bucket_name       = "t3-notebook-${var.environment}-ui"
  api_origin_domain = module.alb.alb_dns_name
  tags              = local.tags
}

# Single AWS secret for all API application configuration.
# Stored in plain-text ini (KEY=VALUE) format.
# Terraform creates the secret resource and a one-time placeholder version.
# The real secret VALUE must be set once via AWS CLI or console and is
# never overwritten by Terraform (see lifecycle.ignore_changes).
resource "aws_secretsmanager_secret" "api_config" {
  name                    = "t3-notebook-${var.environment}/api-config"
  description             = "API application configuration in KEY=VALUE ini format"
  recovery_window_in_days = 7

  tags = merge(local.tags, {
    Name = "t3-notebook-${var.environment}/api-config"
  })
}

resource "aws_secretsmanager_secret_version" "api_config_placeholder" {
  secret_id = aws_secretsmanager_secret.api_config.id

  # Placeholder created on first apply only.
  # Replace actual values via:
  #   aws secretsmanager put-secret-value \
  #     --secret-id t3-notebook-prod/api-config \
  #     --secret-string "$(cat api/.env.prod)"
  secret_string = <<-EOT
    AUTH_OTP_HASH_SECRET=CHANGE_ME
    AUTH_SESSION_HASH_SECRET=CHANGE_ME
    AUTH_OAUTH_STATE_SIGNING_SECRET=CHANGE_ME
    GOOGLE_OAUTH_CLIENT_ID=CHANGE_ME
    GOOGLE_OAUTH_CLIENT_SECRET=CHANGE_ME
    GOOGLE_OAUTH_REDIRECT_URI=https://CHANGE_ME/api/v1/auth/google/callback
    GOOGLE_OAUTH_SUCCESS_REDIRECT_URL=https://CHANGE_ME/
    GOOGLE_OAUTH_ERROR_REDIRECT_URL=https://CHANGE_ME/auth/error
  EOT

  lifecycle {
    ignore_changes = [secret_string]
  }
}

module "api_service" {
  source = "../../modules/ecs-service"

  name                       = "t3-notebook-${var.environment}-api"
  cluster_arn                = data.terraform_remote_state.shared.outputs.ecs_cluster_arn
  task_execution_role_arn    = data.terraform_remote_state.shared.outputs.task_execution_role_arn
  task_role_arn              = data.terraform_remote_state.shared.outputs.api_task_role_arn
  cpu                        = 512
  memory                     = 1024
  desired_count              = 2
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
        AWS_DEFAULT_REGION   = var.aws_region
        AWS_APP_SECRET_ARN   = aws_secretsmanager_secret.api_config.arn
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

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "t3-notebook-${var.environment}-task-execution-secrets"
  role = data.terraform_remote_state.shared.outputs.task_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          module.database.connection_secret_arn,
          aws_secretsmanager_secret.api_config.arn,
        ]
      }
    ]
  })
}
