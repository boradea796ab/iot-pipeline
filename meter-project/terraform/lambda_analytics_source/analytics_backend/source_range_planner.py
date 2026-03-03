from datetime import datetime
from typing import List, Tuple

from .common import HIGH_GRANULARITIES, ValidationError, env_int, hot_cutoff


class SourceRangePlanner:
    def plan(self, start: datetime, end: datetime, granularity: str, mode: str) -> List[Tuple[str, datetime, datetime]]:
        cutoff = hot_cutoff(env_int("HOT_RETENTION_DAYS", 7))

        if mode == "raw":
            if start < cutoff:
                raise ValidationError("mode='raw' supports only recent data in hot retention window")
            return [("hot", start, end)]

        if end <= cutoff:
            return [("cold", start, end)]

        if start >= cutoff:
            if granularity in HIGH_GRANULARITIES:
                return [("hot", start, end)]
            return [("cold", start, end)]

        ranges: List[Tuple[str, datetime, datetime]] = []
        if start < cutoff:
            ranges.append(("cold", start, cutoff))
        if end > cutoff:
            ranges.append(("hot", cutoff, end))
        return ranges
