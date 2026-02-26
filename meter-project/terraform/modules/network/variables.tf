variable "aws_region" {
  description = "AWS region for regional resources like the S3 endpoint service name."
  type        = string
}

variable "project_name" {
  description = "Project prefix used for naming and tagging."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to name network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs."
  type        = list(string)
}
