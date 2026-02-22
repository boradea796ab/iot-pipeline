import json
import time
from typing import List

import paho.mqtt.client as mqtt

from meter_sim.models import SimulationStats, SimulatorConfig
from meter_sim.reading import ReadingGenerator


class SimulationRunner:
    def __init__(self, reading_generator: ReadingGenerator, topic_template: str = "meters/{meter_id}/readings") -> None:
        self.reading_generator = reading_generator
        self.topic_template = topic_template

    def run(self, config: SimulatorConfig, client: mqtt.Client, meter_ids: List[str]) -> SimulationStats:
        interval_sec = 1.0 / config.messages_per_sec
        deadline = time.monotonic() + config.duration_sec
        meter_index = 0
        stats = SimulationStats()

        print(
            "[MQTT] Starting load test: "
            f"meters={len(meter_ids)}, messages_per_sec={config.messages_per_sec}, "
            f"duration_sec={config.duration_sec}, qos={config.qos}"
        )

        try:
            while time.monotonic() < deadline:
                meter_id = meter_ids[meter_index]
                topic = self.topic_template.format(meter_id=meter_id)
                payload = json.dumps(self.reading_generator.build(meter_id))

                result = client.publish(topic, payload, qos=config.qos)
                result.wait_for_publish()

                if result.rc == mqtt.MQTT_ERR_SUCCESS:
                    stats.published += 1
                else:
                    stats.publish_errors += 1

                meter_index = (meter_index + 1) % len(meter_ids)
                time.sleep(interval_sec)
        except KeyboardInterrupt:
            print("Stopping simulator...")

        return stats


class SimulationReporter:
    @staticmethod
    def report(stats: SimulationStats, duration_sec: int) -> None:
        elapsed = max(0.0001, duration_sec)
        actual_rate = stats.published / elapsed
        print(
            "[MQTT] Finished: "
            f"published={stats.published}, errors={stats.publish_errors}, approx_rate={actual_rate:.2f} msg/s"
        )
