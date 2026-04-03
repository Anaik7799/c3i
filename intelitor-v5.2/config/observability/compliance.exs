# Compliance Tracking Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

compliance_config = %{
  frameworks: [:owasp, :iso27001, :dpdp_act, :sia_dc09],
  audit_logging: true,
  automated_checks: true,
  reporting_frequency: "monthly",
  compliance_score_tracking: true,
  evidence_collection: true
}
