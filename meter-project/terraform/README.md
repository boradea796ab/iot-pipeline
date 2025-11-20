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
- Description: Stream the Lambda consumer logs to verify the downstream processor handles the messages and idempotency skips.
- Command:
```bash
aws logs tail /aws/lambda/iot-consumer --region ap-northeast-1 --follow
```
- Expected output: Continuous log stream showing message receipt, success, retries, and `Skipping message ... idempotency record already exists` when duplicates are detected.

## Idempotency Table
- Description: DynamoDB table that stores processed message IDs, payloads, and TTL markers for replay.
- Commands:
```bash
terraform output -raw idempotency_table_name
aws dynamodb scan --table-name "$(terraform output -raw idempotency_table_name)" --select "COUNT"
```
- Expected output: Table name and current item count. Each item includes `message_id`, `status`, `processed_at`, optional `expires_at`, and the original payload.

## DLQ & Replay Workflow
- Description: End-to-end test for SQS retries, DLQ handling, and replaying successful payloads.
- Steps:
  1. Export environment variables:
     ```bash
     export API_URL=$(cd terraform && terraform output -raw api_base_url)
     export IDEMPOTENCY_TABLE=$(cd terraform && terraform output -raw idempotency_table_name)
     ```
  2. Run the simulator to stress the API:
     ```bash
     python3 scripts/lambda_dlq_test.py
     ```
  3. Replay the last 50 successful payloads (throttled to avoid API Gateway limits):
     ```bash
     python3 scripts/replay_recent_messages.py --limit 50 --sleep 0.5
     # or chain both:
     ./scripts/run_sim_and_replay.sh --limit 50 --sleep 0.5
     ```
  4. Observe CloudWatch logs for retries and idempotency skips.
- Notes:
  - The `iot-dlq-processor` Lambda now runs the same business logic as the primary consumer but operates directly on the DLQ. If it succeeds, the message is marked `PROCESSED` in DynamoDB; if it fails, the record stays in the DLQ for manual review.
- Expected result: New items in DynamoDB for each processed message (with payload + TTL), consistent DLQ redrive behavior, and deterministic replays without duplicate processing.

## Sample Signed Ingest Request
- Description: Example request that includes the required HMAC headers expected by the custom Lambda authorizer.
- Command:
```bash
API_URL="$(terraform output -raw api_base_url)"
DEVICE_ID="M001"
TIMESTAMP="20250101T120000Z"
PAYLOAD='{"meter_id":"M001","timestamp":"2025-01-01T12:00:00Z","reading_value":42.17,"unit":"kWh","meter_type":"SMART_METER"}'
SIGNATURE="$(python3 - <<'PY'
import base64, hashlib, hmac, os
device_id = os.getenv("DEVICE_ID")
timestamp = os.getenv("TIMESTAMP")
secret = "supersecret-key-m001"  # replace with secure value stored in SSM
canonical = f"{device_id}:{timestamp}"
digest = hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).digest()
print(base64.b64encode(digest).decode())
PY
)"

curl -X POST "${API_URL}prod/ingest" \
  -H "Content-Type: application/json" \
  -H "x-device-id: ${DEVICE_ID}" \
  -H "x-timestamp: ${TIMESTAMP}" \
  -H "x-signature: ${SIGNATURE}" \
  -d "${PAYLOAD}"
```
- Expected output: HTTP 200 response with the SQS `messageId`. Update the secret value and payload to match your device configuration.

## Inspect Device Secrets in AWS
- Description: Verify that the device HMAC secrets are stored in AWS Systems Manager Parameter Store.
- Command:
```bash
aws ssm get-parameter \
  --name "/iot/device/M001/secret" \
  --with-decryption
```
- Expected output: JSON containing the decrypted secret value (requires IAM permission to read the parameter).

## Notes
- Redeploy the API (`terraform apply`) whenever you change integrations or API key bindings so the stage picks up the latest configuration.

## Reference for APIGateway SQS integration

- AWS Documentation:https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/integrate-amazon-api-gateway-with-amazon-sqs-to-handle-asynchronous-rest-apis.html


