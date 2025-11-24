from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Optional, Sequence

from .idempotency import IdempotencyStore
from .models import BatchResult, Message
from .processor import ReadingProcessor
from .telemetry import log_event


@dataclass(frozen=True)
class BatchBehavior:
    """Describes how a Lambda handler should behave for telemetry + retries."""

    telemetry_prefix: str
    status_label: str
    max_receive_count: Optional[int] = None  # only used by DLQ handler


def run_batch(
    messages: Sequence[Message],
    *,
    processor: ReadingProcessor,
    store: IdempotencyStore,
    behavior: BatchBehavior,
    logger,
    request_id: str,
) -> BatchResult:
    """Drive the reserve → process → mark lifecycle for a batch of SQS records."""

    failures: list[str] = []
    processed = 0
    for message in messages:
        start_ts = int(time.time() * 1000)
        log_event(
            logger,
            f"{behavior.telemetry_prefix}_start",
            message_id=message.message_id,
            request_id=request_id,
            receive_count=message.receive_count,
            timestamp_ms=start_ts,
        )

        if not store.reserve(message.message_id):
            log_event(
                logger,
                f"{behavior.telemetry_prefix}_skip",
                reason="idempotent",
                message_id=message.message_id,
                request_id=request_id,
            )
            continue

        try:
            processor.process(message)
        except Exception as exc:  # pragma: no cover - exercised in integration tests
            log_event(
                logger,
                f"{behavior.telemetry_prefix}_failure",
                message_id=message.message_id,
                request_id=request_id,
                receive_count=message.receive_count,
                error=str(exc),
            )
            if _should_mark_failed(message, behavior):
                store.mark_failed(message.message_id, message.body, str(exc))
                log_event(
                    logger,
                    f"{behavior.telemetry_prefix}_failed_terminal",
                    message_id=message.message_id,
                    request_id=request_id,
                    receive_count=message.receive_count,
                )
            else:
                failures.append(message.message_id)
            continue

        store.mark_processed(message.message_id, message.body)
        processed += 1
        duration_ms = int(time.time() * 1000) - start_ts
        log_event(
            logger,
            f"{behavior.telemetry_prefix}_success",
            message_id=message.message_id,
            request_id=request_id,
            duration_ms=duration_ms,
        )

    return BatchResult(status=behavior.status_label, processed=processed, failures=failures)


def _should_mark_failed(message: Message, behavior: BatchBehavior) -> bool:
    if behavior.max_receive_count is None:
        return False
    return message.receive_count >= behavior.max_receive_count
