import json
import os
import random
import time

import boto3
from botocore.exceptions import ClientError
import pymysql

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


# -----------------------------
# Aurora DB Setup (via Secrets Manager)
# -----------------------------
DB_SECRET_ARN = os.environ["DB_SECRET_ARN"]

_secrets = boto3.client("secretsmanager")
secret_raw = _secrets.get_secret_value(SecretId=DB_SECRET_ARN)
secret = json.loads(secret_raw["SecretString"])

DB_HOST = secret["host"]
DB_USER = secret["username"]
DB_PASSWORD = secret["password"]
DB_NAME = secret["database"]
DB_PORT = int(secret.get("port", 3306))
READINGS_TABLE = os.environ.get("READINGS_TABLE", "iot_readings")



def get_db_connection():
    """Create a new DB connection each invocation (fast for Aurora Serverless v2)."""
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        port=DB_PORT,
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
    )


def save_reading_to_db(conn, message_id, payload_dict):
    """Insert a decoded reading into Aurora."""
    with conn.cursor() as cur:
        sql = f"""
            INSERT INTO {READINGS_TABLE} (
                id,
                payload,
                created_at
            ) VALUES (%s, %s, NOW())
        """
        cur.execute(sql, (message_id, json.dumps(payload_dict)))
    conn.commit()


def lambda_handler(event, context):
    conn = None
    try:
        conn = get_db_connection()

        for record in event.get("Records", []):
            body = record["body"]
            message_id = record["messageId"]
            print(f"[DLQ] Processing message: {body}")

            if not _reserve_message(message_id):
                continue

            try:
                payload = json.loads(body)

                # Reuse the same business logic as the primary consumer.
                if random.random() < 0.3:
                    raise ValueError("💥 Simulated random failure (DLQ)")

                # Save to Aurora
                save_reading_to_db(conn, message_id, payload)
                print(f"💾 Saved to Aurora: {message_id}")

            except Exception as exc:
                print(f"[DLQ] ❌ Error while processing message {message_id}: {exc}")
                # Raising keeps the message in the DLQ for further manual review/retry.
                raise
            else:
                _mark_processed(message_id, body)
    finally:
        if conn:
            conn.close()

    return {"status": "dlq-processed"}
