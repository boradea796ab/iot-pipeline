from datetime import datetime
from typing import Dict, List, Tuple

from .common import (
    ALLOWED_GRANULARITIES,
    ALLOWED_MODES,
    ALLOWED_QUERY_NAMES,
    DEFAULT_FIELDS,
    ValidationError,
    env_int,
    lookback_cutoff,
    parse_time,
)


class RequestParser:
    def parse(self, event: Dict, expected_query_name: str) -> Dict:
        body = event.get("body")
        if not body:
            raise ValidationError("Request body is required")

        import json

        try:
            parsed = json.loads(body)
        except json.JSONDecodeError as exc:
            raise ValidationError("Invalid JSON body") from exc

        query_name = self._validate_query_name(parsed, expected_query_name)
        mode = self._validate_mode(parsed, query_name)
        start, end = self._validate_time_range(parsed)
        granularity = self._validate_granularity(parsed)
        timezone_value = self._validate_timezone(parsed)
        meter_ids, site_ids, tag_filters = self._validate_filters(parsed)
        requested_fields = self._validate_fields(parsed)
        limit = self._validate_limit(parsed, mode)
        self._validate_raw_window(mode, start, end)

        return {
            "query_name": query_name,
            "mode": mode,
            "start": start,
            "end": end,
            "granularity": granularity,
            "timezone": timezone_value,
            "meter_ids": meter_ids,
            "site_ids": site_ids,
            "tag_filters": tag_filters,
            "fields": requested_fields,
            "limit": limit,
        }

    def _validate_query_name(self, parsed: Dict, expected_query_name: str) -> str:
        query_name = parsed.get("query_name")
        if query_name != expected_query_name:
            raise ValidationError(f"query_name must be '{expected_query_name}'")
        if query_name not in ALLOWED_QUERY_NAMES:
            raise ValidationError("Unsupported query_name")
        return query_name

    def _validate_mode(self, parsed: Dict, query_name: str) -> str:
        mode = parsed.get("mode", "aggregated")
        if mode not in ALLOWED_MODES:
            raise ValidationError("mode must be one of aggregated|raw")
        if mode == "raw" and query_name != "timeseries":
            raise ValidationError("mode='raw' is supported only for query_name='timeseries'")
        return mode

    def _validate_time_range(self, parsed: Dict) -> Tuple[datetime, datetime]:
        time_range = parsed.get("time_range") or {}
        start = parse_time(time_range.get("from"))
        end = parse_time(time_range.get("to"))
        if end <= start:
            raise ValidationError("time_range.to must be after time_range.from")

        max_lookback_days = env_int("MAX_LOOKBACK_DAYS", 370)
        if start < lookback_cutoff(max_lookback_days):
            raise ValidationError(f"Lookback exceeds MAX_LOOKBACK_DAYS={max_lookback_days}")
        return start, end

    def _validate_granularity(self, parsed: Dict) -> str:
        granularity = parsed.get("granularity", "15m")
        if granularity not in ALLOWED_GRANULARITIES:
            raise ValidationError("granularity must be one of 1m|5m|15m|1h")
        return granularity

    def _validate_timezone(self, parsed: Dict) -> str:
        timezone_value = parsed.get("timezone", "UTC")
        if timezone_value != "UTC":
            raise ValidationError("Only timezone='UTC' is supported in v1")
        return timezone_value

    def _validate_filters(self, parsed: Dict) -> Tuple[List, List, Dict]:
        filters = parsed.get("filters") or {}
        meter_ids = filters.get("meter_ids") or []
        if not isinstance(meter_ids, list):
            raise ValidationError("filters.meter_ids must be an array")

        max_meter_ids = env_int("MAX_METER_IDS", 100)
        if len(meter_ids) > max_meter_ids:
            raise ValidationError(f"filters.meter_ids exceeds MAX_METER_IDS={max_meter_ids}")

        site_ids = filters.get("site_ids") or []
        if not isinstance(site_ids, list):
            raise ValidationError("filters.site_ids must be an array")

        tag_filters = filters.get("tags") or {}
        if not isinstance(tag_filters, dict):
            raise ValidationError("filters.tags must be an object")

        return meter_ids, site_ids, tag_filters

    def _validate_fields(self, parsed: Dict) -> List:
        requested_fields = parsed.get("fields") or DEFAULT_FIELDS
        if not isinstance(requested_fields, list) or not requested_fields:
            raise ValidationError("fields must be a non-empty array when provided")
        return requested_fields

    def _validate_limit(self, parsed: Dict, mode: str) -> int:
        max_limit = env_int("MAX_SERIES_LIMIT", 5000)
        max_raw_limit = env_int("MAX_RAW_SERIES_LIMIT", max_limit)
        effective_max_limit = max_raw_limit if mode == "raw" else max_limit
        default_limit = min(10000, effective_max_limit) if mode == "raw" else min(2000, effective_max_limit)

        limit = parsed.get("limit", default_limit)
        if not isinstance(limit, int) or limit <= 0:
            raise ValidationError("limit must be a positive integer")

        if limit > effective_max_limit:
            if mode == "raw":
                raise ValidationError(f"limit exceeds MAX_RAW_SERIES_LIMIT={max_raw_limit}")
            raise ValidationError(f"limit exceeds MAX_SERIES_LIMIT={max_limit}")

        return limit

    def _validate_raw_window(self, mode: str, start: datetime, end: datetime) -> None:
        if mode != "raw":
            return

        max_raw_window_minutes = env_int("MAX_RAW_WINDOW_MINUTES", 180)
        window_minutes = (end - start).total_seconds() / 60
        if window_minutes > max_raw_window_minutes:
            raise ValidationError(f"Raw mode window exceeds MAX_RAW_WINDOW_MINUTES={max_raw_window_minutes}")
