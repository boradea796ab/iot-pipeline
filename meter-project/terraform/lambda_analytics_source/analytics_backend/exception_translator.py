import socket
import urllib.error
from typing import Callable, Dict, Type


class ExceptionTranslator:
    def __init__(
        self,
        response_fn: Callable[[int, Dict], Dict],
        emit_metric_fn: Callable[..., None],
        log_event_fn: Callable[..., None],
        validation_error_type: Type[Exception],
    ):
        self._response = response_fn
        self._emit_metric = emit_metric_fn
        self._log_event = log_event_fn
        self._validation_error_type = validation_error_type

    def translate(self, exc: Exception) -> Dict:
        if isinstance(exc, self._validation_error_type):
            self._emit_metric("QueryError", 1)
            self._log_event("query_validation_error", error=str(exc))
            return self._response(400, {"message": str(exc)})

        if isinstance(exc, urllib.error.HTTPError):
            self._emit_metric("QueryError", 1)
            body = exc.read().decode("utf-8") if hasattr(exc, "read") else ""
            self._log_event("query_upstream_http_error", status=exc.code, detail=body)
            return self._response(502, {"message": "Influx query failed", "status": exc.code})

        if isinstance(exc, urllib.error.URLError):
            if isinstance(exc.reason, socket.timeout):
                self._emit_metric("QueryTimeout", 1)
                self._log_event("query_timeout")
                return self._response(504, {"message": "Influx query timeout"})

            self._emit_metric("QueryError", 1)
            self._log_event("query_upstream_connection_error", error=str(exc))
            return self._response(502, {"message": "Influx query connection failed"})

        if isinstance(exc, (TimeoutError, socket.timeout)):
            self._emit_metric("QueryTimeout", 1)
            self._log_event("query_timeout")
            return self._response(504, {"message": "Influx query timeout"})

        self._emit_metric("QueryError", 1)
        self._log_event("query_unhandled_error", error=str(exc))
        return self._response(500, {"message": "Internal server error"})
