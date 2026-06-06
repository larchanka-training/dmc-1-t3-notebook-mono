variable "name_prefix" {
  description = "Prefix used for network resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used to spread subnets across the region."
  type        = list(string)
}

variable "nat_gateway_mode" {
  description = "Use a single NAT gateway or one per AZ."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per-az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be either 'single' or 'per-az'."
  }
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
