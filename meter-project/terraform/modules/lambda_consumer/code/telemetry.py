import json
import logging
from typing import Any


def get_logger(name: str = "lambda_consumer") -> logging.Logger:
    logger = logging.getLogger(name)
    if not logger.handlers:
        logging.basicConfig(level=logging.INFO)
    logger.setLevel(logging.INFO)
    return logger


def log_event(logger: logging.Logger, event: str, **fields: Any) -> None:
    payload = {"event": event}
    payload.update(fields)
    logger.info(json.dumps(payload))
