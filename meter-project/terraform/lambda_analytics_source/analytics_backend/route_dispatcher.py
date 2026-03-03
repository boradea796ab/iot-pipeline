from typing import Callable, Dict, List, Optional, Tuple


class RouteDispatcher:
    def __init__(
        self,
        route_key_handlers: Dict[str, Callable[[Dict], Dict]],
        path_suffix_handlers: List[Tuple[Optional[str], str, Callable[[Dict], Dict]]],
    ):
        self._route_key_handlers = route_key_handlers
        self._path_suffix_handlers = path_suffix_handlers

    def dispatch(self, event: Dict) -> Optional[Dict]:
        request_context = event.get("requestContext", {})
        route_key = request_context.get("routeKey", "")
        handler = self._route_key_handlers.get(route_key)
        if handler:
            return handler(event)

        raw_path = event.get("rawPath", "")
        method = (request_context.get("http", {}) or {}).get("method", "")

        for expected_method, suffix, fallback_handler in self._path_suffix_handlers:
            if expected_method and method != expected_method:
                continue
            if raw_path.endswith(suffix):
                return fallback_handler(event)

        return None
