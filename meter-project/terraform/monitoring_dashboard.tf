locals {
  iot_dashboard = {
    api_gateway_name  = module.api_gateway.api_name
    ingestion_queue   = module.sqs.sqs_name
    dlq_queue         = module.sqs.dlq_name
    lambda_function   = module.lambda.consumer_function_name
    dlq_lambda        = module.lambda.dlq_function_name
    dynamodb_table    = module.idempotency_table.table_name
    aurora_identifier = module.aurora.aurora_cluster_id
    rds_proxy_name    = module.aurora.db_proxy_name
  }
}

resource "aws_cloudwatch_dashboard" "iot_pipeline" {
  dashboard_name = "${var.resource_name_prefix}-iot-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "API Gateway - Requests & Errors"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", local.iot_dashboard.api_gateway_name, { stat = "Sum", label = "Requests" }],
            [".", "5XXError", ".", ".", { stat = "Sum", label = "5XX" }],
            [".", "4XXError", ".", ".", { stat = "Sum", label = "4XX" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "SQS - Depth & Oldest Message Age"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", local.iot_dashboard.ingestion_queue, { stat = "Sum", label = "Visible" }],
            [".", "ApproximateNumberOfMessagesNotVisible", ".", ".", { stat = "Sum", label = "In-flight" }],
            [".", "ApproximateAgeOfOldestMessage", ".", ".", { stat = "Maximum", label = "Oldest Age (s)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "DLQ - Depth"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", local.iot_dashboard.dlq_queue, { stat = "Sum", label = "DLQ Visible" }]
          ]
          view   = "singleValue"
          region = var.region
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title = "Lambda - Invocations, Errors, Duration"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", local.iot_dashboard.lambda_function, { stat = "Sum", label = "Invocations" }],
            [".", "Errors", ".", ".", { stat = "Sum", label = "Errors" }],
            [".", "Throttles", ".", ".", { stat = "Sum", label = "Throttles" }],
            [".", "Duration", ".", ".", { stat = "Average", label = "Duration (ms)", yAxis = "right" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title = "DynamoDB - Capacity & Throttles"
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", local.iot_dashboard.dynamodb_table, { stat = "Sum", label = "Reads" }],
            [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum", label = "Writes" }],
            [".", "ThrottledRequests", ".", ".", { stat = "Sum", label = "Throttles" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title = "DynamoDB - Latency & Errors"
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", local.iot_dashboard.dynamodb_table, { stat = "Average", label = "Latency (ms)" }],
            [".", "SystemErrors", ".", ".", { stat = "Sum", label = "System Errors" }],
            [".", "UserErrors", ".", ".", { stat = "Sum", label = "User Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title = "DLQ Lambda - Invocations, Errors, Duration"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", local.iot_dashboard.dlq_lambda, { stat = "Sum", label = "Invocations" }],
            [".", "Errors", ".", ".", { stat = "Sum", label = "Errors" }],
            [".", "Throttles", ".", ".", { stat = "Sum", label = "Throttles" }],
            [".", "Duration", ".", ".", { stat = "Average", label = "Duration (ms)", yAxis = "right" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 12
        height = 6
        properties = {
          title = "RDS - CPU & Memory"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", local.iot_dashboard.aurora_identifier, { stat = "Average", label = "CPU (%)" }],
            [".", "FreeableMemory", ".", ".", { stat = "Average", label = "Free Mem (MB)", yAxis = "right" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 24
        width  = 12
        height = 6
        properties = {
          title = "RDS Connections"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", local.iot_dashboard.aurora_identifier, { stat = "Maximum", label = "Cluster Connections" }],
            ["AWS/RDS", "ClientConnections", "DBProxyName", local.iot_dashboard.rds_proxy_name, { stat = "Average", label = "Proxy Clients" }],
            ["AWS/RDS", "DatabaseConnections", "DBProxyName", local.iot_dashboard.rds_proxy_name, { stat = "Average", label = "Proxy DB Sessions" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          period  = 60
        }
      }
    ]
  })
}
