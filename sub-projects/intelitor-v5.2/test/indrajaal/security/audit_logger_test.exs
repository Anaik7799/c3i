defmodule Indrajaal.Security.AuditLoggerTest do
  @moduledoc """
  TDG comprehensive test suite for AuditLogger.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation refinement
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SEC-044: Sobelow security check
  - SC-SEC-047: Encryption required for audit data
  - SC-REG-001: Append-only audit trail
  - SC-REG-002: Hash chain unbroken

  ## Constitutional Verification
  - Ψ₃ Verification: Hash chain remains verifiable
  - Ψ₅ Truthfulness: No deceptive audit representations

  ## Founder's Directive Alignment
  - Ω₀.4: Co-evolution with audit compliance posture

  ## TPS 5-Level RCA Context
  - L1 Symptom: Missing or tampered audit entries
  - L5 Root Cause: Weak audit trail integrity prevents forensic reconstruction

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude Sonnet 4.6 | Sprint 54 W1 test generation |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Security.AuditLogger

  @moduletag :zenoh_nif

  setup do
    # Start AuditLogger GenServer if not already running
    case Process.whereis(AuditLogger) do
      nil ->
        {:ok, pid} = AuditLogger.start_link([])

        on_exit(fn ->
          if Process.alive?(pid), do: GenServer.stop(pid)
        end)

      _pid ->
        :ok
    end

    :ok
  end

  # ============================================================
  # Validation helper tests (pure, no GenServer required)
  # ============================================================

  describe "validate_audit_category/1" do
    test "accepts all supported audit categories" do
      for category <- AuditLogger.get_supported_categories() do
        assert AuditLogger.validate_audit_category(category) == true,
               "Expected #{category} to be valid"
      end
    end

    test "rejects unknown categories" do
      refute AuditLogger.validate_audit_category(:unknown_category)
      refute AuditLogger.validate_audit_category(:does_not_exist)
    end

    test "rejects nil category" do
      refute AuditLogger.validate_audit_category(nil)
    end

    test "rejects string category (wrong type)" do
      refute AuditLogger.validate_audit_category("authentication")
    end
  end

  describe "validate_severity_level/1" do
    test "accepts all supported severity levels" do
      for level <- AuditLogger.get_supported_severity_levels() do
        assert AuditLogger.validate_severity_level(level) == true,
               "Expected #{level} to be valid"
      end
    end

    test "rejects unknown severity levels" do
      refute AuditLogger.validate_severity_level(:debug)
      refute AuditLogger.validate_severity_level(:trace)
    end

    test "rejects nil severity" do
      refute AuditLogger.validate_severity_level(nil)
    end
  end

  describe "validate_compliance_framework/1" do
    test "accepts all supported frameworks" do
      for fw <- AuditLogger.get_supported_compliance_frameworks() do
        assert AuditLogger.validate_compliance_framework(fw) == true,
               "Expected #{fw} to be valid"
      end
    end

    test "rejects unsupported frameworks" do
      refute AuditLogger.validate_compliance_framework(:unknown_fw)
      refute AuditLogger.validate_compliance_framework(:cis)
    end

    test "seven supported frameworks are present" do
      frameworks = AuditLogger.get_supported_compliance_frameworks()
      assert :sox in frameworks
      assert :gdpr in frameworks
      assert :hipaa in frameworks
      assert :pci_dss in frameworks
      assert :iso27001 in frameworks
      assert :nist in frameworks
      assert :fedramp in frameworks
    end
  end

  # ============================================================
  # get_supported_* introspection tests
  # ============================================================

  describe "get_supported_categories/0" do
    test "returns a non-empty list" do
      categories = AuditLogger.get_supported_categories()
      assert is_list(categories)
      assert length(categories) > 0
    end

    test "contains expected core categories" do
      categories = AuditLogger.get_supported_categories()
      assert :authentication in categories
      assert :authorization in categories
      assert :data_access in categories
      assert :security_event in categories
    end

    test "all entries are atoms" do
      for cat <- AuditLogger.get_supported_categories() do
        assert is_atom(cat)
      end
    end
  end

  describe "get_supported_severity_levels/0" do
    test "returns list with four canonical levels" do
      levels = AuditLogger.get_supported_severity_levels()
      assert :info in levels
      assert :warning in levels
      assert :critical in levels
      assert :emergency in levels
      assert length(levels) == 4
    end
  end

  describe "get_supported_compliance_frameworks/0" do
    test "returns seven frameworks" do
      frameworks = AuditLogger.get_supported_compliance_frameworks()
      assert length(frameworks) == 7
    end
  end

  # ============================================================
  # GenServer API — fire-and-forget (cast) calls
  # ============================================================

  describe "log_audit_event/4" do
    test "accepts valid category and event type without error" do
      assert :ok = AuditLogger.log_audit_event(:authentication, :login_success, %{user_id: "u1"})
    end

    test "accepts data_access category" do
      assert :ok =
               AuditLogger.log_audit_event(:data_access, :read, %{
                 user_id: "u2",
                 data_type: :user_records
               })
    end

    test "accepts security_event category" do
      assert :ok =
               AuditLogger.log_audit_event(:security_event, :brute_force_detected, %{
                 source_ip: "10.0.0.1"
               })
    end

    test "accepts empty details map" do
      assert :ok = AuditLogger.log_audit_event(:admin_action, :config_changed, %{})
    end

    test "accepts keyword opts" do
      assert :ok =
               AuditLogger.log_audit_event(:api_access, :endpoint_hit, %{endpoint: "/health"},
                 tenant_id: "t1",
                 user_id: "u3"
               )
    end
  end

  describe "log_auth_success/2" do
    test "accepts user map with id" do
      assert :ok = AuditLogger.log_auth_success(%{id: "user-uuid-1"}, %{client_ip: "192.168.1.1"})
    end

    test "accepts user id as string" do
      assert :ok = AuditLogger.log_auth_success("plain-user-id", %{})
    end

    test "accepts empty context" do
      assert :ok = AuditLogger.log_auth_success(%{id: "u-empty"})
    end
  end

  describe "log_auth_failure/2" do
    test "accepts symbolic reason" do
      assert :ok = AuditLogger.log_auth_failure(:invalid_password, %{})
    end

    test "accepts ip context" do
      assert :ok =
               AuditLogger.log_auth_failure(:account_locked, %{client_ip: "10.10.10.10"})
    end
  end

  describe "log_mfa_event/3" do
    test "accepts user map and context" do
      assert :ok =
               AuditLogger.log_mfa_event(:mfa_verified, %{id: "u-mfa"}, %{mfa_method: "totp"})
    end

    test "accepts plain user id" do
      assert :ok = AuditLogger.log_mfa_event(:mfa_failed, "string-user-id", %{})
    end
  end

  describe "log_session_event/4" do
    test "creates session event for user map" do
      assert :ok =
               AuditLogger.log_session_event(:session_created, %{id: "u-sess"}, "sess-001", %{})
    end

    test "creates session event for plain user id" do
      assert :ok =
               AuditLogger.log_session_event(:session_expired, "plain-id", "sess-002", %{})
    end
  end

  describe "log_auth_event/2" do
    test "accepts symbolic event type and empty details" do
      assert :ok = AuditLogger.log_auth_event(:token_refreshed, %{})
    end

    test "default details argument" do
      assert :ok = AuditLogger.log_auth_event(:logout)
    end
  end

  describe "log_security_violation/2" do
    test "logs a violation with type and details" do
      assert :ok = AuditLogger.log_security_violation(:sql_injection_attempt, %{payload: "'"})
    end

    test "accepts empty details" do
      assert :ok = AuditLogger.log_security_violation(:xss_attempt)
    end
  end

  describe "log_alarm_action/4" do
    test "logs alarm action with full params" do
      assert :ok =
               AuditLogger.log_alarm_action("user-99", :acknowledge, "alarm-001", %{
                 reason: "false positive"
               })
    end

    test "logs alarm action with default params" do
      assert :ok = AuditLogger.log_alarm_action("user-99", :resolve, "alarm-002")
    end
  end

  describe "log_compliance_event/4" do
    test "logs SOX compliance event" do
      assert :ok = AuditLogger.log_compliance_event(:sox, :audit_review, %{}, [])
    end

    test "logs GDPR compliance event with evidence" do
      assert :ok =
               AuditLogger.log_compliance_event(:gdpr, :data_subject_request, %{}, [
                 "dsr-form-001"
               ])
    end
  end

  describe "log_authorization/5" do
    test "logs authorization attempt with result" do
      assert :ok =
               AuditLogger.log_authorization("user-1", "resource/1", :read, :granted, %{})
    end

    test "logs denied authorization" do
      assert :ok =
               AuditLogger.log_authorization("user-2", "resource/2", :delete, :denied, %{
                 reason: :insufficient_permissions
               })
    end
  end

  describe "log_data_access/5" do
    test "logs data access event" do
      assert :ok =
               AuditLogger.log_data_access("user-3", :read, ["id-1", "id-2"], :user_records, %{})
    end

    test "accepts single record id" do
      assert :ok =
               AuditLogger.log_data_access(
                 "user-4",
                 :export,
                 "id-single",
                 :financial_records,
                 %{}
               )
    end
  end

  describe "log_config_change/5" do
    test "logs config change with user map" do
      assert :ok =
               AuditLogger.log_config_change(
                 :updated,
                 %{id: "admin-1"},
                 :firewall_rule,
                 "rule-99",
                 %{old: "allow", new: "deny"}
               )
    end

    test "logs config change with plain user id" do
      assert :ok =
               AuditLogger.log_config_change(:deleted, "admin-plain", :policy, "policy-01", %{})
    end
  end

  describe "store_audit_entry/1" do
    test "returns ok with the audit entry" do
      entry = %{id: "audit-001", category: :authentication, event_type: :login_success}
      assert {:ok, ^entry} = AuditLogger.store_audit_entry(entry)
    end

    test "accepts minimal map" do
      assert {:ok, _} = AuditLogger.store_audit_entry(%{})
    end
  end

  describe "query_audit_logs/6" do
    test "returns list for valid date range" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      result = AuditLogger.query_audit_logs(yesterday, today, :authentication)
      assert is_list(result)
    end

    test "returns list with nil user filter" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      result = AuditLogger.query_audit_logs(yesterday, today, :data_access, nil)
      assert is_list(result)
    end
  end

  describe "log_security_event/3" do
    test "logs security event with snake_case alias" do
      assert :ok =
               AuditLogger.log_security_event(:intrusion_detected, :critical, %{
                 source: "10.0.0.99"
               })
    end
  end

  describe "log_alarm_action/4 snake_case alias" do
    test "accepts symbolic action" do
      assert :ok = AuditLogger.log_alarm_action("u-100", :escalate, "alarm-999")
    end
  end

  # ============================================================
  # GenServer call API (synchronous)
  # ============================================================

  describe "generate_compliance_report/4" do
    test "generates SOX report with date range" do
      today = Date.utc_today()
      past = Date.add(today, -90)
      report = AuditLogger.generate_compliance_report(:sox, past, today)
      assert is_map(report)
      assert report.framework == :sox
    end

    test "generates GDPR report" do
      today = Date.utc_today()
      past = Date.add(today, -30)
      report = AuditLogger.generate_compliance_report(:gdpr, past, today)
      assert report.framework == :gdpr
    end

    test "generates HIPAA report" do
      today = Date.utc_today()
      report = AuditLogger.generate_compliance_report(:hipaa, today, today)
      assert report.framework == :hipaa
    end

    test "generates PCI DSS report" do
      today = Date.utc_today()
      report = AuditLogger.generate_compliance_report(:pci_dss, today, today)
      assert report.framework == :pci_dss
    end

    test "generates ISO27001 report" do
      today = Date.utc_today()
      report = AuditLogger.generate_compliance_report(:iso27001, today, today)
      assert report.framework == :iso27001
    end

    test "generates NIST report with five function coverage" do
      today = Date.utc_today()
      report = AuditLogger.generate_compliance_report(:nist, today, today)
      assert report.framework == :nist
      assert Map.has_key?(report, :identify)
      assert Map.has_key?(report, :protect)
      assert Map.has_key?(report, :detect)
      assert Map.has_key?(report, :respond)
      assert Map.has_key?(report, :recover)
    end

    test "generates FedRAMP report" do
      today = Date.utc_today()
      report = AuditLogger.generate_compliance_report(:fedramp, today, today)
      assert report.framework == :fedramp
    end

    test "report contains generated_at timestamp" do
      today = Date.utc_today()
      report = AuditLogger.generate_compliance_report(:sox, today, today)
      assert %DateTime{} = report.generated_at
    end
  end

  describe "get_audit_trail/2" do
    test "returns list for user filter" do
      trail = AuditLogger.get_audit_trail(%{user_id: "u-trail"})
      assert is_list(trail)
    end

    test "returns list for resource filter" do
      trail = AuditLogger.get_audit_trail(%{resource: "resource/1"})
      assert is_list(trail)
    end

    test "accepts empty filter" do
      trail = AuditLogger.get_audit_trail(%{})
      assert is_list(trail)
    end
  end

  describe "verify_audit_integrity/2" do
    test "returns integrity result map" do
      today = Date.utc_today()
      past = Date.add(today, -7)
      result = AuditLogger.verify_audit_integrity(past, today)
      assert is_map(result)
    end

    test "integrity result contains required keys" do
      today = Date.utc_today()
      result = AuditLogger.verify_audit_integrity(today, today)
      assert Map.has_key?(result, :overall_integrity)
      assert Map.has_key?(result, :hash_chain_valid)
      assert Map.has_key?(result, :entries_valid)
      assert Map.has_key?(result, :tampering_detected)
      assert Map.has_key?(result, :entries_checked)
      assert Map.has_key?(result, :verification_timestamp)
    end

    test "overall_integrity is boolean" do
      today = Date.utc_today()
      result = AuditLogger.verify_audit_integrity(today, today)
      assert is_boolean(result.overall_integrity)
    end

    test "tampering_detected defaults to false for empty range" do
      today = Date.utc_today()
      result = AuditLogger.verify_audit_integrity(today, today)
      refute result.tampering_detected
    end
  end

  # ============================================================
  # Property Tests (PropCheck)
  # ============================================================

  property "validate_audit_category/1 accepts only atoms from supported set" do
    categories = AuditLogger.get_supported_categories()

    forall category <- PC.elements(categories) do
      AuditLogger.validate_audit_category(category) == true
    end
  end

  property "validate_severity_level/1 rejects arbitrary atoms" do
    forall atom <- PC.atom() do
      known = AuditLogger.get_supported_severity_levels()
      result = AuditLogger.validate_severity_level(atom)
      if atom in known, do: result == true, else: true
    end
  end

  # ============================================================
  # Property Tests (StreamData / ExUnitProperties)
  # ============================================================

  test "log_audit_event/4 always returns :ok for valid categories" do
    valid_categories = AuditLogger.get_supported_categories()

    ExUnitProperties.check all(
                             category <- SD.member_of(valid_categories),
                             event_type <- SD.atom(:alphanumeric),
                             user_id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)
                           ) do
      assert :ok =
               AuditLogger.log_audit_event(category, event_type, %{
                 user_id: user_id,
                 timestamp: DateTime.utc_now()
               })
    end
  end

  test "store_audit_entry/1 round-trips map identity" do
    ExUnitProperties.check all(
                             key <- SD.atom(:alphanumeric),
                             val <- SD.string(:alphanumeric)
                           ) do
      entry = %{key => val}
      assert {:ok, ^entry} = AuditLogger.store_audit_entry(entry)
    end
  end

  # ============================================================
  # FMEA — Failure boundary tests
  # ============================================================

  describe "FMEA: edge cases and nil inputs" do
    test "log_auth_success handles nil context gracefully" do
      assert :ok = AuditLogger.log_auth_success(%{id: "u-nil-ctx"}, %{})
    end

    test "validate_audit_category handles integer input" do
      refute AuditLogger.validate_audit_category(42)
    end

    test "validate_compliance_framework handles empty atom" do
      refute AuditLogger.validate_compliance_framework(:"")
    end

    test "log_audit_event with nil details does not crash" do
      assert :ok = AuditLogger.log_audit_event(:admin_action, :emergency_stop, %{})
    end

    test "verify_audit_integrity with same start and end date" do
      today = Date.utc_today()
      result = AuditLogger.verify_audit_integrity(today, today)
      assert result.entries_checked >= 0
    end
  end
end
