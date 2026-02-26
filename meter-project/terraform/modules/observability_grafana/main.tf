locals {
  grafana_name = "${var.name_prefix}-grafana"
}

resource "aws_iam_role" "grafana_service_role" {
  name = "${var.name_prefix}-grafana-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "grafana.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "grafana_cloudwatch_read" {
  name = "${var.name_prefix}-grafana-cloudwatch-read"
  role = aws_iam_role.grafana_service_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_grafana_workspace" "this" {
  name                     = local.grafana_name
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"

  data_sources = ["CLOUDWATCH"]
  role_arn     = aws_iam_role.grafana_service_role.arn
}
