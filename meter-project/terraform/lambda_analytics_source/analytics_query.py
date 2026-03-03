from functools import partial
from typing import Dict

from analytics_backend import (
    ALLOWED_QUERY_NAMES,
    ExceptionTranslator,
    FluxQueryBuilder,
    InfluxQueryClient,
    QueryHandlerService,
    RequestParser,
    RouteDispatcher,
    SeriesStats,
    SourceRangePlanner,
    ValidationError,
    emit_metric,
    iso_now,
    log_event,
    response,
)


_request_parser = RequestParser()
_source_range_planner = SourceRangePlanner()
_flux_query_builder = FluxQueryBuilder()
_influx_query_client = InfluxQueryClient()
_series_stats = SeriesStats()
_query_service = QueryHandlerService(
    parser=_request_parser,
    planner=_source_range_planner,
    build_flux_query_fn=_flux_query_builder.build,
    execute_flux_query_fn=_influx_query_client.execute,
    compute_stats_fn=_series_stats.compute,
)


def _handle_query(event: Dict, expected_query_name: str) -> Dict:
    return response(200, _query_service.handle(event, expected_query_name))


def _handle_health(_event: Dict) -> Dict:
    return response(
        200,
        {
            "status": "ok",
            "service": "analytics-query",
            "timestamp_utc": iso_now(),
            "supported_queries": sorted(ALLOWED_QUERY_NAMES),
        },
    )


_route_dispatcher = RouteDispatcher(
    route_key_handlers={
        "GET /health": _handle_health,
        "POST /query/timeseries": partial(_handle_query, expected_query_name="timeseries"),
        "POST /query/statistics": partial(_handle_query, expected_query_name="statistics"),
    },
    path_suffix_handlers=[
        ("GET", "/health", _handle_health),
        (None, "/query/timeseries", partial(_handle_query, expected_query_name="timeseries")),
        (None, "/query/statistics", partial(_handle_query, expected_query_name="statistics")),
    ],
)

_exception_translator = ExceptionTranslator(
    response_fn=response,
    emit_metric_fn=emit_metric,
    log_event_fn=log_event,
    validation_error_type=ValidationError,
)


def lambda_handler(event, context):
    try:
        routed = _route_dispatcher.dispatch(event)
        if routed is None:
            return response(404, {"message": "Route not found"})
        return routed
    except Exception as exc:
        return _exception_translator.translate(exc)
