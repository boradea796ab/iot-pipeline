#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  "INFLUX_HOST_URL"
  "INFLUX_ORG"
  "INFLUX_TOKEN"
  "HOT_BUCKET_NAME"
  "HOT_RETENTION_HRS"
  "COLD_BUCKET_NAME"
  "COLD_RETENTION_HRS"
)

for name in "${required_vars[@]}"; do
  if [ -z "${!name:-}" ]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
done

if ! command -v influx >/dev/null 2>&1; then
  echo "influx CLI is required for bucket tiering automation." >&2
  exit 1
fi

ensure_bucket() {
  local bucket_name="$1"
  local retention_hours="$2"
  local retention="${retention_hours}h"

  local bucket_id
  bucket_id="$(influx bucket list \
    --host-url "${INFLUX_HOST_URL}" \
    --org "${INFLUX_ORG}" \
    --token "${INFLUX_TOKEN}" \
    --name "${bucket_name}" \
    --hide-headers 2>/dev/null | awk 'NR==1 {print $1}')"

  if [ -z "${bucket_id}" ]; then
    influx bucket create \
      --host-url "${INFLUX_HOST_URL}" \
      --org "${INFLUX_ORG}" \
      --token "${INFLUX_TOKEN}" \
      --name "${bucket_name}" \
      --retention "${retention}" >/dev/null
    echo "Created bucket ${bucket_name} with retention ${retention}."
  else
    influx bucket update \
      --host-url "${INFLUX_HOST_URL}" \
      --org "${INFLUX_ORG}" \
      --token "${INFLUX_TOKEN}" \
      --id "${bucket_id}" \
      --retention "${retention}" >/dev/null
    echo "Updated bucket ${bucket_name} retention to ${retention}."
  fi
}

ensure_bucket "${HOT_BUCKET_NAME}" "${HOT_RETENTION_HRS}"
ensure_bucket "${COLD_BUCKET_NAME}" "${COLD_RETENTION_HRS}"
