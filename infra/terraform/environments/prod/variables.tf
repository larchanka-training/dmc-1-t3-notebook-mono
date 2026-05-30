variable "api_image_uri" {
  type        = string
  description = "Fully qualified ECR image URI for the production API"
}

variable "db_username" {
  type        = string
  description = "Master username for the RDS instance"
  default     = "t3admin"
}

variable "db_password" {
  type        = string
  description = "Master password for the RDS instance"
  sensitive   = true
  default     = null
}

variable "custom_domain" {
  type        = string
  default     = ""
  description = "Custom domain name (e.g. notebook.example.com). Leave empty to use default AWS URLs."
}
