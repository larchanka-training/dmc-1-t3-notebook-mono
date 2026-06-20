variable "name" {
  description = "Name used for the CloudFront OAC and distribution."
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name to host UI static assets."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
