defmodule Indrajaal.Observability.DomainLoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.DomainLogger.

  ## STAMP Safety Integration
  - SC-OBS-001: Domain operations must be logged for observability

  ## TPS 5-Level RCA Context
  - L1 Symptom: Successful domain operations untraceable
  - L5 Root Cause: Blind spots in system operation visibility
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.DomainLogger

  describe "log_success/3" do
    test "returns :ok for a basic success log" do
      result = DomainLogger.log_success(:accounts, "create_user")
      assert result == :ok
    end

    test "returns :ok with metadata" do
      result = DomainLogger.log_success(:accounts, "create_user", user_id: 123, email: "x@x.com")
      assert result == :ok
    end

    test "works with various domain atoms" do
      domains = [:alarms, :billing, :compliance, :devices, :dispatch]

      for domain <- domains do
        result = DomainLogger.log_success(domain, "test_operation")
        assert result == :ok, "Expected :ok for domain #{domain}"
      end
    end

    test "works without metadata (defaults to empty list)" do
      result = DomainLogger.log_success(:video, "start_stream")
      assert result == :ok
    end

    test "handles rich metadata" do
      result =
        DomainLogger.log_success(:analytics, "generate_report",
          report_id: "r-123",
          duration_ms: 450,
          rows: 5000,
          tenant_id: "t-1"
        )

      assert result == :ok
    end

    test "handles empty metadata list" do
      result = DomainLogger.log_success(:policy, "apply_rule", [])
      assert result == :ok
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.DomainLogger)
    end

    test "log_success/2 exported" do
      assert function_exported?(Indrajaal.Observability.DomainLogger, :log_success, 2)
    end

    test "log_success/3 exported" do
      assert function_exported?(Indrajaal.Observability.DomainLogger, :log_success, 3)
    end
  end
end
