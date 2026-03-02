# Analytics Query Backend Testing Guide

This guide covers quick end-to-end validation of the analytics query API with signed `awscurl` calls.

## 1. Install `awscurl` (via `pipx`)

```bash
sudo apt-get update
sudo apt-get install -y pipx
pipx ensurepath
source ~/.bashrc
pipx install awscurl
awscurl --help
```

## 2. Get API URLs

```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/terraform
export AWS_REGION="${TF_VAR_aws_region:-ap-northeast-1}"
export HEALTH_URL="$(terraform output -raw analytics_query_health_url)"
export TS_URL="$(terraform output -raw analytics_query_timeseries_url)"
export STATS_URL="$(terraform output -raw analytics_query_statistics_url)"
```

## 3. (Optional) Re-run simulator for fresh data

Use one fixed meter ID so filtering is easy:

```bash
cd /home/ubuntu/cmr-oms-xp/v2/meter-project/iot-simulator
export IOT_ENDPOINT="$(cd ../terraform && terraform output -raw iot_endpoint)"
python3 -m meter_sim.main \
  --endpoint "$IOT_ENDPOINT" \
  --meters 1 \
  --single-meter-id meter-001 \
  --messages-per-sec 10 \
  --duration-sec 180 \
  --qos 1
```

## 4. Endpoint Tests

### 4.1 Health endpoint

```bash
awscurl --service execute-api --region "$AWS_REGION" "$HEALTH_URL"
```

### 4.2 Timeseries endpoint (hot bucket path)

Hot path uses recent range with high granularity (`1m` or `5m`):

```bash
awscurl --service execute-api --region "$AWS_REGION" \
  -X POST "$TS_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query_name":"timeseries",
    "time_range":{"from":"2026-03-02T00:00:00Z","to":"2026-03-02T23:59:59Z"},
    "filters":{"meter_ids":["meter-001"]},
    "granularity":"1m",
    "timezone":"UTC",
    "limit":500
  }'
```

Expected: `meta.sources` includes `hot`.

### 4.3 Timeseries endpoint (cold bucket path)

Cold path uses historical range older than hot retention (default 7 days), or coarse granularity routing:

```bash
awscurl --service execute-api --region "$AWS_REGION" \
  -X POST "$TS_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query_name":"timeseries",
    "time_range":{"from":"2026-02-21T00:00:00Z","to":"2026-02-21T23:59:59Z"},
    "filters":{"meter_ids":["meter-001"]},
    "granularity":"15m",
    "timezone":"UTC",
    "limit":1000
  }'
```

Expected: `meta.sources` includes `cold` if cold bucket has data.

### 4.4 Statistics endpoint (hot-friendly test)

```bash
awscurl --service execute-api --region "$AWS_REGION" \
  -X POST "$STATS_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query_name":"statistics",
    "time_range":{"from":"2026-03-02T00:00:00Z","to":"2026-03-02T23:59:59Z"},
    "filters":{"meter_ids":["meter-001"]},
    "granularity":"1m",
    "timezone":"UTC",
    "limit":500
  }'
```

Expected: `stats.kWh`, `stats.voltage`, and `stats.current` objects with `min/max/avg/p95/count`.

### 4.5 Statistics endpoint (cold-bucket historical test)

```bash
awscurl --service execute-api --region "$AWS_REGION" \
  -X POST "$STATS_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "query_name":"statistics",
    "time_range":{"from":"2026-02-21T00:00:00Z","to":"2026-02-21T23:59:59Z"},
    "filters":{"meter_ids":["meter-001"]},
    "granularity":"15m",
    "timezone":"UTC",
    "limit":1000
  }'
```

## 5. Common reasons for empty results

- `meter_ids` does not match written IDs (`meter-001` vs `sim-meter-001`)
- Query range does not overlap ingest timestamps
- Cold bucket empty because downsampling task was missing/not run yet
- Query route points to cold but no backfill exists for older data
