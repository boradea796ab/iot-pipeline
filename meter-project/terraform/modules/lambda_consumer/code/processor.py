from __future__ import annotations

import json
import random
from dataclasses import dataclass
from typing import Dict

from .models import Message
from .repository import AuroraRepository


@dataclass
class ProcessingSettings:
    """Simple configuration for the message processor."""

    simulated_failure_rate: float = 0.0


class ReadingProcessor:
    """Coordinates payload parsing, optional validation, and DB persistence."""

    def __init__(self, repository: AuroraRepository, *, settings: ProcessingSettings | None = None) -> None:
        self._repository = repository
        self._settings = settings or ProcessingSettings()

    def process(self, message: Message) -> Dict[str, object]:
        payload = json.loads(message.body)
        self._maybe_simulate_failure()
        self._repository.save_reading(message.message_id, payload)
        return payload

    def _maybe_simulate_failure(self) -> None:
        rate = self._settings.simulated_failure_rate
        if rate <= 0:
            return
        if random.random() < rate:
            raise ValueError("Simulated random failure")
