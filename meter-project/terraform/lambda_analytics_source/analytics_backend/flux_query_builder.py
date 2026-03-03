import os
from datetime import datetime
from typing import Dict, List

from .common import escape_flux_string


class FluxQueryBuilder:
    def build(self, bucket: str, req: Dict, start: datetime, end: datetime) -> str:
        measurement_name = os.getenv("INFLUX_MEASUREMENT", "meter_readings")
        meter_filter = self._render_filter("meterId", req["meter_ids"])
        site_filter = self._render_filter("siteId", req["site_ids"])
        tag_filters = self._render_tag_filters(req["tag_filters"])
        field_filter = self._render_filter("_field", req["fields"])

        aggregate_clause = ""
        if req["mode"] == "aggregated":
            aggregate_clause = f'\n  |> aggregateWindow(every: {req["granularity"]}, fn: mean, createEmpty: false)'

        return f'''from(bucket: "{escape_flux_string(bucket)}")
  |> range(start: time(v: "{start.isoformat()}"), stop: time(v: "{end.isoformat()}"))
  |> filter(fn: (r) => r["_measurement"] == "{escape_flux_string(measurement_name)}"){field_filter}{meter_filter}{site_filter}{tag_filters}
{aggregate_clause}
  |> keep(columns: ["_time", "_value", "_field", "meterId", "siteId"])
  |> sort(columns: ["_time"])
  |> limit(n: {req["limit"]})
'''

    def _render_filter(self, column_name: str, values: List) -> str:
        if not values:
            return ""
        escaped_values = [f'r["{column_name}"] == "{escape_flux_string(str(value))}"' for value in values]
        return f"\n  |> filter(fn: (r) => {' or '.join(escaped_values)})"

    def _render_tag_filters(self, tag_filters: Dict) -> str:
        if not tag_filters:
            return ""

        lines = []
        for key, value in tag_filters.items():
            escaped_key = escape_flux_string(str(key))
            if isinstance(value, list):
                parts = [f'r["{escaped_key}"] == "{escape_flux_string(str(item))}"' for item in value]
                if parts:
                    lines.append(f"({' or '.join(parts)})")
            else:
                lines.append(f'r["{escaped_key}"] == "{escape_flux_string(str(value))}"')

        if not lines:
            return ""
        return f"\n  |> filter(fn: (r) => {' and '.join(lines)})"
