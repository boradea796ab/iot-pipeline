import csv
import json
import logging
import os
import socket
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Tuple

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ALLOWED_GRANULARITIES = {"1m", "5m", "15m", "1h"}
HIGH_GRANULARITIES = {"1m", "5m"}
ALLOWED_QUERY_NAMES = {"timeseries", "statistics"}
DEFAULT_FIELDS = ["kWh", "voltage", "current"]


class ValidationError(Exception):
    pass


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        logger.warning("Invalid integer env var", extra={"env": name, "value": value})
        return default


def _response(status_code: int, payload: Dict) -> Dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }


def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_time(value: str) -> datetime:
    if not isinstance(value, str):
        raise ValidationError("Time values must be RFC3339 strings")

    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise ValidationError(f"Invalid RFC3339 timestamp: {value}") from exc

    if parsed.tzinfo is None:
        raise ValidationError(f"Timestamp must include timezone: {value}")

    return parsed.astimezone(timezone.utc)


def _escape_flux_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _emit_metric(metric_name: str, value: float, unit: str = "Count") -> None:
    emf = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": os.getenv("METRICS_NAMESPACE", "SmartMeter/AnalyticsQuery"),
                    "Dimensions": [["Service"]],
                    "Metrics": [{"Name": metric_name, "Unit": unit}],
                }
            ],
        },
        "Service": "analytics-query",
        metric_name: value,
    }
    logger.info(json.dumps(emf))


def _log_event(event_name: str, **kwargs) -> None:
    payload = {"event": event_name, "service": "analytics-query"}
    payload.update(kwargs)
    logger.info(json.dumps(payload, default=str))


