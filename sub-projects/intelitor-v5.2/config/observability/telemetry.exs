# Telemetry Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

telemetry_config = %{
  metrics: [
    :request_duration,
    :request_count,
    :error_rate,
    :memory_usage,
    :cpu_utilization,
    :database_connections,
    :cache_hit_ratio,
    :security_events
  ],
  aggregation_interval: 30_000,
  retention_period: "30 days",
  export_targets: [:prometheus, :grafana, :custom_dashboard]
}
