variable "name" {
  description = "ECS service and task family name."
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster ARN."
  type        = string
}

variable "task_execution_role_arn" {
  description = "Task execution role ARN."
  type        = string
}

variable "task_role_arn" {
  description = "Task role ARN."
  type        = string
}

variable "cpu" {
  description = "Fargate CPU units."
  type        = number
}

variable "memory" {
  description = "Fargate memory in MiB."
  type        = number
}

variable "desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 1
}

variable "assign_public_ip" {
  description = "Assign public IPs to ECS tasks."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Subnet IDs used by the ECS service."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID used to create the service security group."
  type        = string
}

variable "ingress_security_group_ids" {
  description = "Security groups allowed to reach the service containers."
  type        = list(string)
  default     = []
}

variable "ingress_cidr_blocks" {
  description = "CIDR ranges allowed to reach the service containers."
  type        = list(string)
  default     = []
}

variable "container_definitions" {
  description = "Container definitions for the ECS task."
  type = list(object({
    name        = string
    image       = string
    essential   = optional(bool, true)
    command     = optional(list(string))
    entrypoint  = optional(list(string))
    environment = optional(map(string), {})
    secrets     = optional(map(string), {})
    port_mappings = optional(list(object({
      container_port = number
      host_port      = optional(number)
      protocol       = optional(string, "tcp")
    })), [])
    health_check = optional(object({
      command      = list(string)
      interval     = optional(number, 30)
      retries      = optional(number, 3)
      timeout      = optional(number, 5)
      start_period = optional(number, 0)
    }))
  }))
}

variable "load_balancer" {
  description = "Optional ALB integration."
  type = object({
    listener_arn      = string
    priority          = number
    path_patterns     = list(string)
    container_name    = string
    container_port    = number
    health_check_path = string
  })
  default  = null
  nullable = true
}

variable "service_discovery" {
  description = "Optional Cloud Map registration."
  type = object({
    namespace_id   = string
    namespace_name = string
    discovery_name = string
    container_name = string
    container_port = number
  })
  default  = null
  nullable = true
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent during deployment."
  type        = number
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum percent during deployment."
  type        = number
  default     = 200
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to ECS resources."
  type        = map(string)
  default     = {}
}
