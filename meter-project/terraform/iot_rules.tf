# Role that AWS IoT assumes to write to Kinesis + Timestream
resource "aws_iam_role" "iot_rules_role" {
  name = "${var.project_name}-iot-rules-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_rules_policy" {
  name = "${var.project_name}-iot-rules-policy"
  role = aws_iam_role.iot_rules_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow writing to the Kinesis stream
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.iot_telemetry.arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "meters_to_kinesis" {
  name        = "${var.project_name}-meters-rule"
  enabled     = true
  sql         = "SELECT * FROM 'meters/+/readings'"
  sql_version = "2016-03-23"

  kinesis {
    role_arn    = aws_iam_role.iot_rules_role.arn
    stream_name = aws_kinesis_stream.iot_telemetry.name
    partition_key = "${topic()}"
  }
}
