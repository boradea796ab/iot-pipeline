import json
import os
import random
import ssl
import time
import argparse
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

IOT_ENDPOINT = os.getenv("IOT_ENDPOINT")  # e.g. a1234567890-ats.iot.ap-northeast-1.amazonaws.com
DEFAULT_METER_ID = os.getenv("METER_ID", "meter-001")
METER_PREFIX = os.getenv("METER_PREFIX", "meter")
METER_START_INDEX = int(os.getenv("METER_START_INDEX", "1"))
NUM_METERS = int(os.getenv("NUM_METERS", "100"))
MESSAGES_PER_SEC = float(os.getenv("MESSAGES_PER_SEC", "20"))
DURATION_SEC = int(os.getenv("DURATION_SEC", "300"))
QOS = int(os.getenv("QOS", "1"))

CERT_DIR = os.path.join(os.path.dirname(__file__), "certs")
ROOT_CA_PATH = os.path.join(CERT_DIR, "AmazonRootCA1.pem")
CERT_PATH = os.path.join(CERT_DIR, "device_certificate.pem")
KEY_PATH = os.path.join(CERT_DIR, "private_key.pem")

TOPIC_TEMPLATE = "meters/{meter_id}/readings"


def build_reading(meter_id: str) -> dict:
    """Build a synthetic meter reading."""
    now = datetime.now(timezone.utc)
    ts_ms = int(now.timestamp() * 1000)  # epoch milliseconds

    # Very rough fake data
    voltage = random.uniform(210.0, 240.0)     # volts
    current = random.uniform(0.0, 30.0)        # amps
    # kWh increment per reading (assuming 15-min intervals, just fake here)
    kwh_increment = random.uniform(0.0, 0.5)

    return {
        "meterId": meter_id,
        "ts": ts_ms,
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Publish simulated smart meter readings to AWS IoT Core"
    )
    parser.add_argument("--endpoint", default=IOT_ENDPOINT, help="IoT Core data endpoint")
    parser.add_argument(
        "--meters",
        type=int,
        default=NUM_METERS,
        help="Number of logical meters to simulate (default: 100)",
    )
    parser.add_argument(
        "--meter-prefix",
        default=METER_PREFIX,
        help="Logical meter ID prefix (default: meter)",
    )
    parser.add_argument(
        "--start-index",
        type=int,
        default=METER_START_INDEX,
        help="Starting index for logical meter IDs (default: 1)",
    )
    parser.add_argument(
        "--messages-per-sec",
        type=float,
        default=MESSAGES_PER_SEC,
        help="Total publish rate across all meters (default: 20.0)",
    )
    parser.add_argument(
        "--duration-sec",
        type=int,
        default=DURATION_SEC,
        help="How long to run before stopping (default: 300)",
    )
    parser.add_argument(
        "--qos",
        type=int,
        choices=[0, 1],
        default=QOS,
        help="MQTT QoS level (0 or 1)",
    )
    parser.add_argument(
        "--single-meter-id",
        default=DEFAULT_METER_ID,
        help="Used only when --meters=1 (default from METER_ID env var)",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    if not args.endpoint:
        raise SystemExit("Set IOT_ENDPOINT environment variable to your IoT Core data endpoint")
    if args.meters <= 0:
        raise SystemExit("--meters must be greater than 0")
    if args.messages_per_sec <= 0:
        raise SystemExit("--messages-per-sec must be greater than 0")
    if args.duration_sec <= 0:
        raise SystemExit("--duration-sec must be greater than 0")

    if args.meters == 1:
        meter_ids = [args.single_meter_id]
    else:
        meter_ids = [
            f"{args.meter_prefix}-{idx:03d}"
            for idx in range(args.start_index, args.start_index + args.meters)
        ]

    client_id = f"{meter_ids[0]}-simulator"

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

    print(f"[MQTT] Connecting to {args.endpoint} as {client_id}...")
    client.connect(args.endpoint, port=8883, keepalive=60)
    client.loop_start()

    interval_sec = 1.0 / args.messages_per_sec
    deadline = time.monotonic() + args.duration_sec
    meter_index = 0
    published = 0
    publish_errors = 0

    print(
        "[MQTT] Starting load test: "
        f"meters={len(meter_ids)}, messages_per_sec={args.messages_per_sec}, "
        f"duration_sec={args.duration_sec}, qos={args.qos}"
    )

    try:
        while time.monotonic() < deadline:
            meter_id = meter_ids[meter_index]
            topic = TOPIC_TEMPLATE.format(meter_id=meter_id)
            reading = build_reading(meter_id)
            payload = json.dumps(reading)
            result = client.publish(topic, payload, qos=args.qos)
            result.wait_for_publish()

            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                published += 1
            else:
                publish_errors += 1

            meter_index = (meter_index + 1) % len(meter_ids)
            time.sleep(interval_sec)
    except KeyboardInterrupt:
        print("Stopping simulator...")
    finally:
        elapsed = max(0.0001, args.duration_sec)
        actual_rate = published / elapsed
        print(
            "[MQTT] Finished: "
            f"published={published}, errors={publish_errors}, approx_rate={actual_rate:.2f} msg/s"
        )
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
