
# Log group for API Gateway access & execution logs
resource "aws_cloudwatch_log_group" "apigw_logs" {
  name              = "/aws/apigateway/iot-ingestion"
  retention_in_days = 7
}