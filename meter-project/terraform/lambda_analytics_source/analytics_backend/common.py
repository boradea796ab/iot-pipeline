import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Dict

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ALLOWED_GRANULARITIES = {"1m", "5m", "15m", "1h"}
HIGH_GRANULARITIES = {"1m", "5m"}
ALLOWED_QUERY_NAMES = {"timeseries", "statistics"}
ALLOWED_MODES = {"aggregated", "raw"}
DEFAULT_FIELDS = ["kWh", "voltage", "current"]


class ValidationError(Exception):
    pass


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        logger.warning("Invalid integer env var", extra={"env": name, "value": value})
        return default


def response(status_code: int, payload: Dict) -> Dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_time(value: str) -> datetime:
    if not isinstance(value, str):
        raise ValidationError("Time values must be RFC3339 strings")

    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise ValidationError(f"Invalid RFC3339 timestamp: {value}") from exc

    if parsed.tzinfo is None:
        raise ValidationError(f"Timestamp must include timezone: {value}")

    return parsed.astimezone(timezone.utc)


def escape_flux_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def emit_metric(metric_name: str, value: float, unit: str = "Count") -> None:
    emf = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": os.getenv("METRICS_NAMESPACE", "SmartMeter/AnalyticsQuery"),
                    "Dimensions": [["Service"]],
                    "Metrics": [{"Name": metric_name, "Unit": unit}],
                }
            ],
        },
        "Service": "analytics-query",
        metric_name: value,
    }
    logger.info(json.dumps(emf))


def log_event(event_name: str, **kwargs) -> None:
    payload = {"event": event_name, "service": "analytics-query"}
    payload.update(kwargs)
    logger.info(json.dumps(payload, default=str))


def lookback_cutoff(max_lookback_days: int) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=max_lookback_days)


def hot_cutoff(hot_retention_days: int) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=hot_retention_days)
