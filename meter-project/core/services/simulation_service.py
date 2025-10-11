import datetime, json, random, time
from .redis_service import RedisService

class IoTSimulator:
    """Simulates IoT meter readings over time, streamed into Redis."""

    def __init__(self, redis_service: RedisService, redis_key="reading_buffer"):
        self.redis = redis_service
        self.redis_key = redis_key

    def run(
        self,
        num_meters: int,
        interval_minutes: int,
        days: int,
        duration_s: int = 60,
        flush_every: int = 1000,
        jitter_max: float = 0.03,
    ):
        now = datetime.datetime.utcnow().replace(minute=0, second=0, microsecond=0)
        readings_per_meter = int((24 * 60 * days) / interval_minutes)
        total = num_meters * readings_per_meter
        rate = total / duration_s
        sleep_interval = 1.0 / rate

        print(f"[SIM] {total:,} readings over {duration_s}s ({rate:,.1f} rps)")
        buffer = []
        start = time.time()

        for m in range(1, num_meters + 1):
            for i in range(readings_per_meter):
                ts = now - datetime.timedelta(minutes=i * interval_minutes)
                val = round(random.uniform(0.1, 2.0), 3)
                payload = json.dumps({"meter_id": m, "timestamp": ts.isoformat(), "value": val})
                buffer.append(payload)

                if len(buffer) >= flush_every:
                    self.redis.enqueue_many(self.redis_key, buffer)
                    buffer.clear()

                time.sleep(sleep_interval + random.uniform(0, jitter_max))

        if buffer:
            self.redis.enqueue_many(self.redis_key, buffer)

        elapsed = time.time() - start
        print(f"[SIM] Completed {total:,} readings in {elapsed:.1f}s "
              f"({total/elapsed:,.1f} rps)")
