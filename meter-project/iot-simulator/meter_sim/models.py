from dataclasses import dataclass


@dataclass(frozen=True)
class SimulatorConfig:
    endpoint: str
    meters: int
    meter_prefix: str
    start_index: int
    messages_per_sec: float
    duration_sec: int
    qos: int
    single_meter_id: str


@dataclass
class SimulationStats:
    published: int = 0
    publish_errors: int = 0
