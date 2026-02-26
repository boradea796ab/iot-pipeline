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
