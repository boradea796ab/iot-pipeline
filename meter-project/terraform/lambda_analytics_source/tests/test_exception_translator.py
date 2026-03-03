import io
import socket
import unittest
import urllib.error

from analytics_backend import ExceptionTranslator


class _ValidationError(Exception):
    pass


class ExceptionTranslatorTests(unittest.TestCase):
    def setUp(self):
        self.metrics = []
        self.events = []

        def response_fn(status_code, payload):
            return {"statusCode": status_code, "payload": payload}

        def emit_metric_fn(name, value, unit="Count"):
            self.metrics.append((name, value, unit))

        def log_event_fn(name, **kwargs):
            self.events.append((name, kwargs))

        self.translator = ExceptionTranslator(
            response_fn=response_fn,
            emit_metric_fn=emit_metric_fn,
            log_event_fn=log_event_fn,
            validation_error_type=_ValidationError,
        )

    def test_translate_validation_error(self):
        out = self.translator.translate(_ValidationError("bad input"))
        self.assertEqual(out["statusCode"], 400)
        self.assertEqual(out["payload"]["message"], "bad input")
        self.assertEqual(self.metrics[-1][0], "QueryError")
        self.assertEqual(self.events[-1][0], "query_validation_error")

    def test_translate_http_error(self):
        exc = urllib.error.HTTPError(
            url="https://example.com/query",
            code=503,
            msg="Service Unavailable",
            hdrs=None,
            fp=io.BytesIO(b"upstream down"),
        )
        out = self.translator.translate(exc)
        self.assertEqual(out["statusCode"], 502)
        self.assertEqual(out["payload"]["status"], 503)
        self.assertEqual(self.metrics[-1][0], "QueryError")
        self.assertEqual(self.events[-1][0], "query_upstream_http_error")

    def test_translate_url_error_timeout(self):
        exc = urllib.error.URLError(socket.timeout("timed out"))
        out = self.translator.translate(exc)
        self.assertEqual(out["statusCode"], 504)
        self.assertEqual(out["payload"]["message"], "Influx query timeout")
        self.assertEqual(self.metrics[-1][0], "QueryTimeout")
        self.assertEqual(self.events[-1][0], "query_timeout")

    def test_translate_url_error_connection(self):
        exc = urllib.error.URLError("conn refused")
        out = self.translator.translate(exc)
        self.assertEqual(out["statusCode"], 502)
        self.assertEqual(out["payload"]["message"], "Influx query connection failed")
        self.assertEqual(self.metrics[-1][0], "QueryError")
        self.assertEqual(self.events[-1][0], "query_upstream_connection_error")

    def test_translate_unhandled_error(self):
        out = self.translator.translate(RuntimeError("boom"))
        self.assertEqual(out["statusCode"], 500)
        self.assertEqual(out["payload"]["message"], "Internal server error")
        self.assertEqual(self.metrics[-1][0], "QueryError")
        self.assertEqual(self.events[-1][0], "query_unhandled_error")


if __name__ == "__main__":
    unittest.main()
