variable "aws_region" {
  description = "AWS region for shared infrastructure."
  type        = string
  default     = "eu-north-1"
}

variable "repository" {
  description = "Repository tag value."
  type        = string
  default     = "larchanka-training/dmc-1-t3-notebook-mono"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated t3 VPC."
  type        = string
  default     = "10.30.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the shared network."
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b"]
}

variable "nat_gateway_mode" {
  description = "Whether to use a single NAT gateway or one per AZ."
  type        = string
  default     = "single"
}

variable "cloud_map_namespace_name" {
  description = "Private DNS namespace for preview-side service discovery."
  type        = string
  default     = "t3-notebook.internal"
}
