## Terraform usage

## Terraform quality gates

Baseline guardrails for this repository:

- Terraform/provider versions are pinned in `terraform/versions.tf`.
- Linting config lives at `terraform/.tflint.hcl`.
- Security scanning config lives at `terraform/.tfsec.yml`.
- Pre-commit hooks are defined in `.pre-commit-config.yaml`.

Run once from repo root:

```bash
pre-commit install
```

Run all checks manually:

```bash
pre-commit run --all-files
```

Always tell Terraform which AWS region to use so it talks to the same region where the IoT stack was provisioned. The IoT Core APIs that manage certificates/policy attachments are region-scoped, so running `terraform destroy` with the wrong region (for example defaulting to `us-east-1` while the certificate lives in `ap-northeast-1`) produces `InvalidRequestException: Invalid Target` errors while reading `aws_iot_policy_attachment` resources.

You can provide the region by:

- exporting an environment variable before running Terraform:

  ```bash
  export TF_VAR_aws_region=ap-northeast-1
  ```

- or creating a `terraform.tfvars` file in this directory:

  ```hcl
  aws_region = "ap-northeast-1"
  ```

Make sure the same value is used for every `terraform apply`/`destroy` so Terraform can read and delete the existing IoT resources without errors.

Below is a **clean, well-structured, production-quality `README.md`** for your project so far.
It captures **all major components**, including:

* IoT Core ingestion
* Kinesis Stream
* InfluxDB (Timestream for InfluxDB)
* Lambda consumer
* IAM + VPC requirements
* Network pitfalls and fixes

Use this as your repo’s main README.

---

# 📡 Smart Meter IoT Ingestion Pipeline

A fully serverless, streaming IoT data pipeline on AWS for smart-meter telemetry ingestion, real-time processing, and time-series storage.

This project shows how to build a modern, scalable ingestion system that supports **high-volume IoT workloads**, using:

* **AWS IoT Core → MQTT ingestion**
* **Kinesis Data Streams**
* **Amazon Timestream for InfluxDB (Managed InfluxDB)**
* **AWS Lambda Kinesis consumer**
* **Terraform IaC**
* **VPC networking with private subnets + S3 VPC endpoint**

---

# 🏗 Architecture (Phase 1)

```
IoT Simulator (paho-mqtt)
     |
     v
AWS IoT Core → IoT Rules Engine
     |                    |
     | MQTT JSON          | (optional parallel writes)
     v                    v
Kinesis Data Stream    Timestream for InfluxDB (future)
     |
     v
AWS Lambda (Kinesis trigger)
     |
     v
InfluxDB (Timestream for InfluxDB)
```

---

# 🧩 Components

## 1. AWS IoT Core Setup

Terraform provisions:

### ✔ `aws_iot_thing`

Each simulated device registers as an IoT “Thing.”

### ✔ X.509 certificate generation

Terraform outputs:

* device certificate
* private key
* public key

Stored locally under `certs/`.

### ✔ IoT Policy

Allows publish to topic:

```
meters/<meter_id>/readings
```

### ✔ IoT Rule → Kinesis

Rule forwards MQTT JSON payloads into a Kinesis Data Stream:

```sql
SELECT * 
FROM 'meters/+/readings'
```

---

## 2. IoT Device Simulator (Python)

A small Python script using `paho-mqtt` publishes sample meter readings:

```
{
  "meter_id": "meter-123",
  "ts": 1715093392,
  "kWh": 1.42,
  "voltage": 230.1,
  "current": 8.2,
  "status": "OK"
}
```

MQTT endpoint = IoT Core’s ATS endpoint (Terraform output).
Certificates loaded from `certs/`.

---

## 3. Kinesis Data Stream

Terraform creates:

* 1× Kinesis Stream
* Shard count configurable
* IAM policy for IoT Core rule to put records into stream

This is the main ingestion buffer decoupling IoT throughput from downstream processing.

---

## 4. InfluxDB (Amazon Timestream for InfluxDB)

Terraform provisions:

* **db.influx.medium** instance
* private VPC subnet placement
* SG inbound rules from Lambda function
* Alphanumeric-only admin password
* Network access restricted to VPC only

### InfluxDB token creation (CloudShell setup)

To access influxDB correctly via cloudshell, it is necessary to first craete a cloudshell environment with the same VPC/subnet as the influxDB instance. 

