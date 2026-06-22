data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

data "aws_caller_identity" "current" {}

locals {
  runtime_environment = "production"
  root_domain         = var.root_domain
  api_domain          = "api.${var.root_domain}"
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

resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = local.root_domain
  subject_alternative_names = ["*.${local.root_domain}"]
  validation_method         = "DNS"

  tags = merge(local.tags, {
    Name = "${local.root_domain} CloudFront"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_cloudfront" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.terraform_remote_state.shared.outputs.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_cloudfront : record.fqdn]
}

resource "aws_acm_certificate" "alb" {
  domain_name       = local.api_domain
  validation_method = "DNS"

  tags = merge(local.tags, {
    Name = "${local.api_domain} ALB"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_alb" {
  for_each = {
    for dvo in aws_acm_certificate.alb.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.terraform_remote_state.shared.outputs.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_alb : record.fqdn]
}

module "ui" {
  source = "../../modules/static-site"

  name                = "t3-notebook-${var.environment}-ui"
  bucket_name         = "t3-notebook-${var.environment}-ui"
  api_origin_domain   = module.alb.alb_dns_name
  domain_name         = local.root_domain
  acm_certificate_arn = aws_acm_certificate_validation.cloudfront.certificate_arn
  tags                = local.tags
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
        BACKEND_CORS_ORIGINS = "https://${local.root_domain}"
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

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = module.alb.security_group_id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_lb_listener" "alb_https" {
  load_balancer_arn = module.alb.alb_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = module.api_service.target_group_arn
  }
}

resource "aws_route53_record" "ui" {
  zone_id         = data.terraform_remote_state.shared.outputs.route53_zone_id
  name            = local.root_domain
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = module.ui.cloudfront_domain_name
    zone_id                = module.ui.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api" {
  zone_id         = data.terraform_remote_state.shared.outputs.route53_zone_id
  name            = local.api_domain
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Execution role: pulls DATABASE_URL secret at container start (ECS secrets injection)
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

# Task role: app calls GetSecretValue at runtime via boto3 (_load_aws_secret)
resource "aws_iam_role_policy" "api_task_secrets" {
  name = "t3-notebook-${var.environment}-api-task-secrets"
  role = data.terraform_remote_state.shared.outputs.api_task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.api_config.arn]
      }
    ]
  })
}

# Task role: app sends OTP emails via Amazon SES
resource "aws_iam_role_policy" "api_task_ses" {
  name = "t3-notebook-${var.environment}-api-task-ses"
  role = data.terraform_remote_state.shared.outputs.api_task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = ["*"]
      }
    ]
  })
}
