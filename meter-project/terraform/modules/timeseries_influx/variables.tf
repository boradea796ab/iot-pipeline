variable "project_name" {
  description = "Project prefix used for resource naming."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the InfluxDB security group is created."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by Timestream for InfluxDB."
  type        = list(string)
}

variable "organization" {
  description = "InfluxDB organization name."
  type        = string
}

variable "bucket_name" {
  description = "InfluxDB bucket name."
  type        = string
}

variable "db_name" {
  description = "InfluxDB instance name."
  type        = string
}

variable "db_instance_type" {
  description = "Timestream for InfluxDB instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
}

variable "ingress_security_group_ids" {
  description = "Security groups allowed to connect to InfluxDB."
  type        = list(string)
  default     = []
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to connect to InfluxDB."
  type        = list(string)
  default     = []
}

variable "influxdb_port" {
  description = "InfluxDB port."
  type        = number
  default     = 8086
}

variable "admin_username" {
  description = "InfluxDB admin username."
  type        = string
  default     = "admin"
}

variable "admin_password_length" {
  description = "Length for generated InfluxDB admin password."
  type        = number
  default     = 20
}

variable "publish_admin_credentials_to_ssm" {
  description = "Whether to publish InfluxDB admin credentials to SSM Parameter Store."
  type        = bool
  default     = false
}

variable "admin_ssm_parameter_prefix" {
  description = "SSM parameter prefix for published admin credentials."
  type        = string
  default     = "/smart-meter/iot/influxdb/admin"
}
