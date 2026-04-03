# Alerting System Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

alerting_config = %{
  alert_channels: [:email, :slack, :pagerduty, :webhook],
  alert_categories: [
    :critical_errors,
    :performance_degradation,
    :security_incidents,
    :resource_exhaustion,
    :service_unavailability
  ],
  escalation_rules: %{
    high: "5 minutes",
    low: "4 hours",
    critical: "immediate",
    medium: "30 minutes"
  },
  alert_retention: "30 days"
}
