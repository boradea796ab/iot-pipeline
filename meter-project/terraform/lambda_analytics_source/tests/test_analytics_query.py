import json
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import analytics_query


class AnalyticsQueryTests(unittest.TestCase):
    def setUp(self):
        os.environ["MAX_LOOKBACK_DAYS"] = "370"
        os.environ["MAX_METER_IDS"] = "5"
        os.environ["MAX_SERIES_LIMIT"] = "5000"
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
        parsed = analytics_query._parse_request(event, "timeseries")

        self.assertEqual(parsed["query_name"], "timeseries")
        self.assertEqual(parsed["granularity"], "1m")
        self.assertEqual(parsed["meter_ids"], ["meter-1"])

    def test_parse_request_rejects_invalid_query_name(self):
        payload = self._request_payload()
        payload["query_name"] = "statistics"
        event = {"body": json.dumps(payload)}

        with self.assertRaises(analytics_query.ValidationError):
            analytics_query._parse_request(event, "timeseries")

    def test_source_ranges_prefers_hot_for_high_granularity_recent_window(self):
        now = datetime.now(timezone.utc)
        ranges = analytics_query._source_ranges(
            start=now - timedelta(hours=2),
            end=now,
            granularity="1m",
        )

        self.assertEqual(len(ranges), 1)
        self.assertEqual(ranges[0][0], "hot")

    def test_source_ranges_splits_span_across_hot_and_cold(self):
        now = datetime.now(timezone.utc)
        ranges = analytics_query._source_ranges(
            start=now - timedelta(days=14),
            end=now,
            granularity="1m",
        )

        self.assertEqual([item[0] for item in ranges], ["cold", "hot"])

    def test_compute_stats_returns_expected_aggregates(self):
        series = [
            {"field": "kWh", "value": 1.0},
            {"field": "kWh", "value": 2.0},
            {"field": "kWh", "value": 3.0},
        ]

        stats = analytics_query._compute_stats(series)

        self.assertEqual(stats["kWh"]["min"], 1.0)
        self.assertEqual(stats["kWh"]["max"], 3.0)
        self.assertAlmostEqual(stats["kWh"]["avg"], 2.0)
        self.assertEqual(stats["kWh"]["count"], 3)

    @patch("analytics_query._execute_flux_query")
    def test_handle_query_returns_statistics_payload(self, mock_execute):
        mock_execute.return_value = [
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
            "requestContext": {"routeKey": "POST /v1/query/statistics"},
            "rawPath": "/v1/query/statistics",
        }

        os.environ["INFLUX_HOT_BUCKET"] = "hot"
        os.environ["INFLUX_COLD_BUCKET"] = "cold"

        response = analytics_query._handle_query(event, "statistics")
        body = json.loads(response["body"])

        self.assertEqual(response["statusCode"], 200)
        self.assertIn("stats", body)
        self.assertIn("kWh", body["stats"])


if __name__ == "__main__":
    unittest.main()
