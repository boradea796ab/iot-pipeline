import json
import logging
import os
import time
import uuid

import boto3
import pymysql
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_dynamodb = boto3.resource("dynamodb")
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
                ":failed": "FAILED_DLQ",
            },
            ConditionExpression="attribute_not_exists(#s) OR (#s <> :processed AND #s <> :failed)",
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


def _mark_failed(message_id: str, payload: str, error_message: str) -> None:
    if not _idempotency_table:
        return

    now_ts = int(time.time())
    expression_attribute_values = {
        ":s": "FAILED_DLQ",
        ":ts": now_ts,
        ":payload": payload,
        ":error": error_message[:500],
    }
    update_expression = "SET #s = :s, failed_at = :ts, payload = :payload, error_message = :error"

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
MAX_DLQ_ATTEMPTS = int(os.environ.get("DLQ_MAX_ATTEMPTS", "3"))

_db_conn = None


def _close_cached_connection():
    global _db_conn
    if _db_conn:
        try:
            _db_conn.close()
        except Exception:
            pass
        finally:
            _db_conn = None



def get_db_connection():
    """Return a cached DB connection, reconnecting if it expired."""
    global _db_conn

    if _db_conn is not None:
        try:
            _db_conn.ping(reconnect=True)
            return _db_conn
        except Exception:
            _close_cached_connection()

    _db_conn = pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        port=DB_PORT,
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
    )
    return _db_conn


def save_reading_to_db(conn, message_id, payload_dict):
    """Insert a decoded reading into Aurora."""
    with conn.cursor() as cur:
        sql = f"""
            INSERT INTO {READINGS_TABLE} (
                message_id,
                payload,
                created_at
            ) VALUES (%s, %s, NOW())
        """
        cur.execute(sql, (message_id, json.dumps(payload_dict)))
    conn.commit()


def lambda_handler(event, context):
    conn = get_db_connection()
    batch_failures = []

    for record in event.get("Records", []):
        body = record["body"]
        message_id = record["messageId"]
        print(f"[DLQ] Processing message: {body}")
        request_id = getattr(context, "aws_request_id", str(uuid.uuid4()))
        dlq_attempt = int(record.get("attributes", {}).get("ApproximateReceiveCount", "1"))
        t_start = time.time()
        logger.info(
            json.dumps(
                {
                    "event": "dlq_start",
                    "message_id": message_id,
                    "request_id": request_id,
                    "attempt": dlq_attempt,
                    "timestamp_ms": int(t_start * 1000),
                }
            )
        )

        if not _reserve_message(message_id):
            logger.info(
                json.dumps(
                    {
                        "event": "dlq_skip",
                        "reason": "idempotent",
                        "message_id": message_id,
                        "request_id": request_id,
                    }
                )
            )
            continue

        try:
            payload = json.loads(body)

            # Save to Aurora
            save_reading_to_db(conn, message_id, payload)
            print(f"💾 Saved to Aurora: {message_id}")

        except Exception as exc:
            print(f"[DLQ] ❌ Error while processing message {message_id}: {exc}")
            if isinstance(exc, pymysql.MySQLError):
                _close_cached_connection()
            logger.error(
                json.dumps(
                    {
                        "event": "dlq_failure",
                        "message_id": message_id,
                        "request_id": request_id,
                        "attempt": dlq_attempt,
                        "error": str(exc),
                    }
                )
            )
            if dlq_attempt >= MAX_DLQ_ATTEMPTS:
                print(
                    f"[DLQ] ⚠️ Message {message_id} exceeded {MAX_DLQ_ATTEMPTS} attempts; marking FAILED_DLQ"
                )
                _mark_failed(message_id, body, str(exc))
                logger.warning(
                    json.dumps(
                        {
                            "event": "dlq_failed_terminal",
                            "message_id": message_id,
                            "request_id": request_id,
                            "attempt": dlq_attempt,
                        }
                    )
                )
                continue

            batch_failures.append({"itemIdentifier": message_id})
            continue
        else:
            _mark_processed(message_id, body)
            duration_ms = int((time.time() - t_start) * 1000)
            logger.info(
                json.dumps(
                    {
                        "event": "dlq_success",
                        "message_id": message_id,
                        "request_id": request_id,
                        "attempt": dlq_attempt,
                        "duration_ms": duration_ms,
                    }
                )
            )

    response = {"status": "dlq-processed"}
    if batch_failures:
        response["batchItemFailures"] = batch_failures
    return response
