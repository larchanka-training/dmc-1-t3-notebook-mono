variable "service_name" {
  type        = string
  description = "AppRunner service name (e.g. t3-api-prod or t3-api-pr-42)"
}

variable "image_uri" {
  type        = string
  description = "Fully qualified ECR image URI including tag"
}

variable "cpu" {
  type        = string
  default     = "256"
  description = "vCPU units for each AppRunner instance (256 = 0.25 vCPU)"
}

variable "memory" {
  type        = string
  default     = "512"
  description = "Memory in MiB for each AppRunner instance"
}

variable "port" {
  type        = string
  default     = "8000"
  description = "Port the container listens on"
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Plain-text environment variables injected into the container"
}

variable "secrets" {
  type        = map(string)
  default     = {}
  description = "Map of env var name → Secrets Manager secret ARN. Values are fetched at runtime."
}

variable "vpc_connector_arn" {
  type        = string
  description = "ARN of the AppRunner VPC connector for private subnet egress"
}

variable "access_role_arn" {
  type        = string
  description = "IAM role ARN that AppRunner uses to pull images from ECR"
}

variable "instance_role_arn" {
  type        = string
  description = "IAM instance role ARN for the running container (Secrets Manager, etc.)"
}

variable "health_check_path" {
  type        = string
  default     = "/api/v1/health"
  description = "HTTP path used by AppRunner health checks"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
