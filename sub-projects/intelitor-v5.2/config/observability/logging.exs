# Logging Aggregation Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

logging_config = %{
  log_level: :info,
  structured_logging: true,
  formatters: [:json, :console],
  aggregation_targets: [:elasticsearch, :fluentd, :local_files],
  retention_policy: "90 days",
  log_categories: [:application, :security, :audit, :performance, :error, :debug]
}
