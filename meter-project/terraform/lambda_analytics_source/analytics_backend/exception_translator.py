import socket
import urllib.error
from abc import ABC, abstractmethod
from typing import Callable, Dict, List, Type


class ExceptionRule(ABC):
    @abstractmethod
    def can_handle(self, exc: Exception) -> bool:
        raise NotImplementedError

    @abstractmethod
    def handle(self, exc: Exception) -> Dict:
        raise NotImplementedError


class ValidationErrorRule(ExceptionRule):
    def __init__(self, response_fn: Callable[[int, Dict], Dict], emit_metric_fn: Callable[..., None], log_event_fn: Callable[..., None], validation_error_type: Type[Exception]):
        self._response = response_fn
        self._emit_metric = emit_metric_fn
        self._log_event = log_event_fn
        self._validation_error_type = validation_error_type

    def can_handle(self, exc: Exception) -> bool:
        return isinstance(exc, self._validation_error_type)

    def handle(self, exc: Exception) -> Dict:
        self._emit_metric("QueryError", 1)
        self._log_event("query_validation_error", error=str(exc))
        return self._response(400, {"message": str(exc)})


class UpstreamHttpErrorRule(ExceptionRule):
    def __init__(self, response_fn: Callable[[int, Dict], Dict], emit_metric_fn: Callable[..., None], log_event_fn: Callable[..., None]):
        self._response = response_fn
        self._emit_metric = emit_metric_fn
        self._log_event = log_event_fn

    def can_handle(self, exc: Exception) -> bool:
        return isinstance(exc, urllib.error.HTTPError)

    def handle(self, exc: Exception) -> Dict:
        body = exc.read().decode("utf-8") if hasattr(exc, "read") else ""
        self._emit_metric("QueryError", 1)
        self._log_event("query_upstream_http_error", status=exc.code, detail=body)
        return self._response(502, {"message": "Influx query failed", "status": exc.code})


class UpstreamUrlErrorRule(ExceptionRule):
    def __init__(self, response_fn: Callable[[int, Dict], Dict], emit_metric_fn: Callable[..., None], log_event_fn: Callable[..., None]):
        self._response = response_fn
        self._emit_metric = emit_metric_fn
        self._log_event = log_event_fn

    def can_handle(self, exc: Exception) -> bool:
        return isinstance(exc, urllib.error.URLError)

    def handle(self, exc: Exception) -> Dict:
        if isinstance(exc.reason, socket.timeout):
            self._emit_metric("QueryTimeout", 1)
            self._log_event("query_timeout")
            return self._response(504, {"message": "Influx query timeout"})

        self._emit_metric("QueryError", 1)
        self._log_event("query_upstream_connection_error", error=str(exc))
        return self._response(502, {"message": "Influx query connection failed"})


class TimeoutErrorRule(ExceptionRule):
    def __init__(self, response_fn: Callable[[int, Dict], Dict], emit_metric_fn: Callable[..., None], log_event_fn: Callable[..., None]):
        self._response = response_fn
        self._emit_metric = emit_metric_fn
        self._log_event = log_event_fn

    def can_handle(self, exc: Exception) -> bool:
        return isinstance(exc, (TimeoutError, socket.timeout))

    def handle(self, exc: Exception) -> Dict:
        self._emit_metric("QueryTimeout", 1)
        self._log_event("query_timeout")
        return self._response(504, {"message": "Influx query timeout"})


class FallbackErrorRule(ExceptionRule):
    def __init__(self, response_fn: Callable[[int, Dict], Dict], emit_metric_fn: Callable[..., None], log_event_fn: Callable[..., None]):
        self._response = response_fn
        self._emit_metric = emit_metric_fn
        self._log_event = log_event_fn

    def can_handle(self, exc: Exception) -> bool:
        return True

    def handle(self, exc: Exception) -> Dict:
        self._emit_metric("QueryError", 1)
        self._log_event("query_unhandled_error", error=str(exc))
        return self._response(500, {"message": "Internal server error"})


class ExceptionTranslator:
    def __init__(
        self,
        response_fn: Callable[[int, Dict], Dict],
        emit_metric_fn: Callable[..., None],
        log_event_fn: Callable[..., None],
        validation_error_type: Type[Exception],
    ):
        self._emit_metric = emit_metric_fn
        self._log_event = log_event_fn
        self._response = response_fn
        self._rules: List[ExceptionRule] = [
            ValidationErrorRule(response_fn, emit_metric_fn, log_event_fn, validation_error_type),
            UpstreamHttpErrorRule(response_fn, emit_metric_fn, log_event_fn),
            UpstreamUrlErrorRule(response_fn, emit_metric_fn, log_event_fn),
            TimeoutErrorRule(response_fn, emit_metric_fn, log_event_fn),
            FallbackErrorRule(response_fn, emit_metric_fn, log_event_fn),
        ]

    def translate(self, exc: Exception) -> Dict:
        for rule in self._rules:
            if rule.can_handle(exc):
                return rule.handle(exc)
        # Defensive fallback if rules are misconfigured.
        self._emit_metric("QueryError", 1)
        self._log_event("query_unhandled_error", error=str(exc))
        return self._response(500, {"message": "Internal server error"})
