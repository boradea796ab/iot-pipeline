import json
import os
import unittest
from datetime import datetime, timedelta, timezone

import analytics_query
from analytics_backend import FluxQueryBuilder, QueryHandlerService, RequestParser, SeriesStats, SourceRangePlanner


class AnalyticsQueryTests(unittest.TestCase):
    def setUp(self):
        os.environ["MAX_LOOKBACK_DAYS"] = "370"
        os.environ["MAX_METER_IDS"] = "5"
        os.environ["MAX_SERIES_LIMIT"] = "5000"
        os.environ["MAX_RAW_SERIES_LIMIT"] = "8000"
        os.environ["MAX_RAW_WINDOW_MINUTES"] = "180"
        os.environ["HOT_RETENTION_DAYS"] = "7"

    def _request_payload(self):
        now = datetime.now(timezone.utc)
        return {
            "query_name": "timeseries",
            "time_range": {
                "from": (now - timedelta(hours=1)).isoformat(),
                "to": now.isoformat(),
            },
            "filters": {"meter_ids": ["meter-1"]},
            "granularity": "1m",
            "timezone": "UTC",
            "limit": 200,
        }

    def test_parse_request_accepts_valid_envelope(self):
        event = {"body": json.dumps(self._request_payload())}
        parsed = RequestParser().parse(event, "timeseries")

        self.assertEqual(parsed["query_name"], "timeseries")
        self.assertEqual(parsed["granularity"], "1m")
        self.assertEqual(parsed["meter_ids"], ["meter-1"])

    def test_parse_request_rejects_invalid_query_name(self):
        payload = self._request_payload()
        payload["query_name"] = "statistics"
        event = {"body": json.dumps(payload)}

        with self.assertRaises(analytics_query.ValidationError):
            RequestParser().parse(event, "timeseries")

    def test_source_ranges_prefers_hot_for_high_granularity_recent_window(self):
        now = datetime.now(timezone.utc)
        ranges = SourceRangePlanner().plan(
            start=now - timedelta(hours=2),
            end=now,
            granularity="1m",
            mode="aggregated",
        )

        self.assertEqual(len(ranges), 1)
        self.assertEqual(ranges[0][0], "hot")

    def test_source_ranges_splits_span_across_hot_and_cold(self):
        now = datetime.now(timezone.utc)
        ranges = SourceRangePlanner().plan(
            start=now - timedelta(days=14),
            end=now,
            granularity="1m",
            mode="aggregated",
        )

        self.assertEqual([item[0] for item in ranges], ["cold", "hot"])

    def test_parse_request_accepts_raw_mode_for_timeseries(self):
        payload = self._request_payload()
        payload["mode"] = "raw"
        event = {"body": json.dumps(payload)}

        parsed = RequestParser().parse(event, "timeseries")

        self.assertEqual(parsed["mode"], "raw")

    def test_parse_request_rejects_raw_mode_for_statistics(self):
        now = datetime.now(timezone.utc)
        payload = {
            "query_name": "statistics",
            "mode": "raw",
            "time_range": {
                "from": (now - timedelta(hours=1)).isoformat(),
                "to": now.isoformat(),
            },
            "granularity": "1m",
            "timezone": "UTC",
            "limit": 100,
        }
        event = {"body": json.dumps(payload)}

        with self.assertRaises(analytics_query.ValidationError):
            RequestParser().parse(event, "statistics")

    def test_parse_request_rejects_raw_window_over_limit(self):
        now = datetime.now(timezone.utc)
        payload = self._request_payload()
        payload["mode"] = "raw"
        payload["time_range"] = {
            "from": (now - timedelta(hours=4)).isoformat(),
            "to": now.isoformat(),
        }
        event = {"body": json.dumps(payload)}

        with self.assertRaises(analytics_query.ValidationError):
            RequestParser().parse(event, "timeseries")

    def test_source_ranges_raw_rejects_start_outside_hot_window(self):
        now = datetime.now(timezone.utc)

        with self.assertRaises(analytics_query.ValidationError):
            SourceRangePlanner().plan(
                start=now - timedelta(days=8),
                end=now,
                granularity="1m",
                mode="raw",
            )

    def test_build_flux_query_raw_does_not_aggregate(self):
        now = datetime.now(timezone.utc)
        req = {
            "mode": "raw",
            "fields": ["current"],
            "meter_ids": ["meter-1"],
            "site_ids": [],
            "tag_filters": {},
            "granularity": "1m",
            "limit": 100,
        }

        flux = FluxQueryBuilder().build(
            bucket="hot",
            req=req,
            start=now - timedelta(minutes=5),
            end=now,
        )

        self.assertNotIn("aggregateWindow", flux)

    def test_compute_stats_returns_expected_aggregates(self):
        series = [
            {"field": "kWh", "value": 1.0},
            {"field": "kWh", "value": 2.0},
            {"field": "kWh", "value": 3.0},
        ]

        stats = SeriesStats().compute(series)

        self.assertEqual(stats["kWh"]["min"], 1.0)
        self.assertEqual(stats["kWh"]["max"], 3.0)
        self.assertAlmostEqual(stats["kWh"]["avg"], 2.0)
        self.assertEqual(stats["kWh"]["count"], 3)

    def test_handle_query_returns_statistics_payload(self):
        mock_rows = [
            {
                "timestamp": "2026-02-28T00:00:00Z",
                "meter_id": "meter-1",
                "site_id": "site-1",
                "field": "kWh",
                "value": 10.0,
            }
        ]

        now = datetime.now(timezone.utc)
        payload = {
            "query_name": "statistics",
            "time_range": {
                "from": (now - timedelta(hours=1)).isoformat(),
                "to": now.isoformat(),
            },
            "filters": {"meter_ids": ["meter-1"]},
            "granularity": "15m",
            "timezone": "UTC",
            "limit": 100,
        }
        event = {
            "body": json.dumps(payload),
            "requestContext": {"routeKey": "POST /query/statistics"},
            "rawPath": "/v1/query/statistics",
        }

        os.environ["INFLUX_HOT_BUCKET"] = "hot"
        os.environ["INFLUX_COLD_BUCKET"] = "cold"

        service = QueryHandlerService(
            parser=RequestParser(),
            planner=SourceRangePlanner(),
            build_flux_query_fn=FluxQueryBuilder().build,
            execute_flux_query_fn=lambda flux_query, timeout_seconds: mock_rows,
            compute_stats_fn=SeriesStats().compute,
        )
        response = analytics_query.response(200, service.handle(event, "statistics"))
        body = json.loads(response["body"])

        self.assertEqual(response["statusCode"], 200)
        self.assertIn("stats", body)
        self.assertIn("kWh", body["stats"])


if __name__ == "__main__":
    unittest.main()
