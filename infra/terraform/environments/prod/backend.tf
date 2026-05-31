terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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
