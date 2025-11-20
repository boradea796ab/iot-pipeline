variable "vpc_id" {
  description = "ID of the VPC hosting the Aurora cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs mapped to the DB subnet group"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID assigned to the Lambda functions that need DB access"
  type        = string
}

variable "resource_name_prefix" {
  description = "Prefix added to Aurora-related AWS resources"
  type        = string
}

variable "aurora_engine" {
  description = "Aurora engine identifier"
  type        = string
}

variable "aurora_engine_version" {
  description = "Aurora engine version (leave null or blank for default)"
  type        = string
  default     = ""
}

variable "aurora_port" {
  description = "Port exposed by the Aurora cluster"
  type        = number
}

variable "aurora_database_name" {
  description = "Initial database name"
  type        = string
}

variable "aurora_master_username" {
  description = "Master username for the cluster"
  type        = string
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum ACUs"
  type        = number
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum ACUs"
  type        = number
}

variable "aurora_backup_retention_days" {
  description = "Automated backup retention in days"
  type        = number
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
}

variable "aurora_skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
}
