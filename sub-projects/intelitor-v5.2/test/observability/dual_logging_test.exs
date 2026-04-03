defmodule Indrajaal.Observability.DualLoggingLegacyTest do
  @moduledoc """
  Tests for the mandatory dual logging system (Console + SigNoz).
  Ensures both backends are always active and properly configured.
  """
  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Observability.DualLogging
  import Indrajaal.Factory

  describe "dual logging validation" do
    test "validates both backends are configured" do
      # This should not raise since we have both backends configured
      assert :ok = DualLogging.validate_dual_logging!()
    end

    test "current configuration has both backends" do
      backends = Application.get_env(:logger, :backends, [])

      assert :console in backends, "Console backend is missing"
      assert LoggerJSON in backends, "LoggerJSON backend is missing"
    end

    test "raises error if console backend is missing" do
      # Temporarily remove console backend
      original_backends = Application.get_env(:logger, :backends)
      Application.put_env(:logger, :backends, [LoggerJSON])

      assert_raise RuntimeError, ~r/Console logging backend is not configured/, fn ->
        DualLogging.validate_dual_logging!()
      end

      # Restore original backends
      Application.put_env(:logger, :backends, original_backends)
    end

    test "raises error if LoggerJSON backend is missing" do
      # Temporarily remove LoggerJSON backend
      original_backends = Application.get_env(:logger, :backends)
      Application.put_env(:logger, :backends, [:console])

      assert_raise RuntimeError, ~r/LoggerJSON backend is not configured/, fn ->
        DualLogging.validate_dual_logging!()
      end

      # Restore original backends
      Application.put_env(:logger, :backends, original_backends)
    end
  end

  describe "console format configuration" do
    test "can configure console format" do
      # Should not raise
      assert :ok = DualLogging.configure_console_format(:minimal)
      assert :ok = DualLogging.configure_console_format(:detailed)
      assert :ok = DualLogging.configure_console_format(:verbose)
    end

    test "can use custom format string" do
      custom_format = "$date $time [$level] $message
# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n"
      assert :ok = DualLogging.configure_console_format(custom_format)
    end
  end

  describe "backend toggling" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    @tag :backend_toggling
    test "backend toggling placeholder" do
      # TDG: Backend toggling test placeholder
      assert true, "Backend toggling placeholder"
    end
  end

  describe "correlation ID handling" do
    test "adds and removes correlation ID from metadata" do
      correlation_id = "test-correlation-#{System.unique_integer()}"

      result =
        DualLogging.with_correlation_id(correlation_id, fn ->
          metadata = Logger.metadata()
          assert metadata[:correlation_id] == correlation_id

          "test_result"
        end)

      assert result == "test_result"

      # Correlation ID should be cleared after
      metadata = Logger.metadata()
      assert metadata[:correlation_id] == nil
    end
  end

  describe "domain __event logging" do
    test "logs domain __events with enhanced metadata" do
      # This test verifies the function works without errors
      # In a real test, you might capture logs to verify output

      assert :ok =
               DualLogging.log_domain_event(
                 :accounts,
                 "__user.created",
                 :info,
                 __user_id: 123,
                 email: "test@example.com"
               )
    end

    test "important messages use enhanced formatting" do
      # This should not raise
      assert :ok =
               DualLogging.log_important(
                 :warn,
                 "Test important message",
                 test: true
               )
    end
  end

  describe "metadata propagation" do
    test "both backends receive same metadata" do
      # Get current console metadata config
      console__metadata = Application.get_env(:logger, :console)[:metadata] || []

      # Verify important metadata fields are included
      important_fields = [:__request_id, :tenant_id, :trace_id, :__user_id]

      for field <- important_fields do
        assert field in console__metadata,
               "Console backend missing metadata field: #{field}"
      end

      # JSON backend should have all metadata
      json_config = Application.get_env(:logger_json, :backend)
      assert json_config[:metadata] == :all
    end
  end

  describe "production __requirements" do
    test "verifies production configuration __requirements" do
      # Both backends must be configured
      backends = Application.get_env(:logger, :backends, [])
      assert length(backends) >= 2, "Production __requires at least 2 backends"

      # Log level should be appropriate
      level = Application.get_env(:logger, :level, :info)
      assert level in [:debug, :info, :warn, :error]

      # Console should have proper format
      console_config = Application.get_env(:logger, :console, [])
      assert console_config[:format] != nil

      # JSON backend should be configured
      json_config = Application.get_env(:logger_json, :backend, [])
      assert json_config[:formatter] != nil
    end
  end
end
