#!/usr/bin/env elixir

# Test script to verify OpenTelemetry export to SigNoz
# Usage: elixir scripts/observability/test_telemetry_export.exs

# Ensure all applications are started
Application.ensure_all_started(:logger)
Application.ensure_all_started(:opentelemetry)
Application.ensure_all_started(:opentelemetry_api)
Application.ensure_all_started(:opentelemetry_exporter)

__require Logger
__require OpenTelemetry.Tracer

defmodule TelemetryExportTest do
  @moduledoc """
  Test module to verify telemetry export to SigNoz is working correctly.
  """

  @spec run() :: any()
  def run do
    IO.puts """
    ╔═══════════════════════════════════════════════════════════════════╗
    ║              OpenTelemetry Export Test for SigNoz                 ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """

    # Check environment
    endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
    service_name = System.get_env("OTEL_SERVICE_NAME", "indrajaal-test")

    IO.puts "\nConfiguration:"
    IO.puts "  OTLP Endpoint: #{endpoint}"
    IO.puts "  Service Name: #{service_name}"

    # Configure OpenTelemetry if not already configured
    :ok = :opentelemetry.set_default_tracer(:otel_tracer_default)

    # Test 1: Simple trace
    IO.puts "\n📊 Test 1: Generating simple trace..."
    simple_trace_test()

    # Test 2: Nested spans
    IO.puts "\n📊 Test 2: Generating nested spans..."
    nested_spans_test()

    # Test 3: Error trace
    IO.puts "\n📊 Test 3: Generating error trace..."
    error_trace_test()

    # Test 4: Trace with attributes
    IO.puts "\n📊 Test 4: Generating trace with attributes..."
    attributes_test()

    # Test 5: Structured logging
    IO.puts "\n📊 Test 5: Testing structured logging..."
    structured_logging_test()

    # Wait for export
    IO.puts "\n⏳ Waiting 10 seconds for telemetry export..."
    Process.sleep(10_000)

    IO.puts """

    ✅ Test completed!

    To verify in SigNoz:
    1. Open http://localhost:3301
    2. Navigate to Traces
    3. Filter by service name: #{service_name}
    4. Look for traces with names:
       - test.simple_trace
       - test.nested.parent
       - test.error_trace
       - test.with_attributes

    If you don't see traces:
    1. Check if SigNoz is running: podman-compose -f podman-compose.observability.yml ps
    2. Check OTEL collector logs: podman logs indrajaal-otel-collector
    3. Verify endpoint is reachable: curl #{endpoint}
    """
  end

  @spec simple_trace_test() :: any()
  defp simple_trace_test do
    OpenTelemetry.Tracer.with_span("test.simple_trace", %{}, fn ->
      Process.sleep(100)
      Logger.info("Simple trace test executed")
    end
    IO.puts "  ✓ Simple trace generated"
  end

  @spec nested_spans_test() :: any()
  defp nested_spans_test do
    OpenTelemetry.Tracer.with_span "test.nested.parent", %{
      attributes: %{"test.type" => "nested", "level" => 1}
    } do
      Process.sleep(50)

      OpenTelemetry.Tracer.with_span "test.nested.child1", %{
        attributes: %{"level" => 2}
      } do
        Process.sleep(30)
        Logger.info("Child span 1 executed")
      end

      OpenTelemetry.Tracer.with_span "test.nested.child2", %{
        attributes: %{"level" => 2}
      } do
        Process.sleep(40)
        Logger.info("Child span 2 executed")
      end
    end
    IO.puts "  ✓ Nested spans generated"
  end

  @spec error_trace_test() :: any()
  defp error_trace_test do
    try do
      OpenTelemetry.Tracer.with_span("test.error_trace", %{}, fn ->
        Process.sleep(20)
        raise "Test error for telemetry"
      end
    rescue
      error ->
        ctx = :otel_tracer.current_span_ctx()
        OpenTelemetry.Tracer.record_exception(ctx, error, __STACKTRACE__)
        OpenTelemetry.Tracer.set_status(ctx, :error, Exception.message(error))
        IO.puts "  ✓ Error trace generated"
    end
  end

  @spec attributes_test() :: any()
  defp attributes_test do
    OpenTelemetry.Tracer.with_span "test.with_attributes", %{
      attributes: %{
        "tenant.id" => "test-tenant",
        "__user.id" => "test-__user-123",
        "agent.type" => "test-agent",
        "compilation.domain" => "test-domain",
        "test.numeric" => 42,
        "test.boolean" => true
      }
    } do
      Process.sleep(75)

      # Add __event
      OpenTelemetry.Tracer.add_event("test_event", %{
        "__event.__data" => "test __event __data",
        "__event.timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

      Logger.info("Trace with attributes executed",
        __tenant_id: "test-tenant",
        __user_id: "test-__user-123"
      )
    end
    IO.puts "  ✓ Trace with attributes generated"
  end

  @spec structured_logging_test() :: any()
  defp structured_logging_test do
    # Test structured JSON logging
    Logger.info("Structured log test",
      test_id: "telemetry-export-test",
      timestamp: DateTime.utc_now(),
      __tenant_id: "test-tenant",
      metadata: %{
        agent_count: 11,
        compilation_strategy: "smart",
        framework: "sopv51"
      }
    )

    Logger.warning("Test warning message",
      warning_type: "test_warning",
      severity: "medium",
      action_required: false
    )

    IO.puts "  ✓ Structured logs generated"
  end
end

# Run the test
TelemetryExportTest.run()