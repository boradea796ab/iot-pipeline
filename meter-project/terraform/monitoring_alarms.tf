resource "aws_sns_topic" "iot_alarms" {
  name = "${var.resource_name_prefix}-iot-alarms"
}

resource "aws_cloudwatch_metric_alarm" "sqs_oldest_age_high" {
  alarm_name          = "${var.resource_name_prefix}-sqs-oldest-age-high"
  alarm_description   = "SQS backlog building up (oldest message age > threshold)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 60
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = module.sqs.sqs_name
  }

  alarm_actions = [aws_sns_topic.iot_alarms.arn]
  ok_actions    = [aws_sns_topic.iot_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.resource_name_prefix}-lambda-errors"
  alarm_description   = "Any ingestion Lambda errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.lambda.consumer_function_name
  }

  alarm_actions = [aws_sns_topic.iot_alarms.arn]
  ok_actions    = [aws_sns_topic.iot_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "dlq_lambda_errors" {
  alarm_name          = "${var.resource_name_prefix}-dlq-lambda-errors"
  alarm_description   = "Any DLQ processor Lambda errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.lambda.dlq_function_name
  }

  alarm_actions = [aws_sns_topic.iot_alarms.arn]
  ok_actions    = [aws_sns_topic.iot_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "${var.resource_name_prefix}-apigw-5xx"
  alarm_description   = "Any API Gateway 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = module.api_gateway.api_name
  }

  alarm_actions = [aws_sns_topic.iot_alarms.arn]
  ok_actions    = [aws_sns_topic.iot_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "${var.resource_name_prefix}-dynamodb-throttles"
  alarm_description   = "Any throttled requests on the idempotency table"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = module.idempotency_table.table_name
  }

  alarm_actions = [aws_sns_topic.iot_alarms.arn]
  ok_actions    = [aws_sns_topic.iot_alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.resource_name_prefix}-dlq-depth"
  alarm_description   = "DLQ has visible messages after retries"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = module.sqs.dlq_name
  }

  alarm_actions = [aws_sns_topic.iot_alarms.arn]
  ok_actions    = [aws_sns_topic.iot_alarms.arn]
}
