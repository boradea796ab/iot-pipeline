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
  default = []
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
