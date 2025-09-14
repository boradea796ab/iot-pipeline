from celery import shared_task
from .models import Reading

@shared_task
def hello_world():
    return "Hello from Celery!"


@shared_task
def ingest_reading(meter_id, timestamp, value):
    Reading.objects.create(
        meter_id=meter_id,
        timestamp=timestamp,
        value=value
    )