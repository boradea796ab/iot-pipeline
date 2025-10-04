from celery import shared_task
from .models import Reading
import os, psutil, time
from celery import shared_task

@shared_task
def hello_world(n):
    proc = psutil.Process(os.getpid())
    mem = proc.memory_info().rss / (1024 * 1024)  # MB
    cpu = proc.cpu_percent(interval=0.05)

    print(f"[Task {n}] PID={proc.pid} | MEM={mem:.2f}MB | CPU={cpu:.2f}%")
    time.sleep(0.01)  # tiny delay so you can observe usage better
    return n


@shared_task
def ingest_reading(meter_id, timestamp, value):
    Reading.objects.create(
        meter_id=meter_id,
        timestamp=timestamp,
        value=value
    )