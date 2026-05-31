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
    bucket         = "t3-tfstate-867633231218"
    region         = "eu-north-1"
    dynamodb_table = "t3-tfstate-lock"
    encrypt        = true
  }
}
