import json, time, os, psutil
from celery import shared_task
from django.db import transaction, close_old_connections
from django.conf import settings

from core.services.redis_service import RedisService
from core.services.iot_connector import IOTConnector

# ---------------------------------------------------------------------
# Settings (tuneable via Django settings or env vars)
# ---------------------------------------------------------------------
REDIS_URL = getattr(settings, "REDIS_URL", settings.CELERY_BROKER_URL)
REDIS_KEY = getattr(settings, "READING_BUFFER_KEY", "reading_buffer")
BATCH_SIZE = getattr(settings, "READING_BATCH_SIZE", 100)
BLOCK_TIMEOUT = getattr(settings, "REDIS_BLOCK_TIMEOUT", 5)
FLUSH_INTERVAL = getattr(settings, "FLUSH_INTERVAL", 5)

# ---------------------------------------------------------------------
# Celery Consumer Task
# ---------------------------------------------------------------------
@shared_task(queue="flush", bind=True)
def batch_flush_readings(self):
    """Continuously consume readings from Redis and flush to DB in batches."""
    print("[CONSUMER] Started batch_flush_readings worker")

    redis_service = RedisService(REDIS_URL)
    connector = IOTConnector()
    client = redis_service.client

    buffer = []
    last_flush = time.time()

    while True:
        try:
            item = client.blpop(REDIS_KEY, timeout=BLOCK_TIMEOUT)
            if item:
                buffer.append(json.loads(item[1]))

            if len(buffer) >= BATCH_SIZE or (
                buffer and time.time() - last_flush >= FLUSH_INTERVAL
            ):
                count = connector.flush_to_db(buffer)
                print(f"[BATCH INSERT] Inserted {count} readings")
                buffer.clear()
                last_flush = time.time()

        except Exception as e:
            print(f"[BATCH ERROR] {e}")
            time.sleep(2)


