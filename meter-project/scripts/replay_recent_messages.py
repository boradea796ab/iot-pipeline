#!/usr/bin/env python3
"""
Replay the most recent processed IoT payloads by pulling them from the
idempotency DynamoDB table and re-sending them to the ingestion API.
"""

import argparse
import base64
import hashlib
import hmac
import json
import os
import sys
import time
from decimal import Decimal
from typing import List, Dict, Any

import boto3
import requests

# Device secrets used to re-sign the payloads before sending them again.
DEVICE_SECRETS = {
    "M001": "supersecret-key-m001",
    "M002": "anothersecret-key",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Replay recent successful payloads from DynamoDB back to the API."
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=50,
        help="Number of recent payloads to replay (default: 50)",
    )
    parser.add_argument(
        "--sleep",
        type=float,
        default=0.25,
        help="Seconds to pause between replays to respect API Gateway limits (default: 0.25)",
    )
    return parser.parse_args()


def require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        print(f"❌ Missing required env var {name}.", file=sys.stderr)
        if name == "API_URL":
            print("   Run: export API_URL=$(terraform output -raw api_base_url)", file=sys.stderr)
        if name == "IDEMPOTENCY_TABLE":
            print(
                "   Run: export IDEMPOTENCY_TABLE=$(terraform output -raw idempotency_table_name)",
                file=sys.stderr,
            )
        sys.exit(1)
    return value.rstrip("/")


def scan_recent(table_name: str, limit: int) -> List[Dict[str, Any]]:
    """Scan the Dynamo table and return the latest processed items."""
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(table_name)

    items: List[Dict[str, Any]] = []
    scan_kwargs = {
        "ProjectionExpression": "message_id, payload, processed_at",
    }
    last_key = None
    while True:
        if last_key:
            response = table.scan(ExclusiveStartKey=last_key, **scan_kwargs)
        else:
            response = table.scan(**scan_kwargs)
        items.extend(response.get("Items", []))
        last_key = response.get("LastEvaluatedKey")
        if not last_key or len(items) >= limit * 5:
            break

    def processed_ts(item: Dict[str, Any]) -> int:
        value = item.get("processed_at", 0)
        if isinstance(value, Decimal):
            return int(value)
        return int(value or 0)

    enriched = [i for i in items if "payload" in i]
    enriched.sort(key=processed_ts, reverse=True)
    return enriched[:limit]


def sign_request(secret: str, device_id: str, timestamp: str) -> str:
    canonical = f"{device_id}:{timestamp}"
    digest = hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).digest()
    return base64.b64encode(digest).decode()


def replay_payload(api_base_url: str, payload_str: str) -> None:
    try:
        data = json.loads(payload_str)
    except json.JSONDecodeError:
        print("⚠️ Skipping payload: invalid JSON")
        return

    device_id = data.get("meter_id")
    if not device_id or device_id not in DEVICE_SECRETS:
        print(f"⚠️ Skipping payload: unknown device_id {device_id}")
        return

    timestamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    signature = sign_request(DEVICE_SECRETS[device_id], device_id, timestamp)
    headers = {
        "Content-Type": "application/json",
        "x-device-id": device_id,
        "x-signature": signature,
        "x-timestamp": timestamp,
    }

    try:
        resp = requests.post(api_base_url + "/prod/ingest", headers=headers, data=payload_str, timeout=5)
        print(f"[{device_id}] replay → {resp.status_code}: {resp.text[:80]}")
    except Exception as exc:
        print(f"[{device_id}] ❌ Error during replay: {exc}")


def main() -> None:
    args = parse_args()
    api_url = require_env("API_URL")
    table_name = require_env("IDEMPOTENCY_TABLE")

    print(f"Fetching up to {args.limit} recent payloads from {table_name} …")
    recent_items = scan_recent(table_name, args.limit)
    if not recent_items:
        print("No payloads found.")
        return

    print(f"Replaying {len(recent_items)} payload(s) to {api_url}/prod/ingest …")
    for idx, item in enumerate(recent_items, start=1):
        payload = item.get("payload")
        if isinstance(payload, dict):
            payload_str = json.dumps(payload)
        else:
            payload_str = payload
        replay_payload(api_url, payload_str)
        if args.sleep > 0 and idx < len(recent_items):
            time.sleep(args.sleep)

    print("✅ Replay completed.")


if __name__ == "__main__":
    main()
