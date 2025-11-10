variable "table_name" {
  description = "Name of the DynamoDB table used for Lambda idempotency tracking"
  type        = string
}

variable "hash_key_name" {
  description = "Primary key attribute name for the idempotency table"
  type        = string
  default     = "message_id"
}

variable "ttl_attribute_name" {
  description = "Attribute name used for DynamoDB TTL"
  type        = string
  default     = "expires_at"
}
