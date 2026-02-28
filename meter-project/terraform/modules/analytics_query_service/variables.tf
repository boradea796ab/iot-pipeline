variable "project_name" {
  description = "Project prefix used for resource naming."
  type        = string
}

variable "aws_region" {
  description = "AWS region for regional ARNs."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC attachment."
  type        = list(string)
}

variable "lambda_security_group_ids" {
  description = "Security groups for Lambda VPC attachment."
  type        = list(string)
}

variable "lambda_source_dir" {
  description = "Directory containing analytics query Lambda source code."
  type        = string
}

variable "lambda_zip_path" {
  description = "Path where the Lambda deployment zip is built."
  type        = string
}

variable "lambda_timeout_seconds" {
  description = "Analytics query Lambda timeout in seconds."
  type        = number
  default     = 15
}

variable "lambda_memory_mb" {
  description = "Analytics query Lambda memory size in MB."
  type        = number
  default     = 256
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for the analytics query Lambda."
  type        = number
  default     = 5
}

variable "log_retention_days" {
  description = "CloudWatch log retention for analytics query Lambda."
  type        = number
  default     = 14
}

variable "api_stage_name" {
  description = "HTTP API stage name."
  type        = string
  default     = "v1"
}
