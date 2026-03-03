import os
import time
from typing import Callable, Dict, List

from .common import emit_metric, env_int, iso_now, log_event


class QueryHandlerService:
    def __init__(
        self,
        parser,
        planner,
        build_flux_query_fn: Callable,
        execute_flux_query_fn: Callable,
        compute_stats_fn: Callable,
    ):
        self._parser = parser
        self._planner = planner
        self._build_flux_query_fn = build_flux_query_fn
        self._execute_flux_query_fn = execute_flux_query_fn
        self._compute_stats_fn = compute_stats_fn

    def handle(self, event: Dict, expected_query_name: str) -> Dict:
        started = time.time()
        timeout_seconds = env_int("QUERY_TIMEOUT_SECONDS", 10)

        request_payload = self._parser.parse(event, expected_query_name)
        ranges = self._planner.plan(
            start=request_payload["start"],
            end=request_payload["end"],
            granularity=request_payload["granularity"],
            mode=request_payload["mode"],
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

            flux = self._build_flux_query_fn(bucket=bucket, req=request_payload, start=start, end=end)
            source_rows = self._execute_flux_query_fn(flux, timeout_seconds=timeout_seconds)
            for item in source_rows:
                item["source"] = source
            rows.extend(source_rows)
            sources_used.append(source)

        rows.sort(key=lambda item: item.get("timestamp") or "")

        query_name = request_payload["query_name"]
        response_payload = {
            "meta": {
                "query_name": query_name,
                "mode": request_payload["mode"],
                "executed_at": iso_now(),
                "granularity": request_payload["granularity"],
                "partial_data": len(sources_used) > 1,
                "sources": sorted(set(sources_used)),
                "result_rows": len(rows),
            },
            "series": rows,
            "stats": {},
        }

        if query_name == "statistics":
            response_payload["stats"] = self._compute_stats_fn(rows)

        duration_ms = int((time.time() - started) * 1000)
        log_event(
            "query_complete",
            query_name=query_name,
            range_from=request_payload["start"].isoformat(),
            range_to=request_payload["end"].isoformat(),
            meter_count=len(request_payload["meter_ids"]),
            mode=request_payload["mode"],
            granularity=request_payload["granularity"],
            duration_ms=duration_ms,
            result_rows=len(rows),
        )

        emit_metric("QuerySuccess", 1)
        emit_metric("RowsReturned", len(rows))
        emit_metric("QueryDurationMs", duration_ms, unit="Milliseconds")

        return response_payload
