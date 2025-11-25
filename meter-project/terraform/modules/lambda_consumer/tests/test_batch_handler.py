from __future__ import annotations

import json
from dataclasses import dataclass
from typing import List
from unittest.mock import MagicMock

import pytest

import sys
import types
import os
from pathlib import Path

MODULE_DIR = Path(__file__).resolve().parents[1]
CODE_PATH = MODULE_DIR / "code"

pkg = types.ModuleType("code")
pkg.__path__ = [str(CODE_PATH)]
sys.modules["code"] = pkg

mock_boto3 = MagicMock()
mock_resource = MagicMock()
mock_table = MagicMock()
mock_resource.Table.return_value = mock_table
mock_boto3.resource.return_value = mock_resource
mock_boto3.client.return_value = MagicMock()
sys.modules["boto3"] = mock_boto3
sys.modules["botocore.exceptions"] = types.SimpleNamespace(ClientError=Exception)
os.environ.setdefault("DB_SECRET_ARN", "dummy")
os.environ.setdefault("READINGS_TABLE", "iot_readings")

from code.batch_handler import BatchBehavior, run_batch
from code.idempotency import IdempotencyStore
from code.models import Message
from code.processor import ReadingProcessor


class FakeLogger:
    def __init__(self) -> None:
        self.entries: List[str] = []

    def info(self, payload: str) -> None:
        self.entries.append(payload)


@dataclass
class StubProcessor(ReadingProcessor):
    should_raise: bool = False

    def __init__(self, should_raise: bool = False) -> None:
        self.should_raise = should_raise

    def process(self, message: Message):
        if self.should_raise:
            raise ValueError("boom")
        return json.loads(message.body)


class StubStore(IdempotencyStore):
    def __init__(self) -> None:
        self.reserved: List[str] = []
        self.processed: List[str] = []
        self.failed: List[str] = []
        self.reserve_result = True

    def reserve(self, message_id: str) -> bool:
        self.reserved.append(message_id)
        return self.reserve_result

    def mark_processed(self, message_id: str, payload: str) -> None:
        self.processed.append(message_id)

    def mark_failed(self, message_id: str, payload: str, error_message: str) -> None:
        self.failed.append(message_id)


def _message(message_id: str, body: str = '{"value":1}', receive_count: str = "1") -> Message:
    return Message(message_id=message_id, body=body, attributes={"ApproximateReceiveCount": receive_count})


def test_run_batch_success_marks_processed_and_returns_result():
    store = StubStore()
    logger = FakeLogger()
    behavior = BatchBehavior(telemetry_prefix="ingest", status_label="done")

    result = run_batch(
        messages=[_message("m-1")],
        processor=StubProcessor(),
        store=store,
        behavior=behavior,
        logger=logger,
        request_id="req-123",
    )

    assert result.status == "done"
    assert result.processed == 1
    assert result.failures == []
    assert store.processed == ["m-1"]
    assert "ingest_success" in "".join(logger.entries)
    if __debug__:
        print(f"[batch] success result={result.to_lambda_response()} processed={store.processed}")


def test_run_batch_skips_when_reserve_returns_false():
    store = StubStore()
    store.reserve_result = False
    behavior = BatchBehavior(telemetry_prefix="ingest", status_label="done")

    result = run_batch(
        messages=[_message("duplicate")],
        processor=StubProcessor(),
        store=store,
        behavior=behavior,
        logger=FakeLogger(),
        request_id="req",
    )

    assert result.processed == 0
    assert result.failures == []
    assert store.processed == []
    if __debug__:
        print(f"[batch] skip result={result.to_lambda_response()} reserved={store.reserved}")


def test_run_batch_marks_failed_when_receive_count_exceeds_limit():
    store = StubStore()
    behavior = BatchBehavior(telemetry_prefix="dlq", status_label="dlq-processed", max_receive_count=3)

    result = run_batch(
        messages=[_message("m-err", receive_count="3")],
        processor=StubProcessor(should_raise=True),
        store=store,
        behavior=behavior,
        logger=FakeLogger(),
        request_id="req",
    )

    assert result.processed == 0
    assert result.failures == []
    assert store.failed == ["m-err"]
    if __debug__:
        print(f"[batch] terminal failure for {store.failed}")


def test_run_batch_returns_batch_failure_when_under_limit():
    store = StubStore()
    behavior = BatchBehavior(telemetry_prefix="dlq", status_label="dlq-processed", max_receive_count=5)

    result = run_batch(
        messages=[_message("needs-retry", receive_count="2")],
        processor=StubProcessor(should_raise=True),
        store=store,
        behavior=behavior,
        logger=FakeLogger(),
        request_id="req",
    )

    assert result.failures == ["needs-retry"]
    assert store.failed == []
    if __debug__:
        print(f"[batch] retry scheduled for {result.failures}")
