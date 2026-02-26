variable "project_name" {
  description = "Project prefix used for resource naming."
  type        = string
}

variable "kinesis_shard_count" {
  description = "Shard count for the telemetry stream."
  type        = number
  default     = 1
}

variable "kinesis_retention_hours" {
  description = "Kinesis stream retention in hours."
  type        = number
  default     = 24
}
