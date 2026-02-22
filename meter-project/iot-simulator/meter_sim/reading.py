import random
from datetime import datetime, timezone
from typing import Dict


class ReadingGenerator:
    """Generate synthetic meter readings."""

    def build(self, meter_id: str) -> Dict[str, object]:
        now = datetime.now(timezone.utc)
        ts_ms = int(now.timestamp() * 1000)

        voltage = random.uniform(210.0, 240.0)
        current = random.uniform(0.0, 30.0)
        kwh_increment = random.uniform(0.0, 0.5)

        return {
            "meterId": meter_id,
            "ts": ts_ms,
            "kWh": round(kwh_increment, 4),
            "voltage": round(voltage, 2),
            "current": round(current, 2),
            "status": "OK",
        }