def _parse_request(event: Dict, expected_query_name: str) -> Dict:
    body = event.get("body")
    if not body:
        raise ValidationError("Request body is required")

    try:
        parsed = json.loads(body)
    except json.JSONDecodeError as exc:
        raise ValidationError("Invalid JSON body") from exc

    query_name = parsed.get("query_name")
    if query_name != expected_query_name:
        raise ValidationError(f"query_name must be '{expected_query_name}'")

    if query_name not in ALLOWED_QUERY_NAMES:
        raise ValidationError("Unsupported query_name")

    time_range = parsed.get("time_range") or {}
    start = _parse_time(time_range.get("from"))
    end = _parse_time(time_range.get("to"))
    if end <= start:
        raise ValidationError("time_range.to must be after time_range.from")

    max_lookback_days = _env_int("MAX_LOOKBACK_DAYS", 370)
    lookback = datetime.now(timezone.utc) - timedelta(days=max_lookback_days)
    if start < lookback:
        raise ValidationError(f"Lookback exceeds MAX_LOOKBACK_DAYS={max_lookback_days}")

    granularity = parsed.get("granularity", "15m")
    if granularity not in ALLOWED_GRANULARITIES:
        raise ValidationError("granularity must be one of 1m|5m|15m|1h")

    timezone_value = parsed.get("timezone", "UTC")
    if timezone_value != "UTC":
        raise ValidationError("Only timezone='UTC' is supported in v1")

    filters = parsed.get("filters") or {}
    meter_ids = filters.get("meter_ids") or []
    if not isinstance(meter_ids, list):
        raise ValidationError("filters.meter_ids must be an array")

    max_meter_ids = _env_int("MAX_METER_IDS", 100)
    if len(meter_ids) > max_meter_ids:
        raise ValidationError(f"filters.meter_ids exceeds MAX_METER_IDS={max_meter_ids}")

    site_ids = filters.get("site_ids") or []
    if not isinstance(site_ids, list):
        raise ValidationError("filters.site_ids must be an array")

    tag_filters = filters.get("tags") or {}
    if not isinstance(tag_filters, dict):
        raise ValidationError("filters.tags must be an object")

    requested_fields = parsed.get("fields") or DEFAULT_FIELDS
    if not isinstance(requested_fields, list) or not requested_fields:
        raise ValidationError("fields must be a non-empty array when provided")

    max_limit = _env_int("MAX_SERIES_LIMIT", 5000)
    limit = parsed.get("limit", min(2000, max_limit))
    if not isinstance(limit, int) or limit <= 0:
        raise ValidationError("limit must be a positive integer")
    if limit > max_limit:
        raise ValidationError(f"limit exceeds MAX_SERIES_LIMIT={max_limit}")

    return {
        "query_name": query_name,
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


def _source_ranges(start: datetime, end: datetime, granularity: str) -> List[Tuple[str, datetime, datetime]]:
    hot_retention_days = _env_int("HOT_RETENTION_DAYS", 7)
    hot_cutoff = datetime.now(timezone.utc) - timedelta(days=hot_retention_days)

    if end <= hot_cutoff:
        return [("cold", start, end)]

    if start >= hot_cutoff:
        if granularity in HIGH_GRANULARITIES:
            return [("hot", start, end)]
        return [("cold", start, end)]

    ranges: List[Tuple[str, datetime, datetime]] = []
    if start < hot_cutoff:
        ranges.append(("cold", start, hot_cutoff))
    if end > hot_cutoff:
        ranges.append(("hot", hot_cutoff, end))
    return ranges


def _build_flux_query(bucket: str, req: Dict, start: datetime, end: datetime) -> str:
    measurement_name = os.getenv("INFLUX_MEASUREMENT", "meter_readings")

    meter_filter = ""
    if req["meter_ids"]:
        values = [f'r["meterId"] == "{_escape_flux_string(v)}"' for v in req["meter_ids"]]
        meter_filter = f"\n  |> filter(fn: (r) => {' or '.join(values)})"

    site_filter = ""
    if req["site_ids"]:
        values = [f'r["siteId"] == "{_escape_flux_string(v)}"' for v in req["site_ids"]]
        site_filter = f"\n  |> filter(fn: (r) => {' or '.join(values)})"

    tag_filters = ""
    if req["tag_filters"]:
        lines = []
        for key, value in req["tag_filters"].items():
            escaped_key = _escape_flux_string(str(key))
            if isinstance(value, list):
                parts = [f'r["{escaped_key}"] == "{_escape_flux_string(str(item))}"' for item in value]
                if parts:
                    lines.append(f"({' or '.join(parts)})")
            else:
                lines.append(f'r["{escaped_key}"] == "{_escape_flux_string(str(value))}"')
        if lines:
            tag_filters = f"\n  |> filter(fn: (r) => {' and '.join(lines)})"

    fields = [f'r["_field"] == "{_escape_flux_string(field)}"' for field in req["fields"]]
    field_filter = f"\n  |> filter(fn: (r) => {' or '.join(fields)})"

    flux = f'''from(bucket: "{_escape_flux_string(bucket)}")
  |> range(start: time(v: "{start.isoformat()}"), stop: time(v: "{end.isoformat()}"))
  |> filter(fn: (r) => r["_measurement"] == "{_escape_flux_string(measurement_name)}"){field_filter}{meter_filter}{site_filter}{tag_filters}
  |> aggregateWindow(every: {req["granularity"]}, fn: mean, createEmpty: false)
  |> keep(columns: ["_time", "_value", "_field", "meterId", "siteId"])
  |> sort(columns: ["_time"])
  |> limit(n: {req["limit"]})
'''
    return flux


def _execute_flux_query(flux_query: str, timeout_seconds: int) -> List[Dict]:
    influx_url = os.getenv("INFLUX_QUERY_API_URL")
    influx_token = os.getenv("INFLUX_READ_TOKEN")
    influx_org = os.getenv("INFLUX_ORG")

    if not influx_url or not influx_token or not influx_org:
        raise RuntimeError("Influx query configuration is missing")

    payload = {
        "query": flux_query,
        "type": "flux",
        "dialect": {
            "annotations": ["datatype", "group", "default"],
            "delimiter": ",",
            "header": True,
            "dateTimeFormat": "RFC3339",
        },
    }

    url = f"{influx_url}?org={urllib.parse.quote(influx_org)}"
    request = urllib.request.Request(
        url=url,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Token {influx_token}",
            "Content-Type": "application/json",
            "Accept": "application/csv",
        },
    )

    with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
        csv_text = response.read().decode("utf-8")

    records = []
    lines = [line for line in csv_text.splitlines() if line and not line.startswith("#")]
    if not lines:
        return records

    reader = csv.DictReader(lines)
    for row in reader:
        raw_value = row.get("_value")
        if raw_value is None:
            continue
        try:
            value = float(raw_value)
        except ValueError:
            continue

        records.append(
            {
                "timestamp": row.get("_time"),
                "meter_id": row.get("meterId"),
                "site_id": row.get("siteId"),
                "field": row.get("_field"),
                "value": value,
            }
        )

    return records


def _compute_stats(series: List[Dict]) -> Dict[str, Dict[str, float]]:
    values_by_field: Dict[str, List[float]] = {}

    for item in series:
        field = item.get("field")
        value = item.get("value")
        if field is None or value is None:
            continue
        values_by_field.setdefault(field, []).append(float(value))

    stats = {}
    for field, values in values_by_field.items():
        if not values:
            continue
        sorted_values = sorted(values)
        p95_index = int(round((len(sorted_values) - 1) * 0.95))
        stats[field] = {
            "min": min(values),
            "max": max(values),
            "avg": sum(values) / len(values),
            "p95": sorted_values[p95_index],
            "count": len(values),
        }

    return stats


