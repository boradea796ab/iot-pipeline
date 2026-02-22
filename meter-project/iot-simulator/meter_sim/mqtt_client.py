import ssl
from pathlib import Path

import paho.mqtt.client as mqtt


class MqttClientFactory:
    def __init__(self, cert_dir: Path | None = None) -> None:
        resolved_dir = cert_dir or (Path(__file__).resolve().parent.parent / "certs")
        self.root_ca = resolved_dir / "AmazonRootCA1.pem"
        self.cert = resolved_dir / "device_certificate.pem"
        self.key = resolved_dir / "private_key.pem"

    def create(self, client_id: str) -> mqtt.Client:
        client = mqtt.Client(client_id=client_id, protocol=mqtt.MQTTv311)
        client.on_connect = self.on_connect
        client.on_publish = self.on_publish

        client.tls_set(
            ca_certs=str(self.root_ca),
            certfile=str(self.cert),
            keyfile=str(self.key),
            cert_reqs=ssl.CERT_REQUIRED,
            tls_version=ssl.PROTOCOL_TLS_CLIENT,
        )
        client.tls_insecure_set(False)
        return client

    @staticmethod
    def on_connect(client, userdata, flags, rc, properties=None):
        print(f"[MQTT] Connected with result code {rc}")

    @staticmethod
    def on_publish(client, userdata, mid):
        # Placeholder callback for debugging publish acknowledgements.
        pass
