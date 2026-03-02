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

variable "influx_org" {
  description = "InfluxDB organization used for query execution."
  type        = string
}

variable "influx_hot_bucket_name" {
  description = "InfluxDB hot bucket used for recent high-granularity queries."
  type        = string
}

variable "influx_cold_bucket_name" {
  description = "InfluxDB cold bucket used for downsampled historical queries."
  type        = string
}

variable "influxdb_query_url_ssm_parameter" {
  description = "SSM parameter containing Influx query API URL (for example https://<endpoint>:8086/api/v2/query)."
  type        = string
  default     = "/smart-meter/iot/influxdb/query-url"
}

variable "influxdb_read_token_ssm_parameter" {
  description = "SSM parameter containing Influx read token."
  type        = string
  default     = "/smart-meter/iot/influxdb/read-token"
}

variable "hot_retention_days" {
  description = "Number of days raw hot data is retained."
  type        = number
  default     = 7
}

variable "max_lookback_days" {
  description = "Maximum allowed query lookback window in days."
  type        = number
  default     = 370
}

variable "max_series_limit" {
  description = "Maximum number of rows returned by the query API."
  type        = number
  default     = 5000
}

variable "max_meter_ids" {
  description = "Maximum number of meter IDs accepted per request."
  type        = number
  default     = 100
}

variable "query_timeout_seconds" {
  description = "Timeout applied to Influx query HTTP calls."
  type        = number
  default     = 10
}

variable "invoke_role_arns" {
  description = "IAM role ARNs that should receive execute-api invoke permission."
  type        = list(string)
  default     = []
}

variable "metrics_namespace" {
  description = "CloudWatch metrics namespace emitted by the analytics query Lambda."
  type        = string
  default     = "SmartMeter/AnalyticsQuery"
}
