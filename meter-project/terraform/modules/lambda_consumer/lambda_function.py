import json
import os
import random
import time

import boto3
from botocore.exceptions import ClientError

_dynamodb = boto3.resource("dynamodb")
_idempotency_table_name = os.environ.get("IDEMPOTENCY_TABLE")
_payload_retention_seconds = int(os.environ.get("PAYLOAD_RETENTION_SECONDS", "0") or 0)
_idempotency_table = (
    _dynamodb.Table(_idempotency_table_name)
    if _idempotency_table_name
    else None
)


def _reserve_message(message_id: str) -> bool:
    """Attempt to reserve a message ID; returns False if already processed."""
    if not _idempotency_table:
        return True

    try:
        _idempotency_table.put_item(
            Item={
                "message_id": message_id,
                "status": "PROCESSING",
                "updated_at": int(time.time()),
            },
            ConditionExpression="attribute_not_exists(message_id)",
        )
        return True
    except ClientError as err:
        if err.response["Error"]["Code"] == "ConditionalCheckFailedException":
            print(f"🔁 Message {message_id} already processed; skipping.")
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
    for record in event["Records"]:
        body = record["body"]
        message_id = record["messageId"]
        print(f"Processing message: {body}")

        if not _reserve_message(message_id):
            print(f"⏭️  Skipping message {message_id}: idempotency record already exists.")
            continue

        try:
            data = json.loads(body)

            # 🧠 Simulate transient failure ~30% of the time
            if random.random() < 0.3:
                raise ValueError("💥 Simulated random failure")

            # ✅ Normal processing (e.g., store to DB)
            print(f"✅ Successfully processed message: {data}")
            time.sleep(0.2)  # simulate some processing time

        except Exception as e:
            print(f"❌ Error: {e}")

            # re-raise so AWS Lambda marks batch as failed → SQS redrive policy handles DLQ
            raise
        else:
            _mark_processed(message_id, body)

    return {"status": "done"}