## Verify VPC Networking
- Description: Confirm the Terraform-created VPC, subnets, and routing exist in AWS before wiring Lambda/RDS/DynamoDB.
- Commands:
```bash
cd terraform
VPC_ID=$(terraform output -raw vpc_id)
PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids | jq -r '.[]')
PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids | jq -r '.[]')

aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,DnsHostnames:EnableDnsHostnames}"

aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNETS $PUBLIC_SUBNETS \
  --query "Subnets[].{SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,Public:MapPublicIpOnLaunch}"

aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[].{RouteTableId:RouteTableId,Routes:Routes}"
```
- Expected output: One VPC with the configured CIDR + DNS hostnames enabled, at least two private subnets and two public subnets spread across AZs (public ones show `MapPublicIpOnLaunch=true`), and a public route table containing a `0.0.0.0/0` route targeting the created internet gateway.

## Commit 2 – Aurora Networking + Cluster
- Description: This commit stood up the Aurora Serverless v2 data plane without touching the Lambda code path: Lambda and Aurora security groups, a DB subnet group mapped to the private subnets, Secrets Manager credentials, and the Aurora cluster/instance itself. Use the following CLI checks (after `terraform apply`) to verify everything before continuing to later commits.
- Commands:
```bash
cd terraform
CLUSTER_ID=$(terraform output -raw aurora_cluster_id)
LAMBDA_SG=$(terraform output -raw lambda_security_group_id)
AURORA_SG=$(terraform output -raw aurora_security_group_id)
SECRET_ARN=$(terraform output -raw aurora_secret_arn)
DB_SUBNET_GROUP="${TF_VAR_resource_name_prefix:-meter}-aurora-subnets"

aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER_ID" \
  --query "DBClusters[].{Status:Status,Endpoint:Endpoint,ReaderEndpoint:ReaderEndpoint,Engine:Engine,Capacity:ServerlessV2ScalingConfiguration}"

aws ec2 describe-security-groups --group-ids "$AURORA_SG" \
  --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}"

aws ec2 describe-security-groups --group-ids "$LAMBDA_SG" \
  --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}"

aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET_GROUP" \
  --query "DBSubnetGroups[].{Name:DBSubnetGroupName,Status:SubnetGroupStatus,Subnets:Subnets[].SubnetIdentifier}"

aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" \
  --query "{ARN:ARN,Created:CreatedDate}"
```
- Expected output: The Aurora cluster shows `available` status with the writer/reader endpoints and your Serverless v2 scaling window; the Aurora SG displays a single ingress rule referencing the Lambda SG on the DB port with unrestricted egress; the Lambda SG reports no ingress rules and the default `0.0.0.0/0` egress rule; the DB subnet group lists the private subnet IDs wired in Commit 1; and Secrets Manager returns the credential secret metadata (optionally include `--query SecretString` if you need to inspect the JSON).

## Commit 3 – DynamoDB Idempotency + VPC Endpoints + IAM Prep
- Description: This commit kept the existing DynamoDB idempotency table but added the networking dependencies Lambda will need once it runs inside the VPC: a Gateway endpoint for DynamoDB, Interface endpoints for SQS/Logs/STS/Secrets Manager, and a dedicated endpoint security group that only trusts the Lambda security group on TCP/443. Lambda IAM already grants SQS/DynamoDB/CloudWatch Logs access, so no policy change was required.
- Commands:
```bash
cd terraform
VPC_ID=$(terraform output -raw vpc_id)
DDB_ENDPOINT=$(terraform output -raw dynamodb_vpc_endpoint_id)
INTERFACE_ENDPOINTS=$(terraform output -json interface_vpc_endpoint_ids | jq -r '.[]')
VPCE_SG=$(terraform output -raw vpc_endpoint_security_group_id)
IDEMPOTENCY_TABLE=$(terraform output -raw idempotency_table_name)

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$DDB_ENDPOINT" \
  --query "VpcEndpoints[].{Service:ServiceName,Type:VpcEndpointType,RouteTables:RouteTableIds}"

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $INTERFACE_ENDPOINTS \
  --query "VpcEndpoints[].{Service:ServiceName,Subnets:SubnetIds,SecurityGroups:Groups[].GroupId}"

aws ec2 describe-security-groups --group-ids "$VPCE_SG" \
  --query "SecurityGroups[].{Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}"

aws dynamodb describe-table --table-name "$IDEMPOTENCY_TABLE" \
  --query "{TableName:Table.TableName,BillingMode:Table.BillingModeSummary.BillingMode}"
```
- Expected output: The DynamoDB Gateway endpoint shows type `Gateway` with your private route table ID; the Interface endpoints list the private subnet IDs and the endpoint SG; the endpoint security group contains a single ingress rule referencing the Lambda SG on port 443 plus the default allow-all egress; and DynamoDB reports the idempotency table in `PAY_PER_REQUEST` mode, confirming there were no schema changes.
