defmodule Intelitor.Observability.ErrorLoggerTest do
  @moduledoc """
  Tests for standardized error logging and recovery pattern helper.

  Validates:
  - Error classification and severity determination
  - Retry tracking and management
  - Recovery action logging
  - Jidoka halt triggering
  - TPS 5-Level RCA integration
  - SOPv5.11 compliance
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  alias Intelitor.Observability.ErrorLogger

  describe "log_error/4" do
    @tag :sopv511
    @tag :observability
    test "logs error with automatic classification and severity" do
      error = %RuntimeError{message: "Something went wrong"}

      log =
        capture_log(fn ->
          ErrorLogger.log_error("billing", "invoice_generation", error,
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "Domain operation failed"
      assert log =~ "domain: \"billing\""
      assert log =~ "operation: \"invoice_generation\""
      assert log =~ "error_type: :runtime_error"
      assert log =~ "severity: :low"
    end

    @tag :sopv511
    @tag :observability
    test "triggers Jidoka halt for critical errors" do
      error = %DBConnection.ConnectionError{message: "connection refused"}

      log =
        capture_log(fn ->
          ErrorLogger.log_error("core", "database_query", error,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "error_type: :database_error"
      assert log =~ "severity: :critical"
      assert log =~ "JIDOKA HALT TRIGGERED"
    end

    @tag :sopv511
    @tag :observability
    test "includes error context and stack trace when provided" do
      error = %ArgumentError{message: "invalid argument"}

      log =
        capture_log(fn ->
          ErrorLogger.log_error("devices", "device_validation", error,
            user_id: "user-123",
            tenant_id: "tenant-456",
            error_context: %{device_id: "device-789"},
            stack_trace: ["line 1", "line 2"]
          )
        end)

      assert log =~ "error_context:"
      assert log =~ "stack_trace:"
    end

    @tag :sopv511
    @tag :observability
    test "includes correlation_id when provided" do
      error = "Network timeout"

      log =
        capture_log(fn ->
          ErrorLogger.log_error("integrations", "api_call", error,
            user_id: "user-123",
            tenant_id: "tenant-456",
            correlation_id: "corr-12345"
          )
        end)

      assert log =~ "correlation_id: \"corr-12345\""
    end
  end

  describe "log_error_with_retry/4" do
    @tag :sopv511
    @tag :observability
    test "logs error with retry tracking and will_retry flag" do
      error = %Tesla.Error{reason: :timeout}

      log =
        capture_log(fn ->
          ErrorLogger.log_error_with_retry("integrations", "stripe_api_call", error,
            retry_attempt: 2,
            max_retries: 3,
            backoff_ms: 2000,
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "Operation failed - will retry"
      assert log =~ "retry_attempt: 2"
      assert log =~ "max_retries: 3"
      assert log =~ "will_retry: true"
      assert log =~ "backoff_ms: 2000"
    end

    @tag :sopv511
    @tag :observability
    test "logs final error when max retries reached" do
      error = %HTTPoison.Error{reason: :timeout}

      log =
        capture_log(fn ->
          ErrorLogger.log_error_with_retry("integrations", "api_request", error,
            retry_attempt: 3,
            max_retries: 3,
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "max retries reached"
      assert log =~ "will_retry: false"
      assert log =~ "Domain operation failed"
    end

    @tag :sopv511
    @tag :observability
    test "raises ArgumentError when retry_attempt missing" do
      error = "timeout"

      assert_raise ArgumentError, ~r/Missing required metadata field: :retry_attempt/, fn ->
        ErrorLogger.log_error_with_retry("integrations", "api_call", error,
          max_retries: 3,
          user_id: "user-123",
          tenant_id: "tenant-456"
        )
      end
    end

    @tag :sopv511
    @tag :observability
    test "raises ArgumentError when max_retries missing" do
      error = "timeout"

      assert_raise ArgumentError, ~r/Missing required metadata field: :max_retries/, fn ->
        ErrorLogger.log_error_with_retry("integrations", "api_call", error,
          retry_attempt: 2,
          user_id: "user-123",
          tenant_id: "tenant-456"
        )
      end
    end
  end

  describe "log_recoverable_error/4" do
    @tag :sopv511
    @tag :observability
    test "logs recoverable error with recovery action" do
      error = %Tesla.Error{reason: :timeout}

      log =
        capture_log(fn ->
          ErrorLogger.log_recoverable_error("devices", "device_health_check", error,
            recovery_action: "automatic_restart",
            recovery_result: "success",
            device_id: "device-123",
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "Recoverable error - recovery attempted"
      assert log =~ "recovery_action: \"automatic_restart\""
      assert log =~ "recovery_result: \"success\""
    end

    @tag :sopv511
    @tag :observability
    test "logs audit event when recovery successful" do
      error = {:error, :temporary_unavailable}

      log =
        capture_log(fn ->
          ErrorLogger.log_recoverable_error("integrations", "external_api", error,
            recovery_action: "retry_with_backoff",
            recovery_result: "success",
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "Audit event"
      assert log =~ "operation_type: \"system_configuration\""
      assert log =~ "operation_subtype: \"automatic_recovery\""
    end

    @tag :sopv511
    @tag :observability
    test "raises ArgumentError when recovery_action missing" do
      error = "network error"

      assert_raise ArgumentError, ~r/Missing required metadata field: :recovery_action/, fn ->
        ErrorLogger.log_recoverable_error("devices", "device_check", error,
          user_id: "system",
          tenant_id: "tenant-456"
        )
      end
    end

    @tag :sopv511
    @tag :observability
    test "includes additional metadata in logs" do
      error = {:error, :rate_limit}

      log =
        capture_log(fn ->
          ErrorLogger.log_recoverable_error("integrations", "api_call", error,
            recovery_action: "wait_and_retry",
            api_endpoint: "/v1/users",
            rate_limit: 100,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "additional_metadata:"
      assert log =~ "api_endpoint:"
      assert log =~ "rate_limit:"
    end
  end

  describe "log_critical_error/4" do
    @tag :sopv511
    @tag :observability
    test "logs critical error with Jidoka halt" do
      error = %DBConnection.ConnectionError{message: "database unavailable"}

      log =
        capture_log(fn ->
          ErrorLogger.log_critical_error("core", "database_connection", error,
            jidoka_halt: true,
            rca_required: true,
            affected_systems: ["database", "audit_log"],
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "CRITICAL ERROR - immediate attention required"
      assert log =~ "severity: \"critical\""
      assert log =~ "jidoka_halt: true"
      assert log =~ "rca_required: true"
      assert log =~ "JIDOKA HALT TRIGGERED"
    end

    @tag :sopv511
    @tag :observability
    test "logs emergency audit event for critical errors" do
      error = %RuntimeError{message: "system failure"}

      log =
        capture_log(fn ->
          ErrorLogger.log_critical_error("core", "system_health", error,
            jidoka_halt: true,
            rca_required: true,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "Audit event"
      assert log =~ "operation_type: \"emergency_protocol\""
      assert log =~ "operation_subtype: \"critical_error\""
      assert log =~ "severity: \"critical\""
    end

    @tag :sopv511
    @tag :observability
    test "defaults jidoka_halt to true when not specified" do
      error = "data corruption detected"

      log =
        capture_log(fn ->
          ErrorLogger.log_critical_error("core", "data_integrity", error,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "jidoka_halt: true"
      assert log =~ "JIDOKA HALT TRIGGERED"
    end

    @tag :sopv511
    @tag :observability
    test "defaults rca_required to true when not specified" do
      error = "security breach detected"

      log =
        capture_log(fn ->
          ErrorLogger.log_critical_error("core", "security_check", error,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "rca_required: true"
    end

    @tag :sopv511
    @tag :observability
    test "includes affected_systems in logs when provided" do
      error = "resource exhaustion"

      log =
        capture_log(fn ->
          ErrorLogger.log_critical_error("core", "resource_monitor", error,
            affected_systems: ["memory", "cpu", "disk"],
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "affected_systems:"
    end
  end

  describe "determine_severity/1" do
    @tag :sopv511
    @tag :observability
    test "returns :critical for critical error types" do
      assert ErrorLogger.determine_severity(:database_error) == :critical
      assert ErrorLogger.determine_severity(:data_corruption) == :critical
      assert ErrorLogger.determine_severity(:security_breach) == :critical
      assert ErrorLogger.determine_severity(:system_failure) == :critical
      assert ErrorLogger.determine_severity(:resource_exhaustion) == :critical
    end

    @tag :sopv511
    @tag :observability
    test "returns :high for authorization errors" do
      assert ErrorLogger.determine_severity(:authorization_error) == :high
    end

    @tag :sopv511
    @tag :observability
    test "returns :medium for validation errors" do
      assert ErrorLogger.determine_severity(:validation_error) == :medium
    end

    @tag :sopv511
    @tag :observability
    test "returns :medium for recoverable error types" do
      assert ErrorLogger.determine_severity(:timeout_error) == :medium
      assert ErrorLogger.determine_severity(:external_service_error) == :medium
      assert ErrorLogger.determine_severity(:rate_limit_error) == :medium
      assert ErrorLogger.determine_severity(:network_error) == :medium
      assert ErrorLogger.determine_severity(:temporary_unavailable) == :medium
    end

    @tag :sopv511
    @tag :observability
    test "returns :low for other error types" do
      assert ErrorLogger.determine_severity(:unknown_error) == :low
      assert ErrorLogger.determine_severity(:not_found_error) == :low
      assert ErrorLogger.determine_severity(:invalid_argument) == :low
    end
  end

  describe "recoverable?/1" do
    @tag :sopv511
    @tag :observability
    test "returns true for recoverable error types" do
      assert ErrorLogger.recoverable?(:timeout_error) == true
      assert ErrorLogger.recoverable?(:external_service_error) == true
      assert ErrorLogger.recoverable?(:rate_limit_error) == true
      assert ErrorLogger.recoverable?(:network_error) == true
      assert ErrorLogger.recoverable?(:temporary_unavailable) == true
    end

    @tag :sopv511
    @tag :observability
    test "returns false for non-recoverable error types" do
      assert ErrorLogger.recoverable?(:database_error) == false
      assert ErrorLogger.recoverable?(:validation_error) == false
      assert ErrorLogger.recoverable?(:authorization_error) == false
      assert ErrorLogger.recoverable?(:unknown_error) == false
    end
  end

  describe "critical?/1" do
    @tag :sopv511
    @tag :observability
    test "returns true for critical error types" do
      assert ErrorLogger.critical?(:database_error) == true
      assert ErrorLogger.critical?(:data_corruption) == true
      assert ErrorLogger.critical?(:security_breach) == true
      assert ErrorLogger.critical?(:system_failure) == true
      assert ErrorLogger.critical?(:resource_exhaustion) == true
    end

    @tag :sopv511
    @tag :observability
    test "returns false for non-critical error types" do
      assert ErrorLogger.critical?(:timeout_error) == false
      assert ErrorLogger.critical?(:validation_error) == false
      assert ErrorLogger.critical?(:authorization_error) == false
      assert ErrorLogger.critical?(:unknown_error) == false
    end
  end

  describe "Integration with DomainLogger and AuditLogger" do
    @tag :sopv511
    @tag :observability
    test "log_error calls DomainLogger.log_error" do
      error = %RuntimeError{message: "test error"}

      log =
        capture_log(fn ->
          ErrorLogger.log_error("billing", "test_operation", error,
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      # Verify DomainLogger.log_error was called
      assert log =~ "Domain operation failed"
      assert log =~ "domain: \"billing\""
      assert log =~ "error: \"test error\""
    end

    @tag :sopv511
    @tag :observability
    test "log_critical_error calls AuditLogger.log_emergency_event" do
      error = "critical system error"

      log =
        capture_log(fn ->
          ErrorLogger.log_critical_error("core", "system_check", error,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      # Verify AuditLogger.log_emergency_event was called
      assert log =~ "Audit event"
      assert log =~ "operation_type: \"emergency_protocol\""
    end

    @tag :sopv511
    @tag :observability
    test "log_recoverable_error calls AuditLogger.log_audit_event on success" do
      error = "temporary error"

      log =
        capture_log(fn ->
          ErrorLogger.log_recoverable_error("devices", "device_check", error,
            recovery_action: "restart",
            recovery_result: "success",
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      # Verify AuditLogger.log_audit_event was called
      assert log =~ "Audit event"
      assert log =~ "operation_type: \"system_configuration\""
      assert log =~ "operation_subtype: \"automatic_recovery\""
    end
  end
end
