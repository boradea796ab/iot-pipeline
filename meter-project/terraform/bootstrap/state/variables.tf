variable "aws_region" {
  description = "AWS region for the bootstrap state infrastructure."
  type        = string
}

variable "project_name" {
  description = "Project identifier used in default resource names and tags."
  type        = string
  default     = "smart-meter-iot"
}

variable "environment" {
  description = "Environment identifier for tagging."
  type        = string
  default     = "shared"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name to store Terraform state."
  type        = string
}

variable "lock_table_name" {
  description = "Optional explicit DynamoDB lock table name."
  type        = string
  default     = null
}

variable "enable_dynamodb_lock_table" {
  description = "Whether to create DynamoDB lock table for Terraform state locking."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for S3 default encryption. If null, AES256 is used."
  type        = string
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep non-current object versions before expiration."
  type        = number
  default     = 90
}

variable "additional_tags" {
  description = "Additional tags for bootstrap resources."
  type        = map(string)
  default     = {}
}
