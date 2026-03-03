# Dashboard Showcase

This file documents the dashboard set built for the Smart Meter IoT platform.
Add screenshots for each panel/dashboard where marked.

## Data Sources Used
- Analytics API (`/v1/query/timeseries`, `/v1/query/statistics`) via signed HTTP calls
- CloudWatch metrics for ingestion/query operational health

## 1. Real-Time Dashboard Group

### A. Real-Time Meter (`real-time-meter.json`)
Purpose:
- near-live view of current, voltage, and energy behavior
- operator-facing monitoring for active ingest windows

Suggested screenshot:
- `screenshots/realtime-meter.png`

### B. Voltage Quality Band (`voltage-quality-band.json`)
Purpose:
- highlight voltage values against acceptable operating bands
- visually surface instability and excursions

Suggested screenshot:
- `screenshots/voltage-quality-band.png`

### C. Current Distribution (`current-distribution.json`)
Purpose:
- understand load profile distribution
- detect skew/heavy-tail behavior across sampled intervals

Suggested screenshot:
- `screenshots/current-distribution.png`

### D. Ingestion Lag & Throughput (`ingestion-lag-throughput.json`)
Purpose:
- track ingestion health and end-to-end pipeline behavior
- identify spikes, lag increases, or drops in ingestion rate

Suggested screenshot:
- `screenshots/ingestion-lag-throughput.png`

## 2. Historical / Analytics Dashboard Group

### A. Hot vs Cold Horizon (`hot-vs-cold-horizon.json`)
Purpose:
- compare recent high-resolution windows to long-range rolled-up history
- validate tiering behavior and route expectations

Suggested screenshot:
- `screenshots/hot-vs-cold-horizon.png`

### B. Fleet Health Overview (`fleet-health-overview.json`)
Purpose:
- aggregate fleet-level behavior and identify outliers quickly
- provide operational summary panel set

Suggested screenshot:
- `screenshots/fleet-health-overview.png`

### C. Meter Comparison Top 5 (`meter-comparison-top5.json`)
Purpose:
- compare highest-impact meters over selected interval
- identify concentration patterns in usage/load

Suggested screenshot:
- `screenshots/meter-comparison-top5.png`

### D. Percentile KPI (`percentile-kpi.json`)
Purpose:
- present statistical indicators (percentile-oriented KPIs)
- support trend + threshold interpretation

Suggested screenshot:
- `screenshots/percentile-kpi.png`

### E. Energy Consumption Trend (`enery-consumption-trend.json`)
Purpose:
- show energy trend and directional movement over time
- support reporting and planning views

Suggested screenshot:
- `screenshots/energy-consumption-trend.png`

## 3. Supporting Infra Dashboard

### Infra Health (`infra-health.json`)
Purpose:
- cloud resource-level health and runtime signal visibility
- quick correlation view for incidents

Suggested screenshot:
- `screenshots/infra-health.png`

## 4. How to Read This Dashboard Set
- Real-time group is for short-window operational awareness.
- Historical group is for trend, comparison, and statistical interpretation.
- Infra group supports root-cause investigation and service health checks.

## 5. Screenshot Checklist
Add the following image files when ready:
1. `screenshots/realtime-meter.png`
2. `screenshots/voltage-quality-band.png`
3. `screenshots/current-distribution.png`
4. `screenshots/ingestion-lag-throughput.png`
5. `screenshots/hot-vs-cold-horizon.png`
6. `screenshots/fleet-health-overview.png`
7. `screenshots/meter-comparison-top5.png`
8. `screenshots/percentile-kpi.png`
9. `screenshots/energy-consumption-trend.png`
10. `screenshots/infra-health.png`
