variable "api_name" {
  type        = string
}
variable "description" {
  type        = string
  default     = "Minimal mock API for health check"
}
variable "stage_name" {
  type        = string
  default     = "prod"
}

variable "region" {
  type = string
  default = "ap-northeast-1"
}

variable "queue_name" {}
