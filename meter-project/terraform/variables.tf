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
