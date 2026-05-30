terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend key is passed via -backend-config in GitHub Actions (preview.yml / cleanup.yml)
  # key = "preview/pr-${var.pr_number}/terraform.tfstate"
  backend "s3" {}
}

provider "aws" {
  region = "eu-north-1"
}

# -------------------------------------------------------------------
# Re-use existing VPC outputs (data sources referencing prod state)
# -------------------------------------------------------------------

data "terraform_remote_state" "prod" {
  backend = "s3"

  config = {
    bucket = "t3-tfstate-867633231218"
    key    = "prod/terraform.tfstate"
    region = "eu-north-1"
  }
}

# -------------------------------------------------------------------
# Secrets
# -------------------------------------------------------------------

data "aws_secretsmanager_secret_version" "db_url_preview" {
  secret_id = "t3/preview/database-url"
}

# -------------------------------------------------------------------
# AppRunner — per-PR preview
# -------------------------------------------------------------------

module "apprunner_preview" {
  source             = "../../modules/apprunner"
  service_name       = "t3-api-pr-${var.pr_number}"
  image_uri          = var.api_image_uri
  vpc_id             = data.terraform_remote_state.prod.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.prod.outputs.private_subnet_ids

  env_vars = {
    DATABASE_URL = data.aws_secretsmanager_secret_version.db_url_preview.secret_string
    ENVIRONMENT  = "preview"
  }
}
