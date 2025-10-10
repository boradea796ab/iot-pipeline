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
# CONSUMER TASK
# ---------------------------------------------------------------------
@shared_task(queue="flush", bind=True)
def batch_flush_readings(self):
    print("[CONSUMER] Started batch_flush_readings worker")
    buffer = []
    last_flush = time.time()

    while True:
        try:
            # Wait for next reading wirth blocking pop (idle ≤ BLOCK_TIMEOUT)
            item = r.blpop(REDIS_KEY, timeout=BLOCK_TIMEOUT)
            if item:
                buffer.append(json.loads(item[1]))

            # Flush if batch full or flush interval reached
            if len(buffer) >= BATCH_SIZE or (buffer and time.time() - last_flush >= FLUSH_INTERVAL):
                flush_to_db(buffer)
                last_flush = time.time()
                buffer.clear()
        except Exception as e:
            print(f"[BATCH ERROR] {e}")
            time.sleep(2)


def flush_to_db(batch):
    close_old_connections()
    with transaction.atomic():
        Reading.objects.bulk_create(
            [Reading(**d) for d in batch],
            batch_size=len(batch),
            ignore_conflicts=True,
        )
    print(f"[BATCH INSERT] Inserted {len(batch)} readings")


@shared_task
def hello_world(n):
    proc = psutil.Process(os.getpid())
    mem = proc.memory_info().rss / (1024 * 1024)  # MB
    cpu = proc.cpu_percent(interval=0.05)

    print(f"[Task {n}] PID={proc.pid} | MEM={mem:.2f}MB | CPU={cpu:.2f}%")
    time.sleep(0.01)  # tiny delay so you can observe usage better
    return n

# ---------------------------------------------------------------------
# PRODUCER TASK
# ---------------------------------------------------------------------

@shared_task(queue="enqueue")
def simulate_readings_task(num_meters, interval_minutes, days):
    pipe = r.pipeline(transaction=False)
    now = datetime.datetime.utcnow().replace(minute=0, second=0, microsecond=0)
    readings_per_meter = int((24*60*days)/interval_minutes)

    for meter_id in range(1, num_meters+1):
        for i in range(readings_per_meter):
            ts = now - datetime.timedelta(minutes=i*interval_minutes)
            value = round(random.uniform(0.1, 2.0), 3)
            payload = json.dumps({"meter_id": meter_id, "timestamp": ts.isoformat(), "value": value})
            pipe.rpush(REDIS_KEY, payload)
    pipe.execute()
