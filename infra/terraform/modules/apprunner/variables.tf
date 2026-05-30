variable "service_name" {
  type        = string
  description = "Name of the AppRunner service"
}

variable "image_uri" {
  type        = string
  description = "Fully qualified ECR image URI"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC for the VPC connector"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "IDs of the private subnets for the VPC connector"
}

variable "env_vars" {
  type        = map(string)
  description = "Runtime environment variables for the AppRunner service"
  default     = {}
}

variable "cpu" {
  type        = string
  description = "CPU units for the AppRunner service (e.g. '1024')"
  default     = "1024"
}

variable "memory" {
  type        = string
  description = "Memory in MB for the AppRunner service (e.g. '2048')"
  default     = "2048"
}
