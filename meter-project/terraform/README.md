# Component Test Guide

## Fetch SQS Queue URL
- Description: Retrieve the queue URL from Terraform outputs for reuse in CLI commands.
- Command:
```bash
terraform output -raw sqs_url
```
- Expected output: Full HTTPS SQS queue URL (for example, `https://sqs.ap-northeast-1.amazonaws.com/...`).

## Send Test Message To SQS
- Description: Push a simple payload directly to the queue to confirm write access.
- Command:
```bash
aws sqs send-message \
  --queue-url "$(terraform output -raw sqs_url)" \
  --message-body '{"ping":1}'
```
- Expected output: JSON response containing `MessageId` and the message digest fields.

## Check API Health Endpoint
- Description: Hit the `/health` resource to confirm the deployed API stage responds.
- Command:
```bash
curl "$(terraform output -raw api_base_url)prod/health"
```
- Expected output:
  ```json
  {
    "status": "ok",
    "message": "Hello from API Gateway!"
  }
  ```

## Receive Message From SQS
- Description: Pull the most recent message to verify it landed on the queue.
- Command:
```bash
aws sqs receive-message \
  --queue-url "$(terraform output -raw sqs_url)"
```
- Expected output: JSON payload with a `Messages` array describing the queued message.

## Invoke API Gateway → SQS
- Description: Call the `/ingest` endpoint through API Gateway to ensure the full path writes to SQS.
- Command:
```bash
curl -X POST "$(terraform output -raw api_base_url)prod/ingest" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $(terraform output -raw api_key_device_m1)" \
  -d '{"meter_id":"M001","reading":33.45,"timestamp":"2025-10-19T12:00:00Z"}'
```
- Expected output: HTTP 200 response with JSON containing the SQS `messageId`.

## Smoke Test Message
- Description: Optional extra message send to exercise the queue with a different payload.
- Command:
```bash
aws sqs send-message \
  --queue-url "$(terraform output -raw sqs_url)" \
  --message-body '{"smoke":"test"}'
```
- Expected output: JSON response including a unique `MessageId`.

## Tail Lambda Consumer Logs
- Description: Stream the Lambda consumer logs to verify the downstream processor handles the messages.
- Command:
```bash
aws logs tail /aws/lambda/iot-consumer --follow
```
- Expected output: Continuous log stream showing message receipt and processing events.

## Notes
- Redeploy the API (`terraform apply`) whenever you change integrations or API key bindings so the stage picks up the latest configuration.
