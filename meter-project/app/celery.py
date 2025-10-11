import os
from celery import Celery
from celery.signals import worker_ready

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "app.settings")

app = Celery("app")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()

@worker_ready.connect
def start_consumer(sender=None, **kwargs):
    import os
    if os.environ.get("CELERY_QUEUE_NAME") == "flush":
        sender.app.send_task("core.tasks.consumer.batch_flush_readings", queue="flush")
