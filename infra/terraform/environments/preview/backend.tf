terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # bucket, region, dynamodb_table and encrypt are fixed.
    # The state KEY is passed at `terraform init` time via -backend-config:
    #   -backend-config="key=preview/pr-{N}/terraform.tfstate"
    # See .github/workflows/preview.yml and cleanup.yml for the exact command.
    bucket         = "dmc-1-t3-notebook-terraform-state"
    region         = "eu-north-1"
    dynamodb_table = "dmc-1-t3-notebook-terraform-lock"
    encrypt        = true
  }
}
