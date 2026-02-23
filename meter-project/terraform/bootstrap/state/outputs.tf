output "state_bucket_name" {
  description = "S3 bucket name for Terraform state."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN for Terraform state."
  value       = aws_s3_bucket.state.arn
}

output "dynamodb_lock_table_name" {
  description = "DynamoDB table name for Terraform state locking (if enabled)."
  value       = var.enable_dynamodb_lock_table ? aws_dynamodb_table.terraform_locks[0].name : null
}

output "backend_s3_example" {
  description = "Example backend config snippet for the main Terraform stack."
  value = var.enable_dynamodb_lock_table ? format(
    "terraform {\n  backend \"s3\" {\n    bucket         = \"%s\"\n    key            = \"envs/dev/terraform.tfstate\"\n    region         = \"%s\"\n    encrypt        = true\n    use_lockfile   = true\n    dynamodb_table = \"%s\"\n  }\n}\n",
    aws_s3_bucket.state.id,
    var.aws_region,
    aws_dynamodb_table.terraform_locks[0].name
    ) : format(
    "terraform {\n  backend \"s3\" {\n    bucket       = \"%s\"\n    key          = \"envs/dev/terraform.tfstate\"\n    region       = \"%s\"\n    encrypt      = true\n    use_lockfile = true\n  }\n}\n",
    aws_s3_bucket.state.id,
    var.aws_region
  )
}
