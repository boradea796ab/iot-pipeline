from meter_sim.config import ConfigLoader
from meter_sim.ids import MeterIdFactory
from meter_sim.mqtt_client import MqttClientFactory
from meter_sim.reading import ReadingGenerator
from meter_sim.runner import SimulationReporter, SimulationRunner


def main() -> None:
    config = ConfigLoader().load()

    meter_ids = MeterIdFactory().build(config)
    client_id = f"{meter_ids[0]}-simulator"
    client = MqttClientFactory().create(client_id)
    runner = SimulationRunner(reading_generator=ReadingGenerator())

    print(f"[MQTT] Connecting to {config.endpoint} as {client_id}...")
    client.connect(config.endpoint, port=8883, keepalive=60)
    client.loop_start()

    try:
        stats = runner.run(config, client, meter_ids)
        SimulationReporter.report(stats, config.duration_sec)
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
