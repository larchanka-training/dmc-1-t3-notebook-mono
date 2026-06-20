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

variable "environment" {
  type    = string
  default = "dev"
}

variable "api_image" {
  type = string
}

variable "deploy_nonce" {
  type    = string
  default = ""
}

variable "db_name" {
  type    = string
  default = "t3_notebook_dev"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "log_level" {
  type    = string
  default = "INFO"
}
