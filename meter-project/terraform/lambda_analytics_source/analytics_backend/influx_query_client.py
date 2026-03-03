import csv
import json
import os
import urllib.parse
import urllib.request
from typing import Dict, List


class InfluxQueryClient:
    def execute(self, flux_query: str, timeout_seconds: int) -> List[Dict]:
        influx_url = os.getenv("INFLUX_QUERY_API_URL")
        influx_token = os.getenv("INFLUX_READ_TOKEN")
        influx_org = os.getenv("INFLUX_ORG")

        if not influx_url or not influx_token or not influx_org:
            raise RuntimeError("Influx query configuration is missing")

        payload = {
            "query": flux_query,
            "type": "flux",
            "dialect": {
                "annotations": ["datatype", "group", "default"],
                "delimiter": ",",
                "header": True,
                "dateTimeFormat": "RFC3339",
            },
        }

        url = f"{influx_url}?org={urllib.parse.quote(influx_org)}"
        request = urllib.request.Request(
            url=url,
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers={
                "Authorization": f"Token {influx_token}",
                "Content-Type": "application/json",
                "Accept": "application/csv",
            },
        )

        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            csv_text = response.read().decode("utf-8")

        records = []
        lines = [line for line in csv_text.splitlines() if line and not line.startswith("#")]
        if not lines:
            return records

        reader = csv.DictReader(lines)
        for row in reader:
            raw_value = row.get("_value")
            if raw_value is None:
                continue
            try:
                value = float(raw_value)
            except ValueError:
                continue

            records.append(
                {
                    "timestamp": row.get("_time"),
                    "meter_id": row.get("meterId"),
                    "site_id": row.get("siteId"),
                    "field": row.get("_field"),
                    "value": value,
                }
            )

        return records
