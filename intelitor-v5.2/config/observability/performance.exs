# Performance Monitoring Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

performance_config = %{
  response_time_targets: %{
    api_endpoints: "< 100ms",
    database_queries: "< 50ms",
    file_operations: "< 200ms",
    external_services: "< 500ms"
  },
  throughput_targets: %{
    database_connections: 100,
    requests_per_second: 1000,
    concurrent_users: 500
  },
  resource_limits: %{
    memory_usage: "< 2GB",
    cpu_utilization: "< 80%",
    disk_usage: "< 90%",
    network_bandwidth: "< 100Mbps"
  },
  monitoring_interval: 10_000
}
