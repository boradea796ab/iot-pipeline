variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks used to create private subnets"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDR blocks are required."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks used to create public subnets"
  type        = list(string)
  default     = []
}

variable "name_prefix" {
  description = "Prefix applied to the Name tag of networking resources"
  type        = string
  default     = "network"
}

variable "tags" {
  description = "Additional tags applied to networking resources"
  type        = map(string)
  default     = {}
}
