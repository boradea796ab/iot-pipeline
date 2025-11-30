from locust import HttpUser, task, between
import time, json, random, hmac, hashlib, base64, os
from datetime import datetime

# --------------------------------------------------------------------------
#  CONFIG
# --------------------------------------------------------------------------
API_URL = os.getenv("API_URL")
if not API_URL:
    raise RuntimeError("API_URL env variable missing")

API_URL = API_URL.rstrip("/") + "/prod/ingest"

DEVICE_SECRETS = {
    "M001": "supersecret-key-m001",
    "M002": "anothersecret-key",
}

# 0.5–2 seconds between requests per user (can be adjusted)
WAIT_MIN = float(os.getenv("WAIT_MIN", "0.2"))
WAIT_MAX = float(os.getenv("WAIT_MAX", "1.0"))
# --------------------------------------------------------------------------


def sign_request(secret: str, device_id: str, timestamp: str) -> str:
    canonical = f"{device_id}:{timestamp}"
    digest = hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).digest()
    return base64.b64encode(digest).decode()


def make_payload(device_id: str) -> dict:
    return {
        "meter_id": device_id,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "reading_value": round(random.uniform(0, 999.9), 2),
        "unit": "kWh",
        "meter_type": "SMART_METER"
    }


class MeterUser(HttpUser):
    host = os.getenv("API_URL", "").rstrip("/")   # Locust now knows your host
    wait_time = between(WAIT_MIN, WAIT_MAX)

    @task
    def send_reading(self):

        endpoint = "/prod/ingest"
        # 1. Pick a random device
        device_id = random.choice(list(DEVICE_SECRETS.keys()))
        secret = DEVICE_SECRETS[device_id]

        # 2. Prepare payload & timestamp
        payload = make_payload(device_id)
        body = json.dumps(payload, separators=(",", ":"))

        timestamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
        signature = sign_request(secret, device_id, timestamp)

        # 3. Send the request
        headers = {
            "Content-Type": "application/json",
            "x-device-id": device_id,
            "x-timestamp": timestamp,
            "x-signature": signature,
        }

        self.client.post(endpoint, data=body, headers=headers, name="meter_ingest")
