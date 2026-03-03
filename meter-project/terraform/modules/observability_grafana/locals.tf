locals {
  grafana_name = "${var.name_prefix}-grafana"
  influx_datasource_payload = jsonencode({
    name      = var.influx_datasource_name
    type      = "influxdb"
    access    = "proxy"
    url       = var.influx_query_url
    basicAuth = false
    jsonData = {
      version       = "Flux"
      organization  = var.influx_org
      defaultBucket = var.influx_default_bucket
    }
    secureJsonData = {
      token = "<set-via-grafana-api-or-ui>"
    }
  })
}
