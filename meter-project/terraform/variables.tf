variable "region" {
  default = "ap-northeast-1"
}

variable "device_secret_parameter_prefix" {
  description = "Optional SSM parameter path prefix for device HMAC secrets (include leading slash, omit device ID)"
  type        = string
  default     = ""
}

variable "device_secret_parameters" {
  description = "Map of device IDs to full SSM parameter names that store their HMAC secrets"
  type        = map(string)
  default     = {}
}

variable "idempotency_table_name" {
  description = "Name of the DynamoDB table used to track processed messages"
  type        = string
  default     = "iot-idempotency-table"
}

variable "idempotency_payload_ttl_seconds" {
  description = "How long (in seconds) to keep processed message payloads in DynamoDB"
  type        = number
  default     = 86400
}

variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (must have at least two)"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (must have at least two)"
  type        = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24",
  ]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required."
  }
}

variable "resource_name_prefix" {
  description = "Prefix used to name shared infrastructure resources like the VPC and subnets"
  type        = string
  default     = "meter"
}

variable "aurora_engine" {
  description = "Aurora database engine identifier (e.g., aurora-mysql or aurora-postgresql)"
  type        = string
  default     = "aurora-mysql"
}

variable "aurora_engine_version" {
  description = "Specific Aurora engine version to deploy (leave empty for AWS default)"
  type        = string
  default     = ""
}

variable "aurora_port" {
  description = "Port used by the Aurora cluster (3306 for MySQL, 5432 for PostgreSQL)"
  type        = number
  default     = 3306
}

variable "aurora_database_name" {
  description = "Initial database to create in the Aurora cluster"
  type        = string
  default     = "meter_app"
}

variable "aurora_master_username" {
  description = "Master username for the Aurora cluster (saved in Secrets Manager)"
  type        = string
  default     = "meter_admin"
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU capacity"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU capacity"
  type        = number
  default     = 2
}

variable "aurora_backup_retention_days" {
  description = "Number of days to retain automated Aurora backups"
  type        = number
  default     = 1
}

variable "aurora_deletion_protection" {
  description = "Whether to enable deletion protection on the Aurora cluster"
  type        = bool
  default     = false
}

variable "aurora_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the Aurora cluster (set to false in production)"
  type        = bool
  default     = true
}

variable "readings_table_name" {
  description = "Aurora table name used by the Lambda consumers"
  type        = string
  default     = "iot_readings"
}
