#!/usr/bin/env bash
set -euo pipefail

# Creates or updates a 15m downsampling task in InfluxDB2.
# Required env vars:
#   INFLUX_HOST (e.g. https://<endpoint>:8086)
#   INFLUX_TOKEN (admin token with task write permission)
#   INFLUX_ORG
#   INFLUX_HOT_BUCKET
#   INFLUX_COLD_BUCKET
# Optional env vars:
#   TASK_NAME (default: smart-meter-hot-to-cold-15m)
#   TASK_EVERY (default: 15m)
#   TASK_OFFSET (default: 1m)

: "${INFLUX_HOST:?INFLUX_HOST is required}"
: "${INFLUX_TOKEN:?INFLUX_TOKEN is required}"
: "${INFLUX_ORG:?INFLUX_ORG is required}"
: "${INFLUX_HOT_BUCKET:?INFLUX_HOT_BUCKET is required}"
: "${INFLUX_COLD_BUCKET:?INFLUX_COLD_BUCKET is required}"

TASK_NAME="${TASK_NAME:-smart-meter-hot-to-cold-15m}"
TASK_EVERY="${TASK_EVERY:-15m}"
TASK_OFFSET="${TASK_OFFSET:-1m}"

cat <<EOF >/tmp/influx_downsample_task.flux
option task = {name: "${TASK_NAME}", every: ${TASK_EVERY}, offset: ${TASK_OFFSET}}

base = from(bucket: "${INFLUX_HOT_BUCKET}")
  |> range(start: -task.every)
  |> filter(fn: (r) => r["_measurement"] == "meter_readings")

mean_stream = base
  |> aggregateWindow(every: 15m, fn: mean, createEmpty: false)
  |> set(key: "aggregation", value: "mean")

min_stream = base
  |> aggregateWindow(every: 15m, fn: min, createEmpty: false)
  |> set(key: "aggregation", value: "min")

max_stream = base
  |> aggregateWindow(every: 15m, fn: max, createEmpty: false)
  |> set(key: "aggregation", value: "max")

count_stream = base
  |> aggregateWindow(every: 15m, fn: count, createEmpty: false)
  |> set(key: "aggregation", value: "count")

union(tables: [mean_stream, min_stream, max_stream, count_stream])
  |> to(bucket: "${INFLUX_COLD_BUCKET}", org: "${INFLUX_ORG}")
EOF

TASK_ID="$(curl -sS -X GET "${INFLUX_HOST}/api/v2/tasks?name=${TASK_NAME}" \
  -H "Authorization: Token ${INFLUX_TOKEN}" \
  -H "Accept: application/json" | jq -r '.tasks[0].id // empty')"

if [[ -n "${TASK_ID}" ]]; then
  curl -sS -X PATCH "${INFLUX_HOST}/api/v2/tasks/${TASK_ID}" \
    -H "Authorization: Token ${INFLUX_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -Rs --arg org "${INFLUX_ORG}" '{flux: ., org: $org}' </tmp/influx_downsample_task.flux)" >/dev/null
  echo "Updated task: ${TASK_NAME} (${TASK_ID})"
else
  curl -sS -X POST "${INFLUX_HOST}/api/v2/tasks" \
    -H "Authorization: Token ${INFLUX_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -Rs --arg org "${INFLUX_ORG}" '{flux: ., org: $org}' </tmp/influx_downsample_task.flux)" >/dev/null
  echo "Created task: ${TASK_NAME}"
fi

rm -f /tmp/influx_downsample_task.flux
