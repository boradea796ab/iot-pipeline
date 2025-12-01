import json
import os
import random
import ssl
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

IOT_ENDPOINT = os.getenv("IOT_ENDPOINT")  # e.g. a1234567890-ats.iot.ap-northeast-1.amazonaws.com
METER_ID = os.getenv("METER_ID", "meter-001")

CERT_DIR = os.path.join(os.path.dirname(__file__), "certs")
ROOT_CA_PATH = os.path.join(CERT_DIR, "AmazonRootCA1.pem")
CERT_PATH = os.path.join(CERT_DIR, "device_certificate.pem")
KEY_PATH = os.path.join(CERT_DIR, "private_key.pem")

TOPIC_TEMPLATE = "meters/{meter_id}/readings"


def build_reading(meter_id: str) -> dict:
    """Build a synthetic meter reading."""
    now = datetime.now(timezone.utc)

    # Very rough fake data
    voltage = random.uniform(210.0, 240.0)     # volts
    current = random.uniform(0.0, 30.0)        # amps
    # kWh increment per reading (assuming 15-min intervals, just fake here)
    kwh_increment = random.uniform(0.0, 0.5)

    return {
        "meter_id": meter_id,
        "ts": now.isoformat(),
        "kWh": round(kwh_increment, 4),
        "voltage": round(voltage, 2),
        "current": round(current, 2),
        "status": "OK",
    }


def on_connect(client, userdata, flags, rc, properties=None):
    print(f"[MQTT] Connected with result code {rc}")


def on_publish(client, userdata, mid):
    # You can log mid if you want
    pass


def main():
    if not IOT_ENDPOINT:
        raise SystemExit("Set IOT_ENDPOINT environment variable to your IoT Core data endpoint")

    client_id = f"{METER_ID}-simulator"

    client = mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv311)

    client.on_connect = on_connect
    client.on_publish = on_publish

    # TLS configuration for AWS IoT Core
    client.tls_set(
        ca_certs=ROOT_CA_PATH,
        certfile=CERT_PATH,
        keyfile=KEY_PATH,
        cert_reqs=ssl.CERT_REQUIRED,
        tls_version=ssl.PROTOCOL_TLS_CLIENT,
    )
    client.tls_insecure_set(False)

    print(f"[MQTT] Connecting to {IOT_ENDPOINT} as {client_id}...")
    client.connect(IOT_ENDPOINT, port=8883, keepalive=60)
    client.loop_start()

    topic = TOPIC_TEMPLATE.format(meter_id=METER_ID)
    print(f"[MQTT] Publishing to topic: {topic}")

    try:
        # For now, send a reading every 5 seconds (you can adjust later)
        while True:
            reading = build_reading(METER_ID)
            payload = json.dumps(reading)
            print(f"[MQTT] Publish: {payload}")
            result = client.publish(topic, payload, qos=1)
            result.wait_for_publish()
            time.sleep(5)
    except KeyboardInterrupt:
        print("Stopping simulator...")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
