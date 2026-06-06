variable "cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "tags" {
  description = "Common tags applied to observability resources."
  type        = map(string)
  default     = {}
}
