# Container Monitoring Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

container_config = %{
  runtime: :podman,
  metrics: [
    :cpu_usage,
    :memory_usage,
    :network_io,
    :disk_io,
    :container_health,
    :image_vulnerabilities
  ],
  resource_limits: true,
  monitoring_interval: 15_000,
  health_checks: true,
  auto_restart: true
}
