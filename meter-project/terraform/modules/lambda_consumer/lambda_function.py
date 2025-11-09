import json
import random
import time

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

            # re-raise so AWS Lambda marks batch as failed → SQS redrive policy handles DLQ
            raise

    return {"status": "done"}
