variable "name" {
  description = "Name used for the CloudFront OAC and distribution."
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name to host UI static assets."
  type        = string
}

variable "api_origin_domain" {
  description = "ALB DNS name to proxy /api/* requests to. CloudFront connects over HTTP; TLS is terminated at CloudFront."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
