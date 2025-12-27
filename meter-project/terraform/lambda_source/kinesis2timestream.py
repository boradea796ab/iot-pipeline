import base64
import json
import os
import urllib.request
import urllib.error
import logging
from typing import List

logger = logging.getLogger()
logger.setLevel(logging.INFO)

INFLUX_URL = os.environ["INFLUX_URL"]
INFLUX_TOKEN = os.environ["INFLUX_TOKEN"]

HEADERS = {
    "Authorization": f"Token {INFLUX_TOKEN}",
    "Content-Type": "text/plain; charset=utf-8"
}


def build_line_protocol(record: dict) -> str:
    """
    Convert one meter reading into InfluxDB line protocol
    """
    meter_id = record["meterId"]
    ts_ns = int(record["ts"]) * 1_000_000  # ms → ns

    return (
        f"meter_readings,"
        f"meterId={meter_id} "
        f"kWh={record['kWh']},"
        f"voltage={record['voltage']},"
        f"current={record['current']} "
        f"{ts_ns}"
    )


def lambda_handler(event, context):
    lines: List[str] = []

    for rec in event["Records"]:
        try:
            payload = base64.b64decode(rec["kinesis"]["data"])
            data = json.loads(payload)

            line = build_line_protocol(data)
            lines.append(line)

        except Exception as e:
            logger.exception("Failed to parse record, skipping")

    if not lines:
        logger.warning("No valid records to write")
        return {"statusCode": 204}

    body = "\n".join(lines).encode("utf-8")

    req = urllib.request.Request(
        INFLUX_URL,
        data=body,
        headers=HEADERS,
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            logger.info(
                "Successfully wrote %d records to InfluxDB (status=%s)",
                len(lines),
                resp.status
            )
            return {"statusCode": resp.status}

    except urllib.error.HTTPError as e:
        # Important: re-raise to force Lambda retry
        logger.error("InfluxDB write failed: %s", e.read().decode())
        raise

    except Exception:
        logger.exception("Unexpected error writing to InfluxDB")
        raise
