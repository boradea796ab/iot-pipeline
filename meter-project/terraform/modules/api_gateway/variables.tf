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
