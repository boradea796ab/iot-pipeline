from __future__ import annotations

import os
import sys
import types
from pathlib import Path
from unittest.mock import MagicMock

import pytest

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

from code.models import Message
from code.processor import ProcessingSettings, ReadingProcessor


class FakeRepository:
    def __init__(self) -> None:
        self.saved = []

    def save_reading(self, message_id, payload):
        self.saved.append((message_id, payload))


def test_processor_saves_payload_json():
    repo = FakeRepository()
    processor = ReadingProcessor(repo)
    message = Message(message_id="m-1", body='{"foo":42}', attributes={})

    result = processor.process(message)

    assert result == {"foo": 42}
    assert repo.saved == [("m-1", {"foo": 42})]
    if __debug__:
        print(f"[processor] saved payloads: {repo.saved}")


def test_processor_simulated_failure_rate():
    repo = FakeRepository()
    processor = ReadingProcessor(repo, settings=ProcessingSettings(simulated_failure_rate=1.0))
    message = Message(message_id="m-1", body='{"foo":42}', attributes={})

    with pytest.raises(ValueError):
        processor.process(message)
    assert repo.saved == []
    if __debug__:
        print(f"[processor] failure path invoked, saved={repo.saved}")