def _handle_query(event: Dict, expected_query_name: str) -> Dict:
    started = time.time()
    timeout_seconds = _env_int("QUERY_TIMEOUT_SECONDS", 10)

    request_payload = _parse_request(event, expected_query_name)
    ranges = _source_ranges(
        start=request_payload["start"],
        end=request_payload["end"],
        granularity=request_payload["granularity"],
    )

    bucket_by_source = {
        "hot": os.getenv("INFLUX_HOT_BUCKET"),
        "cold": os.getenv("INFLUX_COLD_BUCKET"),
    }

    rows: List[Dict] = []
    sources_used: List[str] = []

    for source, start, end in ranges:
        bucket = bucket_by_source.get(source)
        if not bucket:
            raise RuntimeError(f"Bucket mapping missing for source '{source}'")

        flux = _build_flux_query(bucket=bucket, req=request_payload, start=start, end=end)
        source_rows = _execute_flux_query(flux, timeout_seconds=timeout_seconds)
        for item in source_rows:
            item["source"] = source
        rows.extend(source_rows)
        sources_used.append(source)

    rows.sort(key=lambda item: item.get("timestamp") or "")

    query_name = request_payload["query_name"]
    response_payload = {
        "meta": {
            "query_name": query_name,
            "executed_at": _iso_now(),
            "granularity": request_payload["granularity"],
            "partial_data": len(sources_used) > 1,
            "sources": sorted(set(sources_used)),
            "result_rows": len(rows),
        },
        "series": rows,
        "stats": {},
    }

    if query_name == "statistics":
        response_payload["stats"] = _compute_stats(rows)

    duration_ms = int((time.time() - started) * 1000)
    _log_event(
        "query_complete",
        query_name=query_name,
        range_from=request_payload["start"].isoformat(),
        range_to=request_payload["end"].isoformat(),
        meter_count=len(request_payload["meter_ids"]),
        granularity=request_payload["granularity"],
        duration_ms=duration_ms,
        result_rows=len(rows),
    )

    _emit_metric("QuerySuccess", 1)
    _emit_metric("RowsReturned", len(rows))
    _emit_metric("QueryDurationMs", duration_ms, unit="Milliseconds")

    return _response(200, response_payload)


def lambda_handler(event, context):
    request_context = event.get("requestContext", {})
    route_key = request_context.get("routeKey", "")
    http = request_context.get("http", {})
    method = http.get("method", "")
    raw_path = event.get("rawPath", "")

    try:
        if route_key == "GET /v1/health" or (method == "GET" and raw_path.endswith("/health")):
            return _response(
                200,
                {
                    "status": "ok",
                    "service": "analytics-query",
                    "timestamp_utc": _iso_now(),
                    "supported_queries": sorted(ALLOWED_QUERY_NAMES),
                },
            )

        if route_key == "POST /v1/query/timeseries" or raw_path.endswith("/query/timeseries"):
            return _handle_query(event, "timeseries")

        if route_key == "POST /v1/query/statistics" or raw_path.endswith("/query/statistics"):
            return _handle_query(event, "statistics")

        return _response(404, {"message": "Route not found"})

    except ValidationError as exc:
        _emit_metric("QueryError", 1)
        _log_event("query_validation_error", error=str(exc))
        return _response(400, {"message": str(exc)})

    except urllib.error.HTTPError as exc:
        _emit_metric("QueryError", 1)
        body = exc.read().decode("utf-8") if hasattr(exc, "read") else ""
        _log_event("query_upstream_http_error", status=exc.code, detail=body)
        return _response(502, {"message": "Influx query failed", "status": exc.code})

    except urllib.error.URLError as exc:
        if isinstance(exc.reason, socket.timeout):
            _emit_metric("QueryTimeout", 1)
            _log_event("query_timeout")
            return _response(504, {"message": "Influx query timeout"})
        _emit_metric("QueryError", 1)
        _log_event("query_upstream_connection_error", error=str(exc))
        return _response(502, {"message": "Influx query connection failed"})

    except (TimeoutError, socket.timeout):
        _emit_metric("QueryTimeout", 1)
        _log_event("query_timeout")
        return _response(504, {"message": "Influx query timeout"})

    except Exception as exc:
        _emit_metric("QueryError", 1)
        _log_event("query_unhandled_error", error=str(exc))
        return _response(500, {"message": "Internal server error"})
