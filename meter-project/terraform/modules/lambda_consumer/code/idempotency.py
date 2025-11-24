from __future__ import annotations

import time
from abc import ABC, abstractmethod
from typing import Optional

import boto3
from botocore.exceptions import ClientError


class IdempotencyStore(ABC):
    """Abstracts idempotency semantics so it can be stubbed during tests."""

    @abstractmethod
    def reserve(self, message_id: str) -> bool:
        """Returns False if the message was already processed."""

    @abstractmethod
    def mark_processed(self, message_id: str, payload: str) -> None:
        ...

    def mark_failed(self, message_id: str, payload: str, error_message: str) -> None:
        """Optional hook for DLQ processors."""


class NullIdempotencyStore(IdempotencyStore):
    def reserve(self, message_id: str) -> bool:  # pragma: no cover - trivial
        return True

    def mark_processed(self, message_id: str, payload: str) -> None:  # pragma: no cover
        return None


class DynamoIdempotencyStore(IdempotencyStore):
    """Implements the store using a DynamoDB table shared by both Lambdas."""

    def __init__(
        self,
        table_name: str,
        *,
        payload_retention_seconds: int = 0,
        dynamodb_resource=None,
        processing_status: str = "PROCESSING",
        processed_status: str = "PROCESSED",
        failed_status: Optional[str] = None,
    ) -> None:
        self._dynamodb = dynamodb_resource or boto3.resource("dynamodb")
        self._table = self._dynamodb.Table(table_name)
        self._payload_retention_seconds = payload_retention_seconds
        self._processing_status = processing_status
        self._processed_status = processed_status
        self._failed_status = failed_status

    def reserve(self, message_id: str) -> bool:
        now_ts = int(time.time())
        condition = "attribute_not_exists(#s) OR #s <> :processed"
        expression_attribute_values = {
            ":status": self._processing_status,
            ":ts": now_ts,
            ":processed": self._processed_status,
        }

        if self._failed_status:
            condition += " AND #s <> :failed"
            expression_attribute_values[":failed"] = self._failed_status

        try:
            self._table.update_item(
                Key={"message_id": message_id},
                UpdateExpression="SET #s = :status, updated_at = :ts",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues=expression_attribute_values,
                ConditionExpression=condition,
            )
            return True
        except ClientError as err:  # pragma: no cover - thin wrapper
            if err.response["Error"].get("Code") == "ConditionalCheckFailedException":
                return False
            raise

    def mark_processed(self, message_id: str, payload: str) -> None:
        self._update_status(message_id, payload, self._processed_status, "processed_at")

    def mark_failed(self, message_id: str, payload: str, error_message: str) -> None:
        if not self._failed_status:
            return
        self._update_status(
            message_id,
            payload,
            self._failed_status,
            "failed_at",
            extra_attributes={"error_message": error_message[:500]},
        )

    def _update_status(
        self,
        message_id: str,
        payload: str,
        status: str,
        timestamp_attr: str,
        *,
        extra_attributes: Optional[dict] = None,
    ) -> None:
        now_ts = int(time.time())
        expression_attribute_values = {
            ":s": status,
            ":ts": now_ts,
            ":payload": payload,
        }
        update_expression = f"SET #s = :s, {timestamp_attr} = :ts, payload = :payload"

        if self._payload_retention_seconds > 0:
            expression_attribute_values[":exp"] = now_ts + self._payload_retention_seconds
            update_expression += ", expires_at = :exp"

        if extra_attributes:
            for key, value in extra_attributes.items():
                placeholder = f":extra_{key}"
                expression_attribute_values[placeholder] = value
                update_expression += f", {key} = {placeholder}"

        self._table.update_item(
            Key={"message_id": message_id},
            UpdateExpression=update_expression,
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues=expression_attribute_values,
        )
