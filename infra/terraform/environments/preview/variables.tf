variable "pr_number" {
  type        = string
  description = "Pull request number; used as resource name suffix"
}

variable "api_image_uri" {
  type        = string
  description = "Fully qualified ECR image URI for this PR"
}
