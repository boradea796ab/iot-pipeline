# Terraform Setup and Developer Runbook

This file contains the practical commands used to initialize, deploy, test, and troubleshoot the Terraform-managed IoT stack.

## 1. Prerequisites
- Terraform installed (version compatible with `versions.tf`)
- AWS credentials configured
- Region set consistently (example: `ap-northeast-1`)
- Tools: `jq`, `curl`, `python3`, `pipx` (for `awscurl`)

Set region for Terraform:
```bash
export TF_VAR_aws_region=ap-northeast-1
```

## 2. Quality Gates
From repo root:
```bash
pre-commit install
pre-commit run --all-files
```

## 3. Bootstrap Remote State (one-time)
```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/terraform/bootstrap/state
terraform init
terraform plan
terraform apply
```

Capture outputs:
```bash
terraform output -raw state_bucket_name
terraform output -raw dynamodb_lock_table_name
```

## 4. Configure Environment Backend
```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/terraform
ENV=prod
cp "envs/${ENV}/backend.hcl.example" "envs/${ENV}/backend.hcl"
# edit envs/${ENV}/backend.hcl with real bucket/table/region/key
```

Initialize with explicit backend:
```bash
terraform init -reconfigure -backend-config="envs/${ENV}/backend.hcl"
```

## 5. Standard Plan/Apply Flow
```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/terraform
ENV=prod
terraform init -backend-config="envs/${ENV}/backend.hcl"
terraform fmt -recursive
terraform plan \
  -var-file="envs/common.tfvars" \
  -var-file="envs/${ENV}/terraform.tfvars"
terraform apply \
  -var-file="envs/common.tfvars" \
  -var-file="envs/${ENV}/terraform.tfvars"
```

## 6. Analytics API Security Quick Check
Verify route auth types are IAM:
```bash
aws apigatewayv2 get-routes --api-id 55ojneksi9 \
  --query 'Items[].{RouteKey:RouteKey,Auth:AuthorizationType}' \
  --output table
```

## 7. Install and Use `awscurl`
Install:
```bash
sudo apt-get update
sudo apt-get install -y pipx
pipx ensurepath
source ~/.bashrc
pipx install awscurl
```

Health check:
```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/terraform
awscurl --service execute-api --region "${TF_VAR_aws_region:-ap-northeast-1}" \
  "$(terraform output -raw analytics_query_health_url)"
```

Timeseries query:
```bash
awscurl --service execute-api --region "${TF_VAR_aws_region:-ap-northeast-1}" \
  -X POST "$(terraform output -raw analytics_query_timeseries_url)" \
  -H "Content-Type: application/json" \
  -d '{
    "query_name":"timeseries",
    "time_range":{"from":"2026-03-01T00:00:00Z","to":"2026-03-03T23:59:59Z"},
    "filters":{"meter_ids":["meter-001"]},
    "granularity":"1m",
    "timezone":"UTC",
    "limit":500
  }'
```

Statistics query:
```bash
awscurl --service execute-api --region "${TF_VAR_aws_region:-ap-northeast-1}" \
  -X POST "$(terraform output -raw analytics_query_statistics_url)" \
  -H "Content-Type: application/json" \
  -d '{
    "query_name":"statistics",
    "time_range":{"from":"2026-03-01T00:00:00Z","to":"2026-03-03T23:59:59Z"},
    "filters":{"meter_ids":["meter-001"]},
    "granularity":"1m",
    "timezone":"UTC",
    "limit":500
  }'
```

## 8. Run Simulator for Fresh Data
```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/iot-simulator
export IOT_ENDPOINT="$(cd ../terraform && terraform output -raw iot_endpoint)"
python3 -m meter_sim.main \
  --endpoint "$IOT_ENDPOINT" \
  --meters 100 \
  --meter-prefix meter \
  --start-index 1 \
  --messages-per-sec 50 \
  --duration-sec 2400 \
  --qos 1
```

## 9. Hot/Cold Operational Commands
### Create/update downsampling task
```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/terraform
export INFLUX_HOST="https://<influx-endpoint>:8086"
export INFLUX_TOKEN="<admin-or-task-token>"
export INFLUX_ORG="<org>"
export INFLUX_HOT_BUCKET="<hot-bucket>"
export INFLUX_COLD_BUCKET="<cold-bucket>"
./scripts/create_influx_downsampling_task.sh
```

### Validate buckets/tasks
```bash
influx bucket list --host "$INFLUX_HOST" --org "$INFLUX_ORG" --token "$INFLUX_TOKEN"
influx task list --host "$INFLUX_HOST" --org "$INFLUX_ORG" --token "$INFLUX_TOKEN"
```

## 10. Common Troubleshooting
### A. Terraform planning wrong environment resources
Symptoms: plan proposes renaming/replacing many core resources.
Fix:
```bash
ENV=prod
terraform init -reconfigure -backend-config="envs/${ENV}/backend.hcl"
terraform plan -var-file="envs/common.tfvars" -var-file="envs/${ENV}/terraform.tfvars"
```

### B. Missing SSM params for query API
Create expected params:
```bash
aws ssm put-parameter --name /smart-meter/iot/influxdb/query-url --type SecureString --overwrite --value "https://<endpoint>:8086/api/v2/query" --region ap-northeast-1
aws ssm put-parameter --name /smart-meter/iot/influxdb/read-token --type SecureString --overwrite --value "<read-token>" --region ap-northeast-1
```

### C. Zero rows from API
Check:
1. meter filter matches produced IDs (`meter-001` vs `sim-meter-001`)
2. range overlaps ingestion timestamps
3. cold bucket/task exists for cold-path queries
4. query URL points to `/api/v2/query` (not write URL)

### D. Lambda packaging drift from `__pycache__`
```bash
find lambda_analytics_source -type d -name "__pycache__" -prune -exec rm -rf {} +
find lambda_analytics_source -type f -name "*.pyc" -delete
```

## 11. Useful Logs
Query API logs:
```bash
aws logs tail "/aws/lambda/$(terraform output -raw analytics_query_lambda_function_name)" --follow
```

Ingestion Lambda logs (name may vary by project prefix):
```bash
aws logs tail "/aws/lambda/smart-meter-iot-kinesis-to-influx" --follow
```
