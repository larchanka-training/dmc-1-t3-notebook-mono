variable "pr_number" {
  type        = string
  description = "Pull request number used as the resource name suffix (e.g. 42)"
}

variable "api_image_uri" {
  type        = string
  description = "Fully qualified ECR image URI for this PR (e.g. 123456789.dkr.ecr.eu-north-1.amazonaws.com/t3-api:pr-42-abc1234)"
}
