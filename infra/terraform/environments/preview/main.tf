provider "aws" {
  region = "eu-north-1"
}

locals {
  tags = {
    Project     = "t3-notebook"
    Environment = "preview"
    PR          = var.pr_number
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Read shared infrastructure outputs from the production Terraform state.
# The VPC connector, IAM roles, and preview DB secret were created once in
# the prod environment and are reused by every PR preview to avoid conflicts.
# ---------------------------------------------------------------------------
data "terraform_remote_state" "prod" {
  backend = "s3"
  config = {
    bucket = "dmc-1-t3-notebook-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "eu-north-1"
  }
}

# ---------------------------------------------------------------------------
# AppRunner — per-PR preview API service
# Destroyed when the PR is closed (cleanup.yml).
# ---------------------------------------------------------------------------
module "apprunner_preview" {
  source = "../../modules/apprunner"

  service_name      = "t3-api-pr-${var.pr_number}"
  image_uri         = var.api_image_uri
  vpc_connector_arn = data.terraform_remote_state.prod.outputs.vpc_connector_arn
  access_role_arn   = data.terraform_remote_state.prod.outputs.apprunner_ecr_role_arn
  instance_role_arn = data.terraform_remote_state.prod.outputs.apprunner_instance_role_arn

  environment_variables = {
    ENVIRONMENT = "preview"
    PR_NUMBER   = var.pr_number
  }

  # DATABASE_URL is fetched from Secrets Manager at runtime.
  # All preview services share t3/preview/database-url (t3_notebook_preview database).
  secrets = {
    DATABASE_URL = data.terraform_remote_state.prod.outputs.preview_db_url_secret_arn
  }

  tags = local.tags
}
