variable "api_image_uri" {
  type        = string
  description = "Fully qualified ECR image URI for the production API (passed by CI)"
}

variable "custom_domain" {
  type        = string
  default     = ""
  description = "Custom domain (e.g. notebook.example.com). Leave empty until domain is purchased."
}
