import argparse
import os
from typing import Dict, Optional, Sequence

from meter_sim.models import SimulatorConfig


class ConfigLoader:
    """Build and validate simulator config from env + CLI args."""

    def env_defaults(self) -> Dict[str, object]:
        return {
            "endpoint": os.getenv("IOT_ENDPOINT"),
            "single_meter_id": os.getenv("METER_ID", "meter-001"),
            "meter_prefix": os.getenv("METER_PREFIX", "meter"),
            "start_index": int(os.getenv("METER_START_INDEX", "1")),
            "meters": int(os.getenv("NUM_METERS", "100")),
            "messages_per_sec": float(os.getenv("MESSAGES_PER_SEC", "20")),
            "duration_sec": int(os.getenv("DURATION_SEC", "300")),
            "qos": int(os.getenv("QOS", "1")),
        }

    def parser(self) -> argparse.ArgumentParser:
        defaults = self.env_defaults()
        parser = argparse.ArgumentParser(
            description="Publish simulated smart meter readings to AWS IoT Core"
        )
        parser.add_argument("--endpoint", default=defaults["endpoint"], help="IoT Core data endpoint")
        parser.add_argument(
            "--meters",
            type=int,
            default=defaults["meters"],
            help="Number of logical meters to simulate (default: 100)",
        )
        parser.add_argument(
            "--meter-prefix",
            default=defaults["meter_prefix"],
            help="Logical meter ID prefix (default: meter)",
        )
        parser.add_argument(
            "--start-index",
            type=int,
            default=defaults["start_index"],
            help="Starting index for logical meter IDs (default: 1)",
        )
        parser.add_argument(
            "--messages-per-sec",
            type=float,
            default=defaults["messages_per_sec"],
            help="Total publish rate across all meters (default: 20.0)",
        )
        parser.add_argument(
            "--duration-sec",
            type=int,
            default=defaults["duration_sec"],
            help="How long to run before stopping (default: 300)",
        )
        parser.add_argument(
            "--qos",
            type=int,
            choices=[0, 1],
            default=defaults["qos"],
            help="MQTT QoS level (0 or 1)",
        )
        parser.add_argument(
            "--single-meter-id",
            default=defaults["single_meter_id"],
            help="Used only when --meters=1 (default from METER_ID env var)",
        )
        return parser

    def load(self, argv: Optional[Sequence[str]] = None) -> SimulatorConfig:
        args = self.parser().parse_args(argv)
        config = SimulatorConfig(
            endpoint=args.endpoint,
            meters=args.meters,
            meter_prefix=args.meter_prefix,
            start_index=args.start_index,
            messages_per_sec=args.messages_per_sec,
            duration_sec=args.duration_sec,
            qos=args.qos,
            single_meter_id=args.single_meter_id,
        )
        self.validate(config)
        return config

    def validate(self, config: SimulatorConfig) -> None:
        if not config.endpoint:
            raise SystemExit("Set IOT_ENDPOINT environment variable to your IoT Core data endpoint")
        if config.meters <= 0:
            raise SystemExit("--meters must be greater than 0")
        if config.messages_per_sec <= 0:
            raise SystemExit("--messages-per-sec must be greater than 0")
        if config.duration_sec <= 0:
            raise SystemExit("--duration-sec must be greater than 0")
