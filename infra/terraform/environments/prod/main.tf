provider "aws" {
  region = "eu-north-1"
}

locals {
  prefix = "t3"
  tags = {
    Project     = "t3-notebook"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
module "network" {
  source   = "../../modules/network"
  prefix   = local.prefix
  vpc_cidr = "10.0.0.0/16"
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# ECR — container registry for the API image
# ---------------------------------------------------------------------------
module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "${local.prefix}-api"
  tags            = local.tags
}

# ---------------------------------------------------------------------------
# RDS — PostgreSQL 16 (shared by prod and preview environments)
# NOTE: After first apply, manually connect to RDS and run:
#   CREATE DATABASE t3_notebook_preview;
# The preview DATABASE_URL secret is set automatically below.
# ---------------------------------------------------------------------------
resource "random_password" "db" {
  length           = 32
  special          = true
  # Exclude URL-unsafe characters so the connection string needs no encoding
  override_special = "!#%^*()-_+=[]<>~"
}

module "rds" {
  source          = "../../modules/rds"
  identifier      = "${local.prefix}-postgres"
  db_name         = "t3_notebook_prod"
  master_username = "t3admin"
  master_password = random_password.db.result
  subnet_ids      = module.network.private_subnet_ids
  rds_sg_id       = module.network.rds_sg_id
  tags            = local.tags
}

# ---------------------------------------------------------------------------
# Secrets Manager — connection strings consumed by AppRunner at runtime
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "prod_db_url" {
  name                    = "t3/prod/database-url"
  description             = "PostgreSQL connection URL for production"
  recovery_window_in_days = 7
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "prod_db_url" {
  secret_id     = aws_secretsmanager_secret.prod_db_url.id
  secret_string = "postgresql://${module.rds.master_username}:${random_password.db.result}@${module.rds.address}:${module.rds.port}/t3_notebook_prod"
}

resource "aws_secretsmanager_secret" "preview_db_url" {
  name                    = "t3/preview/database-url"
  description             = "PostgreSQL connection URL for preview PRs (shared database)"
  recovery_window_in_days = 7
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "preview_db_url" {
  secret_id     = aws_secretsmanager_secret.preview_db_url.id
  secret_string = "postgresql://${module.rds.master_username}:${random_password.db.result}@${module.rds.address}:${module.rds.port}/t3_notebook_preview"
}

# ---------------------------------------------------------------------------
# IAM — AppRunner access role (pull images from ECR)
# Created once; shared with preview environments via remote state outputs.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "apprunner_ecr_access" {
  name = "${local.prefix}-apprunner-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "build.apprunner.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# ---------------------------------------------------------------------------
# IAM — AppRunner instance role (runtime access to Secrets Manager)
# Created once; shared with preview environments via remote state outputs.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "apprunner_instance" {
  name = "${local.prefix}-apprunner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "tasks.apprunner.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "apprunner_secrets" {
  name = "${local.prefix}-apprunner-secrets-policy"
  role = aws_iam_role.apprunner_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:eu-north-1:867633231218:secret:t3/*"
    }]
  })
}

# ---------------------------------------------------------------------------
# VPC connector — shared between prod and preview AppRunner services
# Created once; ARN is exported via outputs and read by preview environment.
# ---------------------------------------------------------------------------
resource "aws_apprunner_vpc_connector" "main" {
  vpc_connector_name = "${local.prefix}-vpc-connector"
  subnets            = module.network.private_subnet_ids
  security_groups    = [module.network.apprunner_sg_id]
  tags               = local.tags
}

# ---------------------------------------------------------------------------
# AppRunner — production API service
# ---------------------------------------------------------------------------
module "apprunner_prod" {
  source = "../../modules/apprunner"

  service_name      = "${local.prefix}-api-prod"
  image_uri         = var.api_image_uri
  vpc_connector_arn = aws_apprunner_vpc_connector.main.arn
  access_role_arn   = aws_iam_role.apprunner_ecr_access.arn
  instance_role_arn = aws_iam_role.apprunner_instance.arn

  environment_variables = {
    ENVIRONMENT = "production"
  }

  secrets = {
    DATABASE_URL = aws_secretsmanager_secret.prod_db_url.arn
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Amplify — UI hosting with PR previews
# The build spec is read from ui/amplify.yml in the repository root.
# VITE_API_URL is set to the production AppRunner URL and overridden per
# PR branch by the preview.yml GitHub Actions workflow.
# ---------------------------------------------------------------------------
data "aws_secretsmanager_secret_version" "github_token" {
  # Secret must be created manually in Phase 1 (bootstrap):
  #   aws secretsmanager create-secret --name t3/github-token --secret-string "<PAT>"
  secret_id = "t3/github-token"
}

resource "aws_amplify_app" "ui" {
  name         = "${local.prefix}-ui"
  repository   = "https://github.com/larchanka-training/dmc-1-t3-notebook-mono"
  access_token = data.aws_secretsmanager_secret_version.github_token.secret_string

  # Inline build spec mirrors ui/amplify.yml; Amplify uses this as fallback
  # if amplify.yml is not found at the repo root.
  build_spec = file("${path.module}/../../../../ui/amplify.yml")

  environment_variables = {
    VITE_API_URL = "https://${module.apprunner_prod.service_url}"
  }

  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true

  tags = local.tags
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.ui.id
  branch_name = "main"
  stage       = "PRODUCTION"
  framework   = "React"

  environment_variables = {
    VITE_API_URL = "https://${module.apprunner_prod.service_url}"
  }
}

# ---------------------------------------------------------------------------
# Custom domain (deferred) — uncomment once domain is purchased
# ---------------------------------------------------------------------------
# resource "aws_amplify_domain_association" "ui" {
#   count       = var.custom_domain != "" ? 1 : 0
#   app_id      = aws_amplify_app.ui.id
#   domain_name = var.custom_domain
#
#   sub_domain {
#     branch_name = aws_amplify_branch.main.branch_name
#     prefix      = ""
#   }
#
#   sub_domain {
#     branch_name = aws_amplify_branch.main.branch_name
#     prefix      = "www"
#   }
# }
#
# resource "aws_apprunner_custom_domain_association" "api" {
#   count                = var.custom_domain != "" ? 1 : 0
#   service_arn          = module.apprunner_prod.service_arn
#   domain_name          = "api.${var.custom_domain}"
#   enable_www_subdomain = false
# }
