from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional

import boto3
import pymysql


class AuroraRepository:
    """Encapsulates Aurora access so it can be mocked in tests."""

    def __init__(
        self,
        *,
        host: str,
        user: str,
        password: str,
        database: str,
        port: int = 3306,
        table_name: str = "iot_readings",
        proxy_endpoint: Optional[str] = None,
    ) -> None:
        self._config = {
            "host": proxy_endpoint or host,
            "user": user,
            "password": password,
            "database": database,
            "port": port,
        }
        self._table_name = table_name
        self._conn: Optional[pymysql.connections.Connection] = None

    @classmethod
    def from_secret(cls, secret_arn: str, *, table_name: str, proxy_endpoint: Optional[str] = None):
        secrets = boto3.client("secretsmanager")
        payload = secrets.get_secret_value(SecretId=secret_arn)
        data = json.loads(payload["SecretString"])
        return cls(
            host=data["host"],
            user=data["username"],
            password=data["password"],
            database=data["database"],
            port=int(data.get("port", 3306)),
            table_name=table_name,
            proxy_endpoint=proxy_endpoint,
        )

    def close(self) -> None:
        if self._conn:
            try:
                self._conn.close()
            finally:
                self._conn = None

    def _connection(self) -> pymysql.connections.Connection:
        if self._conn is not None:
            try:
                self._conn.ping(reconnect=True)
                return self._conn
            except Exception:
                self.close()
        self._conn = pymysql.connect(
            connect_timeout=5,
            cursorclass=pymysql.cursors.DictCursor,
            **self._config,
        )
        return self._conn

    def save_reading(self, message_id: str, payload: Dict[str, Any]) -> None:
        conn = self._connection()
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {self._table_name} (
                    message_id,
                    payload,
                    created_at
                ) VALUES (%s, %s, NOW())
                """,
                (message_id, json.dumps(payload)),
            )
        conn.commit()


class InMemoryRepository(AuroraRepository):  # pragma: no cover - used only in tests
    def __init__(self):
        self.rows = []

    def save_reading(self, message_id: str, payload: Dict[str, Any]) -> None:
        self.rows.append((message_id, payload))

    def close(self) -> None:
        return None
