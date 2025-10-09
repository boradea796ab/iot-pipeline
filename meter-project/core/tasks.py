from celery import shared_task
from .models import Reading
import os, psutil, time
from django.db import close_old_connections
import random, datetime

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
            ingest_reading.delay(meter_id, ts.isoformat(), value)

@shared_task
def ingest_reading(meter_id, timestamp, value):
    close_old_connections()  # ensures no stale DB sockets
    Reading.objects.create(
        meter_id=meter_id,
        timestamp=timestamp,
        value=value
    )