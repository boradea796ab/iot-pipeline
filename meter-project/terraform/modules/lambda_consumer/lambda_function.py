import json
import os
import boto3
import random
import time

sqs = boto3.client("sqs")

def lambda_handler(event, context):
    for record in event["Records"]:
        body = record["body"]
        print(f"Processing message: {body}")
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

            # Send message explicitly to DLQ (optional)
            dlq_url = os.environ.get("DLQ_URL")
            if dlq_url:
                print("➡️ Sending failed message to DLQ...")
                sqs.send_message(QueueUrl=dlq_url, MessageBody=body)
            # re-raise so AWS Lambda marks batch as failed → triggers retry
            raise

    return {"status": "done"}
