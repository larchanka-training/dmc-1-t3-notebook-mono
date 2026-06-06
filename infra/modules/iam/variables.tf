variable "name_prefix" {
  description = "Prefix used for ECS IAM role names."
  type        = string
}

variable "tags" {
  description = "Common tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
