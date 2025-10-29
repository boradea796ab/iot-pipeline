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
