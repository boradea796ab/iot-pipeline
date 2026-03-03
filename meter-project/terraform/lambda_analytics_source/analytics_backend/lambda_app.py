from functools import partial
from typing import Callable, Dict

from .common import ALLOWED_QUERY_NAMES, ValidationError, emit_metric, iso_now, log_event, response
from .exception_translator import ExceptionTranslator
from .flux_query_builder import FluxQueryBuilder
from .influx_query_client import InfluxQueryClient
from .query_handler_service import QueryHandlerService
from .request_parser import RequestParser
from .route_dispatcher import RouteDispatcher
from .series_stats import SeriesStats
from .source_range_planner import SourceRangePlanner


def create_lambda_handler() -> Callable[[Dict, object], Dict]:
    request_parser = RequestParser()
    source_range_planner = SourceRangePlanner()
    flux_query_builder = FluxQueryBuilder()
    influx_query_client = InfluxQueryClient()
    series_stats = SeriesStats()

    query_service = QueryHandlerService(
        parser=request_parser,
        planner=source_range_planner,
        build_flux_query_fn=flux_query_builder.build,
        execute_flux_query_fn=influx_query_client.execute,
        compute_stats_fn=series_stats.compute,
    )

    def handle_query(event: Dict, expected_query_name: str) -> Dict:
        return response(200, query_service.handle(event, expected_query_name))

    def handle_health(_event: Dict) -> Dict:
        return response(
            200,
            {
                "status": "ok",
                "service": "analytics-query",
                "timestamp_utc": iso_now(),
                "supported_queries": sorted(ALLOWED_QUERY_NAMES),
            },
        )

    route_dispatcher = RouteDispatcher(
        route_key_handlers={
            "GET /health": handle_health,
            "POST /query/timeseries": partial(handle_query, expected_query_name="timeseries"),
            "POST /query/statistics": partial(handle_query, expected_query_name="statistics"),
        },
        path_suffix_handlers=[
            ("GET", "/health", handle_health),
            (None, "/query/timeseries", partial(handle_query, expected_query_name="timeseries")),
            (None, "/query/statistics", partial(handle_query, expected_query_name="statistics")),
        ],
    )

    exception_translator = ExceptionTranslator(
        response_fn=response,
        emit_metric_fn=emit_metric,
        log_event_fn=log_event,
        validation_error_type=ValidationError,
    )

    def handler(event, context):
        try:
            routed = route_dispatcher.dispatch(event)
            if routed is None:
                return response(404, {"message": "Route not found"})
            return routed
        except Exception as exc:
            return exception_translator.translate(exc)

    return handler


lambda_handler = create_lambda_handler()
