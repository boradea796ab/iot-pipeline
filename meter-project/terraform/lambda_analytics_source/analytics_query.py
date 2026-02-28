import json
from datetime import datetime, timezone


def _response(status_code, payload):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }


def lambda_handler(event, context):
    request_context = event.get("requestContext", {})
    http = request_context.get("http", {})
    method = http.get("method", "")
    path = event.get("rawPath", "")

    if method == "GET" and path.endswith("/health"):
        return _response(
            200,
            {
                "status": "ok",
                "service": "analytics-query",
                "mode": "stub",
                "timestamp_utc": datetime.now(timezone.utc).isoformat(),
            },
        )

    if method == "POST" and path.endswith("/query"):
        body = event.get("body")
        parsed_body = None
        if body:
            try:
                parsed_body = json.loads(body)
            except json.JSONDecodeError:
                return _response(400, {"message": "Invalid JSON body"})

        return _response(
            200,
            {
                "message": "Stub analytics query service. No Influx query executed.",
                "request_echo": parsed_body,
            },
        )

    return _response(404, {"message": "Route not found"})
