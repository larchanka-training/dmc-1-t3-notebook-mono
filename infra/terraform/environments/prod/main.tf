terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "t3-tfstate-867633231218"
    key            = "prod/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "t3-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-north-1"
}

# -------------------------------------------------------------------
# Shared modules
# -------------------------------------------------------------------

module "network" {
  source = "../../modules/network"
}

module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "t3-api"
}

# -------------------------------------------------------------------
# Secrets
# -------------------------------------------------------------------

data "aws_secretsmanager_secret_version" "db_url_prod" {
  secret_id = "t3/prod/database-url"
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "t3/github-token"
}

# -------------------------------------------------------------------
# RDS
# -------------------------------------------------------------------

module "rds" {
  source             = "../../modules/rds"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  allowed_security_group_ids = [module.apprunner_prod.vpc_connector_sg_id]

  db_name     = "t3_notebook_prod"
  db_username = var.db_username
  db_password = var.db_password
}

# -------------------------------------------------------------------
# AppRunner — production
# -------------------------------------------------------------------

module "apprunner_prod" {
  source             = "../../modules/apprunner"
  service_name       = "t3-api-prod"
  image_uri          = var.api_image_uri
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  env_vars = {
    DATABASE_URL = data.aws_secretsmanager_secret_version.db_url_prod.secret_string
    ENVIRONMENT  = "production"
  }
}

# -------------------------------------------------------------------
# AWS Amplify — UI
# -------------------------------------------------------------------

resource "aws_amplify_app" "ui" {
  name       = "t3-ui"
  repository = "https://github.com/larchanka-training/dmc-1-t3-notebook-mono"

  access_token = data.aws_secretsmanager_secret_version.github_token.secret_string

  build_spec = file("${path.module}/amplify_build_spec.yml")

  environment_variables = {
    VITE_API_URL = "https://${module.apprunner_prod.service_url}"
  }

  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true
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

# -------------------------------------------------------------------
# Custom domain (deferred — skipped when custom_domain is empty)
# -------------------------------------------------------------------

resource "aws_amplify_domain_association" "ui" {
  count = var.custom_domain != "" ? 1 : 0

  app_id      = aws_amplify_app.ui.id
  domain_name = var.custom_domain

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = ""
  }

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = "www"
  }
}

resource "aws_apprunner_custom_domain_association" "api" {
  count = var.custom_domain != "" ? 1 : 0

  service_arn          = module.apprunner_prod.service_arn
  domain_name          = "api.${var.custom_domain}"
  enable_www_subdomain = false
}
