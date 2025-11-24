from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class CommonConfig:
    idempotency_table: Optional[str]
    payload_retention_seconds: int
    db_secret_arn: str
    readings_table: str
    db_proxy_endpoint: Optional[str]


@dataclass
class ConsumerConfig(CommonConfig):
    failure_rate: float = 0.3


@dataclass
class DlqConfig(CommonConfig):
    max_dlq_attempts: int = 3


def _parse_int(value: str, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _parse_float(value: str, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load_consumer_config() -> ConsumerConfig:
    return ConsumerConfig(
        idempotency_table=os.environ.get("IDEMPOTENCY_TABLE"),
        payload_retention_seconds=_parse_int(os.environ.get("PAYLOAD_RETENTION_SECONDS", "0"), 0),
        db_secret_arn=os.environ["DB_SECRET_ARN"],
        readings_table=os.environ.get("READINGS_TABLE", "iot_readings"),
        db_proxy_endpoint=os.environ.get("DB_PROXY_ENDPOINT"),
        failure_rate=_parse_float(os.environ.get("SIMULATED_FAILURE_RATE", "0.3"), 0.3),
    )


def load_dlq_config() -> DlqConfig:
    return DlqConfig(
        idempotency_table=os.environ.get("IDEMPOTENCY_TABLE"),
        payload_retention_seconds=_parse_int(os.environ.get("PAYLOAD_RETENTION_SECONDS", "0"), 0),
        db_secret_arn=os.environ["DB_SECRET_ARN"],
        readings_table=os.environ.get("READINGS_TABLE", "iot_readings"),
        db_proxy_endpoint=os.environ.get("DB_PROXY_ENDPOINT"),
        max_dlq_attempts=_parse_int(os.environ.get("DLQ_MAX_ATTEMPTS", "3"), 3),
    )
