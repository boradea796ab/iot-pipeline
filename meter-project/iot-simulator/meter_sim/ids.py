from typing import List

from meter_sim.models import SimulatorConfig


class MeterIdFactory:
    def build(self, config: SimulatorConfig) -> List[str]:
        if config.meters == 1:
            return [config.single_meter_id]

        return [
            f"{config.meter_prefix}-{idx:03d}"
            for idx in range(config.start_index, config.start_index + config.meters)
        ]
