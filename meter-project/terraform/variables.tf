variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-1"
}

variable "project_name" {
  type        = string
  description = "Project prefix for naming"
  default     = "smart-meter-iot"
}

variable "sim_meter_thing_name" {
  type        = string
  description = "Thing name for simulator device"
  default     = "sim-meter-001"
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
  default     = []
}

variable "name_prefix" {
  description = "Prefix used to name shared infrastructure resources like the VPC and subnets"
  type        = string
  default     = "network"
}

variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "kinesis_shard_count" {
  description = "Shard count for IoT telemetry Kinesis stream."
  type        = number
  default     = 1
}

variable "kinesis_retention_hours" {
  description = "Retention period (hours) for IoT telemetry Kinesis stream."
  type        = number
  default     = 24
}

variable "influxdb_organization" {
  description = "InfluxDB organization name."
  type        = string
  default     = "VCC"
}

variable "influxdb_bucket_name" {
  description = "Optional explicit InfluxDB bucket name. Null defaults to <project_name>-influxdb-bucket."
  type        = string
  default     = null
}

variable "influxdb_instance_class" {
  description = "Timestream for InfluxDB instance class."
  type        = string
  default     = "db.influx.medium"
}

variable "influxdb_allocated_storage_gb" {
  description = "Timestream for InfluxDB allocated storage in GB."
  type        = number
  default     = 20
}

variable "influxdb_ingress_cidr_blocks" {
  description = "Optional CIDR blocks allowed to connect to InfluxDB in addition to Lambda SG."
  type        = list(string)
  default     = []
}

variable "influxdb_admin_password_length" {
  description = "Length for generated InfluxDB admin password."
  type        = number
  default     = 20
}

variable "publish_influxdb_admin_credentials_to_ssm" {
  description = "Whether to publish generated InfluxDB admin credentials to SSM Parameter Store."
  type        = bool
  default     = false
}

variable "influxdb_admin_ssm_parameter_prefix" {
  description = "SSM parameter prefix used when publishing InfluxDB admin credentials."
  type        = string
  default     = "/smart-meter/iot/influxdb/admin"
}

variable "influx_hot_bucket_name" {
  description = "Hot bucket name for raw recent data."
  type        = string
  default     = null
}

variable "influx_cold_bucket_name" {
  description = "Cold bucket name for downsampled historical data."
  type        = string
  default     = null
}

variable "analytics_query_lambda_timeout_seconds" {
  description = "Analytics query Lambda timeout in seconds."
  type        = number
  default     = 15
}

variable "analytics_query_lambda_memory_mb" {
  description = "Analytics query Lambda memory in MB."
  type        = number
  default     = 256
}

variable "analytics_query_lambda_reserved_concurrency" {
  description = "Reserved concurrency for analytics query Lambda."
  type        = number
  default     = 5
}

variable "analytics_query_log_retention_days" {
  description = "CloudWatch Logs retention for analytics query Lambda."
  type        = number
  default     = 14
}

variable "analytics_query_api_stage_name" {
  description = "API stage name for analytics query HTTP API."
  type        = string
  default     = "v1"
}

variable "analytics_query_influxdb_query_url_ssm_parameter" {
  description = "SSM parameter name containing Influx query API URL."
  type        = string
  default     = "/smart-meter/iot/influxdb/query-url"
}

variable "analytics_query_influxdb_read_token_ssm_parameter" {
  description = "SSM parameter name containing Influx read token for analytics queries."
  type        = string
  default     = "/smart-meter/iot/influxdb/read-token"
}

variable "analytics_query_hot_retention_days" {
  description = "Hot bucket retention (days) used by query-routing logic."
  type        = number
  default     = 7
}

variable "analytics_query_max_lookback_days" {
  description = "Maximum query lookback window in days."
  type        = number
  default     = 370
}

variable "analytics_query_max_series_limit" {
  description = "Maximum returned rows from analytics query API."
  type        = number
  default     = 5000
}

variable "analytics_query_max_meter_ids" {
  description = "Maximum meter IDs accepted in analytics query request filters."
  type        = number
  default     = 100
}

variable "analytics_query_influx_timeout_seconds" {
  description = "Timeout in seconds for Lambda calls to Influx query API."
  type        = number
  default     = 10
}

variable "analytics_query_invoke_role_arns" {
  description = "IAM role ARNs allowed to invoke analytics query API (policy attachment target)."
  type        = list(string)
  default     = []
}

variable "analytics_query_metrics_namespace" {
  description = "CloudWatch metrics namespace for analytics query Lambda EMF metrics."
  type        = string
  default     = "SmartMeter/AnalyticsQuery"
}

variable "grafana_admin_role_arns" {
  description = "IAM role ARNs that should be Grafana workspace admins (usually your SSO roles)."
  type        = list(string)
  default     = ["arn:aws:iam::808329257566:role/aws-reserved/sso.amazonaws.com/ap-northeast-1/AWSReservedSSO_GrafanaAdmin_53a8c239834e0009"]
}
