resource "aws_s3_bucket" "flink_code_bucket" {
  bucket = "${var.project_name}-flink-code-${random_id.suffix.hex}"

  force_destroy = true

  tags = {
    Project = var.project_name
    Type    = "flink-code"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "flink_code_bucket_versioning" {
  bucket = aws_s3_bucket.flink_code_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flink_code_bucket_encryption" {
  bucket = aws_s3_bucket.flink_code_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
