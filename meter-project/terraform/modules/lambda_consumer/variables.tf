variable "project_name" {
  description = "Project prefix used for resource naming."
  type        = string
}

variable "aws_region" {
  description = "AWS region for regional ARNs."
  type        = string
}

variable "kinesis_stream_arn" {
  description = "Kinesis stream ARN consumed by the Lambda function."
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
  description = "Directory containing Lambda source code."
  type        = string
}

variable "lambda_zip_path" {
  description = "Path where the Lambda deployment zip is built."
  type        = string
}

variable "influxdb_write_url_ssm_parameter" {
  description = "SSM parameter name for InfluxDB write URL."
  type        = string
  default     = "/smart-meter/iot/influxdb/write-url"
}

variable "influxdb_token_ssm_parameter" {
  description = "SSM parameter name for InfluxDB token."
  type        = string
  default     = "/smart-meter/iot/influxdb/token"
}
