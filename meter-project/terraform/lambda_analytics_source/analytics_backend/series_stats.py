from typing import Dict, List


class SeriesStats:
    def compute(self, series: List[Dict]) -> Dict[str, Dict[str, float]]:
        values_by_field: Dict[str, List[float]] = {}

        for item in series:
            field = item.get("field")
            value = item.get("value")
            if field is None or value is None:
                continue
            values_by_field.setdefault(field, []).append(float(value))

        stats = {}
        for field, values in values_by_field.items():
            if not values:
                continue
            sorted_values = sorted(values)
            p95_index = int(round((len(sorted_values) - 1) * 0.95))
            stats[field] = {
                "min": min(values),
                "max": max(values),
                "avg": sum(values) / len(values),
                "p95": sorted_values[p95_index],
                "count": len(values),
            }

        return stats
