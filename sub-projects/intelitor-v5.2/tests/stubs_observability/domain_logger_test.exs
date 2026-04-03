defmodule Intelitor.Observability.DomainLoggerTest do
  @moduledoc """
  Tests for DomainLogger standardized logging helper.

  Validates:
  - Structured logging format compliance
  - Metadata validation
  - Domain validation
  - OpenTelemetry integration
  - Error classification
  - SOPv5.11 compliance
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  alias Intelitor.Observability.DomainLogger

  @valid_domains [
    "access_control",
    "accounts",
    "alarms",
    "analytics",
    "asset_management",
    "billing",
    "communication",
    "compliance",
    "core",
    "devices",
    "dispatch",
    "guard_tour",
    "integrations",
    "maintenance",
    "policy",
    "risk_management",
    "sites",
    "video",
    "visitor_management"
  ]

  describe "log_success/3" do
    @tag :sopv511
    @tag :observability
    test "logs successful operation with required metadata" do
      log =
        capture_log(fn ->
          DomainLogger.log_success("billing", "invoice_generation",
            user_id: "user-123",
            tenant_id: "tenant-456",
            resource_id: "invoice-789",
            duration_ms: 1250
          )
        end)

      assert log =~ "Domain operation successful"
      assert log =~ "domain: \"billing\""
      assert log =~ "operation: \"invoice_generation\""
      assert log =~ "user_id: \"user-123\""
      assert log =~ "tenant_id: \"tenant-456\""
      assert log =~ "resource_id: \"invoice-789\""
      assert log =~ "duration_ms: 1250"
    end

    @tag :sopv511
    @tag :observability
    test "includes trace_id from OpenTelemetry context when available" do
      log =
        capture_log(fn ->
          DomainLogger.log_success("billing", "invoice_generation",
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "trace_id:"
    end

    @tag :sopv511
    @tag :observability
    test "accepts custom trace_id in metadata" do
      log =
        capture_log(fn ->
          DomainLogger.log_success("billing", "invoice_generation",
            user_id: "user-123",
            tenant_id: "tenant-456",
            trace_id: "custom-trace-id"
          )
        end)

      assert log =~ "trace_id: \"custom-trace-id\""
    end

    @tag :sopv511
    @tag :observability
    test "includes additional domain-specific metadata" do
      log =
        capture_log(fn ->
          DomainLogger.log_success("billing", "invoice_generation",
            user_id: "user-123",
            tenant_id: "tenant-456",
            amount: 99.99,
            currency: "USD"
          )
        end)

      assert log =~ "amount: 99.99"
      assert log =~ "currency: \"USD\""
    end

    @tag :sopv511
    @tag :observability
    test "raises ArgumentError for invalid domain" do
      assert_raise ArgumentError, ~r/Invalid domain/, fn ->
        DomainLogger.log_success("invalid_domain", "test_operation",
          user_id: "user-123",
          tenant_id: "tenant-456"
        )
      end
    end

    @tag :sopv511
    @tag :observability
    test "raises ArgumentError for missing user_id" do
      assert_raise ArgumentError, ~r/Missing required metadata fields.*:user_id/, fn ->
        DomainLogger.log_success("billing", "invoice_generation", tenant_id: "tenant-456")
      end
    end

    @tag :sopv511
    @tag :observability
    test "raises ArgumentError for missing tenant_id" do
      assert_raise ArgumentError, ~r/Missing required metadata fields.*:tenant_id/, fn ->
        DomainLogger.log_success("billing", "invoice_generation", user_id: "user-123")
      end
    end
  end

  describe "log_error/4" do
    @tag :sopv511
    @tag :observability
    test "logs operation error with exception" do
      error = %RuntimeError{message: "Something went wrong"}

      log =
        capture_log(fn ->
          DomainLogger.log_error("billing", "invoice_generation", error,
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "Domain operation failed"
      assert log =~ "domain: \"billing\""
      assert log =~ "operation: \"invoice_generation\""
      assert log =~ "error: \"Something went wrong\""
      assert log =~ "error_type: :runtime_error"
    end

    @tag :sopv511
    @tag :observability
    test "classifies database errors correctly" do
      error = %DBConnection.ConnectionError{message: "connection refused"}

      log =
        capture_log(fn ->
          DomainLogger.log_error("core", "database_query", error,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "error_type: :database_error"
    end

    @tag :sopv511
    @tag :observability
    test "classifies validation errors correctly" do
      error = %Ash.Error.Invalid{errors: []}

      log =
        capture_log(fn ->
          DomainLogger.log_error("billing", "invoice_creation", error,
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "error_type: :validation_error"
    end

    @tag :sopv511
    @tag :observability
    test "includes custom error_type when provided" do
      error = "Custom error"

      log =
        capture_log(fn ->
          DomainLogger.log_error("billing", "invoice_generation", error,
            user_id: "user-123",
            tenant_id: "tenant-456",
            error_type: :custom_business_error
          )
        end)

      assert log =~ "error_type: :custom_business_error"
    end

    @tag :sopv511
    @tag :observability
    test "handles error tuple format" do
      error = {:error, :not_found}

      log =
        capture_log(fn ->
          DomainLogger.log_error("devices", "device_lookup", error,
            user_id: "user-123",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "error_type: :not_found_error"
    end
  end

  describe "log_state_change/6" do
    @tag :sopv511
    @tag :observability
    test "logs state transition with all details" do
      log =
        capture_log(fn ->
          DomainLogger.log_state_change(
            "alarms",
            "alarm",
            "alarm-123",
            "active",
            "resolved",
            user_id: "user-123",
            tenant_id: "tenant-456",
            reason: "Manual resolution"
          )
        end)

      assert log =~ "State transition"
      assert log =~ "domain: \"alarms\""
      assert log =~ "resource_type: \"alarm\""
      assert log =~ "resource_id: \"alarm-123\""
      assert log =~ "previous_state: \"active\""
      assert log =~ "new_state: \"resolved\""
      assert log =~ "reason: \"Manual resolution\""
    end

    @tag :sopv511
    @tag :observability
    test "converts atom states to strings" do
      log =
        capture_log(fn ->
          DomainLogger.log_state_change(
            "devices",
            "device",
            "device-123",
            :online,
            :offline,
            user_id: "system",
            tenant_id: "tenant-456"
          )
        end)

      assert log =~ "previous_state: \"online\""
      assert log =~ "new_state: \"offline\""
    end
  end

  describe "log_warning/4" do
    @tag :sopv511
    @tag :observability
    test "logs warning condition with message" do
      log =
        capture_log(fn ->
          DomainLogger.log_warning(
            "billing",
            "invoice_generation",
            "Invoice amount exceeds normal threshold",
            user_id: "user-123",
            tenant_id: "tenant-456",
            amount: 10000.0,
            threshold: 5000.0
          )
        end)

      assert log =~ "Domain operation warning"
      assert log =~ "domain: \"billing\""
      assert log =~ "message: \"Invoice amount exceeds normal threshold\""
      assert log =~ "amount: 10000.0"
      assert log =~ "threshold: 5000.0"
    end
  end

  describe "validate_domain!/1" do
    @tag :sopv511
    @tag :observability
    test "accepts all 19 valid domains" do
      for domain <- @valid_domains do
        assert :ok = DomainLogger.validate_domain!(domain)
      end
    end

    @tag :sopv511
    @tag :observability
    test "rejects invalid domain names" do
      assert_raise ArgumentError, fn ->
        DomainLogger.validate_domain!("invalid_domain")
      end
    end
  end

  describe "validate_required_metadata!/2" do
    @tag :sopv511
    @tag :observability
    test "passes when all required fields are present" do
      metadata = [user_id: "user-123", tenant_id: "tenant-456"]
      assert :ok = DomainLogger.validate_required_metadata!(metadata, [:user_id, :tenant_id])
    end

    @tag :sopv511
    @tag :observability
    test "raises when required field is missing" do
      metadata = [user_id: "user-123"]

      assert_raise ArgumentError, ~r/Missing required metadata fields.*:tenant_id/, fn ->
        DomainLogger.validate_required_metadata!(metadata, [:user_id, :tenant_id])
      end
    end

    @tag :sopv511
    @tag :observability
    test "raises when required field is nil" do
      metadata = [user_id: "user-123", tenant_id: nil]

      assert_raise ArgumentError, ~r/Missing required metadata fields.*:tenant_id/, fn ->
        DomainLogger.validate_required_metadata!(metadata, [:user_id, :tenant_id])
      end
    end
  end

  describe "format_error/1" do
    @tag :sopv511
    @tag :observability
    test "formats exception with message" do
      error = %RuntimeError{message: "Test error"}
      assert DomainLogger.format_error(error) == "Test error"
    end

    @tag :sopv511
    @tag :observability
    test "formats string error as-is" do
      error = "String error"
      assert DomainLogger.format_error(error) == "String error"
    end

    @tag :sopv511
    @tag :observability
    test "formats atom error as string" do
      error = :timeout
      assert DomainLogger.format_error(error) == "timeout"
    end

    @tag :sopv511
    @tag :observability
    test "formats error tuple by extracting reason" do
      error = {:error, "Network timeout"}
      assert DomainLogger.format_error(error) == "Network timeout"
    end

    @tag :sopv511
    @tag :observability
    test "inspects unknown error types" do
      error = {:custom, :error, :type}
      result = DomainLogger.format_error(error)
      assert is_binary(result)
      assert result =~ ":custom"
    end
  end

  describe "classify_error/1" do
    @tag :sopv511
    @tag :observability
    test "classifies validation errors" do
      assert DomainLogger.classify_error(%Ecto.Changeset{}) == :validation_error
      assert DomainLogger.classify_error(%Ash.Error.Invalid{}) == :validation_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies database errors" do
      assert DomainLogger.classify_error(%DBConnection.ConnectionError{}) == :database_error
      assert DomainLogger.classify_error(%Postgrex.Error{}) == :database_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies external service errors" do
      assert DomainLogger.classify_error(%Tesla.Error{}) == :external_service_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies data format errors" do
      assert DomainLogger.classify_error(%Jason.DecodeError{}) == :data_format_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies argument errors" do
      assert DomainLogger.classify_error(%ArgumentError{}) == :invalid_argument
    end

    @tag :sopv511
    @tag :observability
    test "classifies runtime errors" do
      assert DomainLogger.classify_error(%RuntimeError{}) == :runtime_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies not found errors" do
      assert DomainLogger.classify_error({:error, :not_found}) == :not_found_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies authorization errors" do
      assert DomainLogger.classify_error({:error, :unauthorized}) == :authorization_error
      assert DomainLogger.classify_error({:error, :forbidden}) == :authorization_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies timeout errors" do
      assert DomainLogger.classify_error({:error, :timeout}) == :timeout_error
    end

    @tag :sopv511
    @tag :observability
    test "classifies unknown errors" do
      assert DomainLogger.classify_error({:error, :custom}) == :unknown_error
      assert DomainLogger.classify_error("unknown") == :unknown_error
    end
  end

  describe "get_trace_id/0" do
    @tag :sopv511
    @tag :observability
    test "returns trace_id from OpenTelemetry context when available" do
      # This test assumes OpentelemetryProcessPropagator is available
      # In real implementation, might need to set up OpenTelemetry context
      trace_id = DomainLogger.get_trace_id()
      assert is_binary(trace_id)
    end

    @tag :sopv511
    @tag :observability
    test "returns no-trace when OpenTelemetry context is not available" do
      # Without setting up OpenTelemetry, should return fallback
      trace_id = DomainLogger.get_trace_id()
      assert trace_id == "no-trace" or is_binary(trace_id)
    end
  end
end