```bash
# 0) Set values from Terraform outputs/state
export INFLUX_HOST_URL="https://<YOUR_INFLUX_ENDPOINT>:8086"
export INFLUX_ORG="VCC"
export INFLUX_BUCKET="smart-meter-iot-influxdb-bucket"

# 1) Create admin config (prompts for username/password)
# Username is "admin", password is the Terraform-generated master password.
influx config create \
  --config-name smart-meter-admin \
  --host-url "$INFLUX_HOST_URL" \
  --org "$INFLUX_ORG" \
  --username-password \
  --active

# 2) Activate config explicitly (if multiple configs exist)
influx config set -n smart-meter-iot-influxdb --active

# 3) Verify access and list buckets
influx bucket list

# 4) Capture the target bucket ID
BUCKET_ID=$(influx bucket list --name "$INFLUX_BUCKET" --json | jq -r '.[0].id')
echo "Bucket ID: $BUCKET_ID"

# 5) Create a token scoped to this bucket (read + write)
influx auth create \
  --description "lambda-rw-$INFLUX_BUCKET" \
  --org "$INFLUX_ORG" \
  --read-bucket "$BUCKET_ID" \
  --write-bucket "$BUCKET_ID"
```

Notes:
- `influx auth create` prints the token value once. Store it immediately (for example in SSM Parameter Store).
- If `jq` is unavailable in CloudShell, copy the bucket ID manually from `influx bucket list`.

### Store InfluxDB secrets in SSM Parameter Store

Keep the Lambda environment free of hardcoded secrets by writing them to SSM (you run these commands):

```bash
aws ssm put-parameter --name "/smart-meter/iot/influxdb/write-url" --type "SecureString" --value "<YOUR_INFLUX_WRITE_URL>" --overwrite --region ap-northeast-1
aws ssm put-parameter --name "/smart-meter/iot/influxdb/token" --type "SecureString" --value "<YOUR_INFLUX_TOKEN>" --overwrite --region ap-northeast-1
aws ssm get-parameter --name "/smart-meter/iot/influxdb/write-url" --with-decryption --region ap-northeast-1
```

Terraform reads these parameters and injects them into the Lambda environment automatically.

### Lambda payload test

To verify the Lambda parses Kinesis records correctly, invoke it with a sample event like:

```json
{
  "Records": [
    {
      "kinesis": {
        "partitionKey": "meter-001",
        "data": "eyJtZXRlcklkIjogIm1ldGVyLTAwMSIsICJ0cyI6IDE3MzYyMjU3OTAwMDAsICJrV2giOiAxMi40NSwgInZvbHRhZ2UiOiAyMjAuMywgImN1cnJlbnQiOiAxLjg1LCAic3RhdHVzIjogIm9rIn0=",
        "approximateArrivalTimestamp": 1736225790
      },
      "eventSource": "aws:kinesis",
      "eventID": "shardId-000000000000:1234567890",
      "eventVersion": "1.0",
      "eventName": "aws:kinesis:record",
      "awsRegion": "ap-northeast-1",
      "eventSourceARN": "arn:aws:kinesis:ap-northeast-1:123456789012:stream/iot-telemetry"
    }
  ]
}
```

The `data` field is base64-encoded; decoding it reveals the JSON the Lambda actually writes to InfluxDB.

Lambda writes meter readings into InfluxDB using Influx Line Protocol.

---

# ⚙️ VPC + Networking

A custom VPC is created:

### ✔ CIDR

```
10.0.0.0/16
```

### ✔ Private subnets

Terraform constructs subnets dynamically using `private_subnet_cidrs`, mapped automatically across availability zones.

### ✔ Public subnets (optional)

Used for NAT Gateway placement.

### ✔ NAT Gateway

Allows private subnets to reach AWS APIs (Kinesis, S3, CloudWatch).

### ✔ S3 VPC Endpoint

Required so private workloads (and Lambda if packaged or logging to S3) can reach S3 without internet.

```hcl
resource "aws_vpc_endpoint" "s3" {
   service_name      = "com.amazonaws.<region>.s3"
   vpc_endpoint_type = "Gateway"
   route_table_ids   = [aws_route_table.private.id]
}
```

### ✔ SG for Lambda

---

# 🎯 Deployment Summary

### 1. Terraform creates everything end-to-end:

* IoT Core + certs
* IoT Policy + Rule
* Kinesis Stream
* InfluxDB
* VPC + subnets + route tables + NAT + endpoints
* IAM roles + policies
* Lambda consumer triggered by Kinesis
* SSM parameters for Influx URL/token (read at deploy time)
* S3 bucket (if you package artifacts there)

---

# 🧪 Next Steps (Phase 2)

* Enhance Lambda parsing/validation
* Expand metrics/observability (CloudWatch, alarms)
* Build Grafana dashboards
* Add error handling (DLQ Kinesis stream)

---

# ✔ Conclusion

This project now successfully covers:

* IoT → MQTT ingestion
* Stream ingestion buffer (Kinesis)
* Private time-series storage (InfluxDB)
* End-to-end VPC isolation
* Lambda-based processing path (Kinesis → InfluxDB)

This is a **professional-grade IoT ingestion pipeline**, matching real industry patterns used by smart-meter / smart-grid companies.

---
