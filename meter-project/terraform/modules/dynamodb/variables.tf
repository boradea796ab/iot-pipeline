variable "table_name" {
  description = "Name of the DynamoDB table used for Lambda idempotency tracking"
  type        = string
}

variable "hash_key_name" {
  description = "Primary key attribute name for the idempotency table"
  type        = string
  default     = "message_id"
}
