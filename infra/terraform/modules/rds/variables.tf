variable "identifier" {
  type        = string
  description = "RDS instance identifier (e.g. t3-postgres)"
}

variable "db_name" {
  type        = string
  description = "Name of the initial database created on the instance"
}

variable "master_username" {
  type        = string
  default     = "t3admin"
  description = "Master DB username"
}

variable "master_password" {
  type        = string
  sensitive   = true
  description = "Master DB password (store in Secrets Manager; passed from the calling environment)"
}

variable "instance_class" {
  type        = string
  default     = "db.t4g.micro"
  description = "RDS instance class"
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Allocated storage in GiB"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group"
}

variable "rds_sg_id" {
  type        = string
  description = "Security group ID to attach to the RDS instance"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
