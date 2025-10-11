import redis

class RedisService:
    """Infrastructure wrapper for Redis to decouple low-level ops."""

    def __init__(self, url):
        self.url = url
        self.client = redis.StrictRedis.from_url(url, decode_responses=True)

    def enqueue_many(self, key: str, items: list[str]):
        """Push many items efficiently."""
        pipe = self.client.pipeline(transaction=False)
        for item in items:
            pipe.rpush(key, item)
        pipe.execute()

    def dequeue_blocking(self, key: str, timeout: int):
        """Blocking pop (used by consumer)."""
        return self.client.blpop(key, timeout=timeout)
