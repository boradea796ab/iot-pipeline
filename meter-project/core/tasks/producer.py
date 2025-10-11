from celery import shared_task
from core.services.redis_service import RedisService
from core.services.simulation_service import IoTSimulator
from django.conf import settings

REDIS_URL = getattr(settings, "REDIS_URL", settings.CELERY_BROKER_URL)

@shared_task(bind=True)
def simulate_readings_task(self, num_meters, interval_minutes, days, duration_s=60):
    """Celery entrypoint for streaming IoT readings into Redis."""
    redis_service = RedisService(REDIS_URL)
    simulator = IoTSimulator(redis_service)
    simulator.run(num_meters, interval_minutes, days, duration_s)
