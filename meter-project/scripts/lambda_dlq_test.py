#!/usr/bin/env python3
import json, os, time, random, hmac, hashlib, base64, requests, threading, sys

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
REQUEST_COUNT  = 200
DURATION_SEC   = 100.0
# ------------------------------------------------------------------------------

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
        r = requests.post(API_URL, headers=headers, data=body, timeout=5)
        print(f"[{device_id}] {r.status_code}: {r.text[:80]}")
    except Exception as e:
        print(f"[{device_id}] ❌ Error: {e}")

def main():
    print(f"Sending {REQUEST_COUNT} requests over {DURATION_SEC}s → {API_URL}")
    interval = DURATION_SEC / REQUEST_COUNT
    threads = []
    for _ in range(REQUEST_COUNT):
        dev = random.choice(list(DEVICE_SECRETS.keys()))
        t = threading.Thread(target=send_one, args=(dev,))
        threads.append(t)
        t.start()
        time.sleep(interval)
    for t in threads: t.join()
    print("✅ Simulation complete.")

if __name__ == "__main__":
    main()
