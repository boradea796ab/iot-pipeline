import json
import os
import random
import time

import boto3
from botocore.exceptions import ClientError

_dynamodb = boto3.resource("dynamodb")
_idempotency_table_name = os.environ.get("IDEMPOTENCY_TABLE")
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


def _mark_processed(message_id: str) -> None:
    if not _idempotency_table:
        return

    _idempotency_table.update_item(
        Key={"message_id": message_id},
        UpdateExpression="SET #s = :s, processed_at = :ts",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": "PROCESSED", ":ts": int(time.time())},
    )

def lambda_handler(event, context):
    for record in event["Records"]:
        body = record["body"]
        message_id = record["messageId"]
        print(f"Processing message: {body}")

        if not _reserve_message(message_id):
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
            _mark_processed(message_id)

    return {"status": "done"}
