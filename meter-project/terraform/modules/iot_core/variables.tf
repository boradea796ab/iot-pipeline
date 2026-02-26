variable "project_name" {
  description = "Project prefix used for resource naming."
  type        = string
}

variable "sim_meter_thing_name" {
  description = "IoT thing name for the simulator meter."
  type        = string
}

variable "certs_output_dir" {
  description = "Directory where generated simulator certificates and keys are written."
  type        = string
}

variable "kinesis_stream_name" {
  description = "Kinesis stream name used by the IoT rule action."
  type        = string
}

variable "kinesis_stream_arn" {
  description = "Kinesis stream ARN used by IoT rules IAM policy."
  type        = string
}
