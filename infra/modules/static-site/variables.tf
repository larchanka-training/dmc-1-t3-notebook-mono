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

variable "domain_name" {
  description = "Custom domain for CloudFront (e.g. t3.jsnb.org). If empty, CloudFront default certificate is used."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the custom domain."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
