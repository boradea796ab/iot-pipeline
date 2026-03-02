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

variable "influx_datasource_name" {
  description = "Display name for Grafana InfluxDB datasource."
  type        = string
  default     = "InfluxDB-Hot"
}

variable "influx_org" {
  description = "InfluxDB organization name for datasource provisioning payload."
  type        = string
  default     = ""
}

variable "influx_query_url" {
  description = "InfluxDB query URL for datasource provisioning payload."
  type        = string
  default     = ""
}

variable "influx_default_bucket" {
  description = "Default bucket for Grafana datasource provisioning payload."
  type        = string
  default     = ""
}
