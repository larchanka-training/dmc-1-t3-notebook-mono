variable "repositories" {
  description = "ECR repositories to create."
  type        = set(string)
}

variable "scan_on_push" {
  description = "Enable image scanning on push."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Retention count for lifecycle policy."
  type        = number
  default     = 200
}

variable "replication_regions" {
  description = "Destination regions for cross-region image replication."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all repositories."
  type        = map(string)
  default     = {}
}
