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
