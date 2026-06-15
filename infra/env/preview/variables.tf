variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "repository" {
  type    = string
  default = "larchanka-training/dmc-1-t3-notebook-mono"
}

variable "shared_state_bucket" {
  type    = string
  default = "dmc-1-t3-notebook-terraform-state"
}

variable "shared_state_key" {
  type    = string
  default = "t3/dmc-1-t3-notebook-mono/shared/terraform.tfstate"
}

variable "shared_state_region" {
  type    = string
  default = "eu-north-1"
}

variable "pr_number" {
  type = number
}

variable "ui_image" {
  type = string
}

variable "api_image" {
  type = string
}

variable "database_url_secret_arn" {
  description = "Secrets Manager ARN containing preview DATABASE_URL in the 'url' JSON field."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:", var.database_url_secret_arn))
    error_message = "database_url_secret_arn must be a valid AWS Secrets Manager ARN (must start with 'arn:aws:secretsmanager:'). Set the PREVIEW_DATABASE_URL_SECRET_ARN GitHub secret."
  }
}

variable "preview_proxy_image" {
  type    = string
  default = "nginx:1.27-alpine"
}

variable "deploy_nonce" {
  type    = string
  default = ""
}

variable "log_level" {
  type    = string
  default = "INFO"
}
