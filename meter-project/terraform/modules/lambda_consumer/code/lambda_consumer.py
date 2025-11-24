from __future__ import annotations

import uuid

from .batch_handler import BatchBehavior, run_batch
from .config import load_consumer_config
from .idempotency import DynamoIdempotencyStore, NullIdempotencyStore
from .models import BatchResult, parse_records
from .processor import ProcessingSettings, ReadingProcessor
from .repository import AuroraRepository
from .telemetry import get_logger


def _build_dependencies():
    config = load_consumer_config()
    repository = AuroraRepository.from_secret(
        config.db_secret_arn,
        table_name=config.readings_table,
        proxy_endpoint=config.db_proxy_endpoint,
    )
    settings = ProcessingSettings(simulated_failure_rate=config.failure_rate)
    processor = ReadingProcessor(repository, settings=settings)
    store = (
        DynamoIdempotencyStore(
            config.idempotency_table,
            payload_retention_seconds=config.payload_retention_seconds,
            processing_status="PROCESSING",
            processed_status="PROCESSED",
        )
        if config.idempotency_table
        else NullIdempotencyStore()
    )
    behavior = BatchBehavior(telemetry_prefix="ingest", status_label="done")
    logger = get_logger("lambda_consumer")
    return processor, store, behavior, logger


_PROCESSOR, _STORE, _BEHAVIOR, _LOGGER = _build_dependencies()


def lambda_handler(event, context):
    request_id = getattr(context, "aws_request_id", str(uuid.uuid4()))
    messages = parse_records(event.get("Records", []))
    result: BatchResult = run_batch(
        messages,
        processor=_PROCESSOR,
        store=_STORE,
        behavior=_BEHAVIOR,
        logger=_LOGGER,
        request_id=request_id,
    )
    return result.to_lambda_response()
