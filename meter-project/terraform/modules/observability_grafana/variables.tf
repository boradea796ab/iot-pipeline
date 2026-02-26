variable "project_name" {
  description = "Project prefix used for naming and tags."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for shared resource names."
  type        = string
}

variable "grafana_admin_role_arns" {
  description = "IAM role ARNs that should be Grafana workspace admins."
  type        = list(string)
  default     = []
}
