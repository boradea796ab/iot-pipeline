from __future__ import annotations

import sys
import types
from pathlib import Path
from unittest.mock import MagicMock

import pytest

MODULE_DIR = Path(__file__).resolve().parents[1]
CODE_PATH = MODULE_DIR / "code"


@pytest.fixture(autouse=True, scope="session")
def _load_code_package():
    if "code" not in sys.modules or not hasattr(sys.modules["code"], "__path__"):
        code_pkg = types.ModuleType("code")
        code_pkg.__path__ = [str(CODE_PATH)]
        sys.modules["code"] = code_pkg


@pytest.fixture(autouse=True, scope="session")
def _stub_boto3():
    mock_boto3 = MagicMock()
    mock_resource = MagicMock()
    mock_table = MagicMock()
    mock_resource.Table.return_value = mock_table
    mock_client = MagicMock()

    mock_boto3.resource.return_value = mock_resource
    mock_boto3.client.return_value = mock_client

    sys.modules["boto3"] = mock_boto3
    sys.modules["botocore.exceptions"] = types.SimpleNamespace(ClientError=Exception)
    # Provide env defaults so config/repository modules don't KeyError
    import os

    os.environ.setdefault("DB_SECRET_ARN", "dummy-secret")
    os.environ.setdefault("READINGS_TABLE", "iot_readings")
