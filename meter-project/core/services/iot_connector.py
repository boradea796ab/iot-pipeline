import time
from django.db import transaction, close_old_connections
from core.models import Reading

class IOTConnector:
    """Domain service for persisting IoT readings into the DB."""

    def flush_to_db(self, batch: list[dict]) -> int:
        if not batch:
            return 0
        close_old_connections()
        start = time.time()
        with transaction.atomic():
            Reading.objects.bulk_create(
                [Reading(**d) for d in batch],
                batch_size=len(batch),
                ignore_conflicts=True,
            )
        duration = time.time() - start
        print(f"[DB FLUSH] {len(batch)} rows in {duration:.2f}s")
        return len(batch)
