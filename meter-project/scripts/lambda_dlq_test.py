#!/usr/bin/env python3
import json, os, time, random, hmac, hashlib, base64, requests, threading, sys, logging
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

# --- CONFIG -------------------------------------------------------------------
API_URL = os.getenv("API_URL")  # pulled from environment
if not API_URL:
    print("❌ ERROR: API_URL environment variable not set.")
    print("Run: export API_URL=$(terraform output -raw api_base_url)")
    sys.exit(1)

# Make sure it has no trailing slash
API_URL = API_URL.rstrip("/") + "/prod/ingest"

DEVICE_SECRETS = {
    "M001": "supersecret-key-m001",
    "M002": "anothersecret-key"
}
REQUEST_COUNT  = 7000
DURATION_SEC   = 1000.0
MAX_WORKERS    = int(os.getenv("MAX_WORKERS", "32"))
LOG_DIR        = Path(__file__).resolve().parent / "logs"
LOG_FILE       = LOG_DIR / f"log-{datetime.utcnow().strftime('%Y-%m-%d-%H%M%S')}.log"
# ------------------------------------------------------------------------------

LOG_DIR.mkdir(parents=True, exist_ok=True)
logger = logging.getLogger("lambda_dlq_test")
logger.setLevel(logging.INFO)
handler = logging.FileHandler(LOG_FILE, mode="w", encoding="utf-8")
formatter = logging.Formatter("%(asctime)sZ %(levelname)s %(message)s", "%Y-%m-%dT%H:%M:%S")
formatter.converter = time.gmtime
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.propagate = False

_thread_local = threading.local()


def _get_session() -> requests.Session:
    session = getattr(_thread_local, "session", None)
    if session is None:
        session = requests.Session()
        _thread_local.session = session
    return session


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

def send_one(device_id: str):
    payload = make_payload(device_id)
    body = json.dumps(payload, separators=(",", ":"))
    timestamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    sig  = sign_request(DEVICE_SECRETS[device_id], device_id, timestamp)
    headers = {
        "Content-Type": "application/json",
        "x-device-id": device_id,
        "x-signature": sig,
        "x-timestamp": timestamp,
    }
    try:
        session = _get_session()
        r = session.post(API_URL, headers=headers, data=body, timeout=5)
        logger.info("[%s] %s %s", device_id, r.status_code, r.text.strip().replace("\n", " ")[:200])
    except Exception as e:
        logger.error("[%s] ❌ Error: %s", device_id, e)

def main():
    print(f"Sending {REQUEST_COUNT} requests over {DURATION_SEC}s → {API_URL}")
    print(f"Writing request logs to {LOG_FILE}")
    interval = DURATION_SEC / REQUEST_COUNT
    futures = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        next_launch = time.perf_counter()
        for _ in range(REQUEST_COUNT):
            dev = random.choice(list(DEVICE_SECRETS.keys()))
            futures.append(executor.submit(send_one, dev))
            next_launch += interval
            sleep_for = next_launch - time.perf_counter()
            if sleep_for > 0:
                time.sleep(sleep_for)
        for future in futures:
            future.result()
    print("✅ Simulation complete.")

if __name__ == "__main__":
    main()
