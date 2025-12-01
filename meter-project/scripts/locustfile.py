from locust import HttpUser, task, between
import time, json, random, hmac, hashlib, base64, os, threading, atexit
from pathlib import Path

# --------------------------------------------------------------------------
#  CONFIG
# --------------------------------------------------------------------------
API_URL = os.getenv("API_URL")
if not API_URL:
    raise RuntimeError("API_URL env variable missing")

API_URL = API_URL.rstrip("/") + "/prod/ingest"

REQUEST_LOG_PATH = os.getenv("LOCUST_REQUEST_LOG")

DEVICE_SECRETS = {
    "M001": "supersecret-key-m001",
    "M002": "anothersecret-key",
}

# 0.5–2 seconds between requests per user (can be adjusted)
WAIT_MIN = float(os.getenv("WAIT_MIN", "1.0"))
WAIT_MAX = float(os.getenv("WAIT_MAX", "2.0"))
# --------------------------------------------------------------------------


class RequestRecorder:
    """Append request/response metadata to a JSONL file in a thread-safe way."""

    def __init__(self, log_path: Path):
        self._path = log_path
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._file = self._path.open("a", encoding="utf-8")
        self._lock = threading.Lock()

    def log(self, record: dict) -> None:
        payload = json.dumps(record, separators=(",", ":"), default=str)
        with self._lock:
            self._file.write(payload + "\n")
            self._file.flush()

    def close(self) -> None:
        try:
            self._file.close()
        except Exception:
            pass


REQUEST_LOGGER = None
if REQUEST_LOG_PATH:
    REQUEST_LOGGER = RequestRecorder(Path(REQUEST_LOG_PATH))
    atexit.register(REQUEST_LOGGER.close)


def record_attempt(data: dict) -> None:
    if REQUEST_LOGGER is None:
        return
    REQUEST_LOGGER.log(data)


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

        try:
            response = self.client.post(endpoint, data=body, headers=headers, name="meter_ingest")
        except Exception as exc:
            record_attempt(
                {
                    "event": "request_error",
                    "device_id": device_id,
                    "payload": payload,
                    "signature_timestamp": timestamp,
                    "error": str(exc),
                }
            )
            raise

        message_id = None
        response_error = None
        response_text = response.text
        if response.status_code == 200:
            try:
                data = response.json()
                message_id = data.get("messageId")
            except ValueError:
                response_error = "Unable to decode JSON response"
        else:
            response_error = f"HTTP {response.status_code}"

        record_attempt(
            {
                "event": "request_complete",
                "device_id": device_id,
                "message_id": message_id,
                "payload": payload,
                "signature_timestamp": timestamp,
                "status_code": response.status_code,
                "response_body": (response_text[:500] if response_text else ""),
                "response_error": response_error,
            }
        )
