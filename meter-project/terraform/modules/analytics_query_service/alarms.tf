resource "aws_cloudwatch_metric_alarm" "query_errors" {
  alarm_name          = "${var.project_name}-analytics-query-errors"
  namespace           = var.metrics_namespace
  metric_name         = "QueryError"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Analytics query API is returning repeated query errors."
}

resource "aws_cloudwatch_metric_alarm" "query_timeouts" {
  alarm_name          = "${var.project_name}-analytics-query-timeouts"
  namespace           = var.metrics_namespace
  metric_name         = "QueryTimeout"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Analytics query API is experiencing upstream query timeouts."
}
