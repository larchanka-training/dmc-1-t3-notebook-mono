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
  default = "prod"
}

variable "root_domain" {
  type    = string
  default = "t3.jsnb.org"
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
  default = "t3_notebook_prod"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "log_level" {
  type    = string
  default = "INFO"
}

variable "dr_region" {
  description = "Secondary AWS region for disaster-recovery replication of secrets."
  type        = string
  default     = "eu-west-1"
}

variable "dr_secondary_alb_dns_name" {
  description = "DR-region ALB DNS name for the API SECONDARY failover record. Empty disables failover routing and keeps a single primary alias (no SERVFAIL risk)."
  type        = string
  default     = ""
}

variable "dr_secondary_alb_zone_id" {
  description = "DR-region ALB hosted zone ID for the API SECONDARY failover record. Required when dr_secondary_alb_dns_name is set."
  type        = string
  default     = ""
}

variable "ops_alert_email" {
  description = "Email subscribed to operational SNS alerts (budgets, alarms)."
  type        = string
  default     = "ops@t3.jsnb.org"
}

variable "bedrock_monthly_budget_usd" {
  description = "Monthly Amazon Bedrock cost budget in USD."
  type        = number
  default     = 200
}
