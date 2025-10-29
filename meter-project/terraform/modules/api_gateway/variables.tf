variable "api_name" {
  type = string
}
variable "description" {
  type    = string
  default = "Minimal mock API for health check"
}
variable "stage_name" {
  type    = string
  default = "prod"
}

variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "queue_name" {}

variable "force_redeploy_token" {
  type    = string
  default = "deploy-apigw-logging"
}

variable "device_secret_parameter_prefix" {
  description = "Optional SSM parameter path prefix for device HMAC secrets (e.g. /meter/devices)"
  type        = string
  default     = "/iot/device"
}

variable "device_secret_parameters" {
  description = "Map of device IDs to full SSM parameter names containing their HMAC secrets"
  type        = map(string)
  default     = {}
}
