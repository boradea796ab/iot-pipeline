variable "sqs_arn" {
  type = string
}

variable "dlq_sqs_arn" {
  type = string
}

variable "dlq_id" {
  type = string
}

variable "idempotency_table" {
  description = "DynamoDB table used to track processed messages"
  type        = string
}

variable "idempotency_table_arn" {
  description = "ARN of the DynamoDB table used for idempotency tracking"
  type        = string
}
