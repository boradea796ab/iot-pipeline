from celery import shared_task
from .models import Reading
import os, psutil, time
from django.db import close_old_connections
import random, datetime
import redis, json
from django.db import transaction
from django.conf import settings


# ---------------------------------------------------------------------
# Redis & batch settings
# ---------------------------------------------------------------------
REDIS_URL = getattr(settings, "REDIS_URL", settings.CELERY_BROKER_URL)
REDIS_KEY = "reading_buffer"
BATCH_SIZE = 100
LOCK_KEY = "reading_batch_lock"
LOCK_TTL = 10          # seconds
BLOCK_TIMEOUT = 5      # seconds
FLUSH_INTERVAL = 5     # seconds between idle checks

# ---------------------------------------------------------------------
# Redis connection (dedicated client, not Celery's internal connection)
# ---------------------------------------------------------------------
r = redis.StrictRedis.from_url(REDIS_URL, decode_responses=True)

# ---------------------------------------------------------------------
# PRODUCER TASK
# ---------------------------------------------------------------------
@shared_task(queue="enqueue")
def enqueue_reading(meter_id, timestamp, value):
    """Lightweight producer: pushes JSON payload to Redis list."""
    payload = json.dumps({"meter_id": meter_id, "timestamp": timestamp, "value": value})
    r.rpush(REDIS_KEY, payload)
    return "enqueued"


# ---------------------------------------------------------------------
# CONSUMER TASK
# ---------------------------------------------------------------------
@shared_task(queue="flush", bind=True, max_retries=None)
def batch_flush_readings(self):
    """
    Long-running consumer that drains Redis in batches and writes to DB.
    Should be run in its own dedicated Celery worker (concurrency=1).
    """
    print("[CONSUMER] Started batch_flush_readings worker")

    while True:
        batch = []

        # Acquire distributed lock (only one consumer active at a time)
        with r.lock(LOCK_KEY, timeout=LOCK_TTL, blocking_timeout=1) as lock:
            if not lock.locked():
                time.sleep(1)
                continue

            # Drain up to BATCH_SIZE items
            for _ in range(BATCH_SIZE):
                data = r.lpop(REDIS_KEY)
                if not data:
                    break
                batch.append(json.loads(data))

            if not batch:
                time.sleep(FLUSH_INTERVAL)
                continue

            try:
                close_old_connections()  # avoid stale DB connections
                with transaction.atomic():
                    Reading.objects.bulk_create(
                        [Reading(**d) for d in batch],
                        batch_size=BATCH_SIZE,
                        ignore_conflicts=True,  # prevent duplicates
                    )
                print(f"[BATCH INSERT] Inserted {len(batch)} readings.")
            except Exception as e:
                # Push failed batch back for retry
                for d in batch:
                    r.lpush(REDIS_KEY, json.dumps(d))
                print(f"[BATCH ERROR] {e}. Requeued {len(batch)} readings.")
                time.sleep(2)


@shared_task
def hello_world(n):
    proc = psutil.Process(os.getpid())
    mem = proc.memory_info().rss / (1024 * 1024)  # MB
    cpu = proc.cpu_percent(interval=0.05)

    print(f"[Task {n}] PID={proc.pid} | MEM={mem:.2f}MB | CPU={cpu:.2f}%")
    time.sleep(0.01)  # tiny delay so you can observe usage better
    return n

@shared_task
def simulate_readings_task(num_meters, interval_minutes, days):
    now = datetime.datetime.utcnow().replace(minute=0, second=0, microsecond=0)
    readings_per_meter = int((24*60*days)/interval_minutes)
    for meter_id in range(1, num_meters+1):
        for i in range(readings_per_meter):
            ts = now - datetime.timedelta(minutes=i*interval_minutes)
            value = round(random.uniform(0.1, 2.0), 3)
            enqueue_reading.delay(meter_id, ts.isoformat(), value)
