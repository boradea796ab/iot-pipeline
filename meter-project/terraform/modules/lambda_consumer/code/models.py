from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Iterable, List


@dataclass(frozen=True)
class Message:
    """Lightweight wrapper around an SQS record used by both handlers."""

    message_id: str
    body: str
    attributes: Dict[str, Any]

    @property
    def receive_count(self) -> int:
        value = self.attributes.get("ApproximateReceiveCount", "1")
        try:
            return int(value)
        except (TypeError, ValueError):
            return 1


@dataclass
class BatchResult:
    """Represents the Lambda batch response payload."""

    status: str
    processed: int
    failures: List[str]

    def to_lambda_response(self) -> Dict[str, Any]:
        response: Dict[str, Any] = {"status": self.status, "processed": self.processed}
        if self.failures:
            response["batchItemFailures"] = [
                {"itemIdentifier": message_id} for message_id in self.failures
            ]
        return response


def parse_records(records: Iterable[Dict[str, Any]]) -> List[Message]:
    """Convert the raw Lambda `event["Records"]` array into Message objects."""

    parsed: List[Message] = []
    for record in records:
        parsed.append(
            Message(
                message_id=record["messageId"],
                body=record["body"],
                attributes=record.get("attributes", {}),
            )
        )
    return parsed
