variable "name" {
  description = "ALB name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by the ALB."
  type        = list(string)
}

variable "internal" {
  description = "Whether the load balancer is internal."
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB."
  type        = bool
  default     = false
}

variable "listener_port" {
  description = "Frontend listener port."
  type        = number
  default     = 80
}

variable "listener_protocol" {
  description = "Frontend listener protocol."
  type        = string
  default     = "HTTP"
}

variable "ingress_cidr_blocks" {
  description = "CIDR ranges allowed to reach the ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Common tags applied to ALB resources."
  type        = map(string)
  default     = {}
}
