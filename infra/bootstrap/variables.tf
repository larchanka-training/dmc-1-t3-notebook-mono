variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  description = "Terraform remote state S3 bucket name."
  type        = string
  default     = "dmc-1-t3-notebook-terraform-state"
}

variable "lock_table_name" {
  description = "Terraform remote lock DynamoDB table name."
  type        = string
  default     = "dmc-1-t3-notebook-terraform-lock"
}

variable "repository" {
  description = "Repository tag value."
  type        = string
  default     = "larchanka-training/dmc-1-t3-notebook-mono"
}
