import json
import os
import random
import time

import boto3
from botocore.exceptions import ClientError

_dynamodb = boto3.resource("dynamodb")
_dlq_url = os.environ.get("DLQ_URL")
_idempotency_table_name = os.environ.get("IDEMPOTENCY_TABLE")
_payload_retention_seconds = int(os.environ.get("PAYLOAD_RETENTION_SECONDS", "0") or 0)
_idempotency_table = (
    _dynamodb.Table(_idempotency_table_name)
    if _idempotency_table_name
    else None
)


def _reserve_message(message_id: str) -> bool:
    """Allow reprocessing unless the message is already marked PROCESSED."""
    if not _idempotency_table:
        return True

    now_ts = int(time.time())
    try:
        _idempotency_table.update_item(
            Key={"message_id": message_id},
            UpdateExpression="SET #s = :status, updated_at = :ts",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":status": "DLQ_PROCESSING",
                ":ts": now_ts,
                ":processed": "PROCESSED",
            },
            ConditionExpression="attribute_not_exists(#s) OR #s <> :processed",
        )
        return True
    except ClientError as err:
        if err.response["Error"]["Code"] == "ConditionalCheckFailedException":
            print(f"[DLQ] ⏭️ Message {message_id} already PROCESSED; skipping.")
            return False
        raise


def _mark_processed(message_id: str, payload: str) -> None:
    if not _idempotency_table:
        return

    now_ts = int(time.time())
    expression_attribute_values = {
        ":s": "PROCESSED",
        ":ts": now_ts,
        ":payload": payload,
    }
    update_expression = "SET #s = :s, processed_at = :ts, payload = :payload"

    if _payload_retention_seconds > 0:
        expression_attribute_values[":exp"] = now_ts + _payload_retention_seconds
        update_expression += ", expires_at = :exp"

    _idempotency_table.update_item(
        Key={"message_id": message_id},
        UpdateExpression=update_expression,
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues=expression_attribute_values,
    )


def lambda_handler(event, context):
    for record in event.get("Records", []):
        body = record["body"]
        message_id = record["messageId"]
        print(f"[DLQ] Processing message: {body}")

        if not _reserve_message(message_id):
            continue

        try:
            data = json.loads(body)

            # Reuse the same business logic as the primary consumer.
            if random.random() < 0.3:
                raise ValueError("💥 Simulated random failure (DLQ)")

            print(f"[DLQ] ✅ Successfully processed message: {data}")
            time.sleep(0.2)

        except Exception as exc:
            print(f"[DLQ] ❌ Error while processing message {message_id}: {exc}")
            # Raising keeps the message in the DLQ for further manual review/retry.
            raise
        else:
            _mark_processed(message_id, body)

    return {"status": "dlq-processed"}
