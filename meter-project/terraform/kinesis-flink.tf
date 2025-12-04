# resource "aws_kinesisanalyticsv2_application" "flink_app" {
#   name        = "${var.project_name}-flink"
#   runtime_environment = "FLINK-1_18"   # choose the latest
#   service_execution_role = aws_iam_role.kda_role.arn

#   application_configuration {
#     application_code_configuration {
#       code_content {
#         s3_content_location {
#           bucket_arn = aws_s3_bucket.flink_code_bucket.arn
#           file_key   = "flink-app.jar"
#         }
#       }
#       code_content_type = "ZIPFILE"
#     }

#     # VPC config required so Flink can connect to InfluxDB
#     vpc_configuration {
#       subnet_ids         = values(aws_subnet.private)[*].id
#       security_group_ids = [aws_security_group.flink_sg.id]
#     }
#   }
# }

resource "aws_iam_role" "kda_role" {
  name = "${var.project_name}-kda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "kinesisanalytics.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "kda_policy" {
  name = "${var.project_name}-kda-policy"
  role = aws_iam_role.kda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ]
        Resource = aws_kinesis_stream.iot_telemetry.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "flink_sg" {
  name        = "${var.project_name}-flink-sg"
  description = "Security group for Kinesis Analytics Flink application"
  vpc_id      = aws_vpc.main.id

  # Outbound allowed (required for S3, Kinesis, STS, CloudWatch, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
    Type    = "kda-flink"
  }
}
