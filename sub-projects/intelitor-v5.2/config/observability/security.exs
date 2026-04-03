# Security Monitoring Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

security_config = %{
  security_events: [
    :authentication_failures,
    :unauthorized_access,
    :privilege_escalation,
    :data_exfiltration,
    :malware_detection
  ],
  threat_detection: true,
  intrusion_monitoring: true,
  vulnerability_scanning: true,
  compliance_checking: true,
  incident_response: true,
  alert_sensitivity: :high
}
