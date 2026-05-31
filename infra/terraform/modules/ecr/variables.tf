variable "repository_name" {
  type        = string
  description = "Name of the ECR repository (e.g. t3-api)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
