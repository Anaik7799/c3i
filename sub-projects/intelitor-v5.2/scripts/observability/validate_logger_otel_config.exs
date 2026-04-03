#!/usr/bin/env elixir

# ═════════════════════════════════════════════════════════════════════════════
# Logger and OTEL Configuration Validator
# ═════════════════════════════════════════════════════════════════════════════
#
# This script validates that Logger and OpenTelemetry configurations are
# properly set up for SigNoz integration with trace metadata support.
#
# SOPv5.1 Compliance: ✅ Configuration validation with cybernetic feedback
# STAMP Safety: SC1 (Pr__event __data loss), SC2 (Ensure proper initialization)
# ═════════════════════════════════════════════════════════════════════════════

defmodule LoggerOtelConfigValidator do
  @moduledoc """
  Validates Logger and OpenTelemetry configurations for proper SigNoz integration.
  """

  @spec run() :: :ok
  def run do
    # Load the application configuration first
    Mix.Task.run("app.config", [])

    IO.puts("\n🔍 Validating Logger and OTEL Configuration...")
    IO.puts("═" <> String.duplicate("═", 79))

    results = [
      validate_logger_backends(),
      validate_logger__metadata(),
      validate_logger_json_config(),
      validate_otel_exporter(),
      validate_otel_resource(),
      validate_otel_propagators(),
      validate_otel_sampling(),
      validate_instrumentation_libraries(),
      validate_signoz_config()
    ]

    success_count = Enum.count(results, & &1)
    total_count = length(results)

    IO.puts("\n═" <> String.duplicate("═", 79))

    if success_count == total_count do
      IO.puts("✅ All #{total_count} configuration checks passed!")
      IO.puts("\n🎯 Logger and OTEL configuration is properly set up for SigNoz integration.")
      System.halt(0)
    else
      IO.puts("❌ #{total_count - success_count} out of #{total_count} checks failed!")
      IO.puts("\n⚠️  Please review the configuration issues above.")
      System.halt(1)
    end
  end

  defp validate_logger_backends do
    IO.puts("\n📋 Checking Logger backends...")
    backends = Application.get_env(:logger, :backends, [])

    console_present = :console in backends
    logger_json_present = LoggerJSON in backends
    timescale_present = Indrajaal.Timescale.LoggerBackend in backends

    if console_present and logger_json_present do
      IO.puts("  ✅ Console backend: Configured")
      IO.puts("  ✅ LoggerJSON backend: Configured")

      if timescale_present do
        IO.puts("  ✅ TimescaleDB backend: Configured (Triple logging active)")
      else
        IO.puts("  ⚠️  TimescaleDB backend: Not configured (Dual logging only)")
      end

      true
    else
      if not console_present do
        IO.puts("  ❌ Console backend: NOT configured")
      end

      if not logger_json_present do
        IO.puts("  ❌ LoggerJSON backend: NOT configured")
      end

      false
    end
  end

  defp validate_logger__metadata do
    IO.puts("\n📋 Checking Logger metadata configuration...")
    console_config = Application.get_env(:logger, :console, [])
    metadata = console_config[:metadata]

    if metadata == :all do
      IO.puts("  ✅ Console metadata: :all (includes trace __context)")
      true
    else
      if is_list(metadata) and :trace_id in metadata and :span_id in metadata do
        IO.puts("  ✅ Console metadata: Includes :trace_id and :span_id")
        true
      else
        IO.puts("  ❌ Console metadata: Missing trace __context fields")
        false
      end
    end
  end

  defp validate_logger_json_config do
    IO.puts("\n📋 Checking LoggerJSON configuration...")
    json_config = Application.get_env(:logger_json, :backend, [])

    formatter = json_config[:formatter]
    metadata = json_config[:metadata]

    valid_formatter =
      formatter in [
        LoggerJSON.Formatters.Datadog,
        LoggerJSON.Formatters.GoogleCloud,
        LoggerJSON.Formatters.Elastic
      ]

    if valid_formatter and metadata == :all do
      IO.puts("  ✅ LoggerJSON formatter: #{inspect(formatter)}")
      IO.puts("  ✅ LoggerJSON metadata: :all")
      true
    else
      if not valid_formatter do
        IO.puts("  ❌ LoggerJSON formatter: #{inspect(formatter)} (not supported)")
      end

      if metadata != :all do
        IO.puts("  ❌ LoggerJSON metadata: #{inspect(metadata)} (should be :all)")
      end

      false
    end
  end

  defp validate_otel_exporter do
    IO.puts("\n📋 Checking OTEL exporter configuration...")

    span_processor = Application.get_env(:opentelemetry, :span_processor)
    traces_exporter = Application.get_env(:opentelemetry, :traces_exporter)
    otlp_config = Application.get_env(:opentelemetry_exporter, :otlp, [])

    endpoint = otlp_config[:endpoint] || System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT")

    if span_processor == :batch and traces_exporter == :otlp do
      IO.puts("  ✅ Span processor: :batch")
      IO.puts("  ✅ Traces exporter: :otlp")

      if endpoint do
        IO.puts("  ✅ OTLP endpoint: #{endpoint}")
      else
        IO.puts("  ⚠️  OTLP endpoint: Not configured (will use default)")
      end

      true
    else
      IO.puts("  ❌ Span processor: #{inspect(span_processor)} (should be :batch)")
      IO.puts("  ❌ Traces exporter: #{inspect(traces_exporter)} (should be :otlp)")
      false
    end
  end

  defp validate_otel_resource do
    IO.puts("\n📋 Checking OTEL resource attributes...")
    resource = Application.get_env(:opentelemetry, :resource, %{})

    service = resource[:service] || %{}
    attributes = resource[:attributes] || []

    has_service_name = service[:name] == "indrajaal"
    has_signoz_attr = {"signoz.integration", "enabled"} in attributes

    if has_service_name and has_signoz_attr do
      IO.puts("  ✅ Service name: indrajaal")
      IO.puts("  ✅ SigNoz integration: enabled")
      true
    else
      if not has_service_name do
        IO.puts("  ❌ Service name: #{inspect(service[:name])} (should be 'indrajaal')")
      end

      if not has_signoz_attr do
        IO.puts("  ❌ SigNoz integration attribute: missing")
      end

      false
    end
  end

  defp validate_otel_propagators do
    IO.puts("\n📋 Checking OTEL propagators...")
    propagators = Application.get_env(:opentelemetry, :propagators, [])

    has_trace__context = :trace__context in propagators
    has_baggage = :baggage in propagators

    if has_trace__context do
      IO.puts("  ✅ TraceContext propagator: configured")

      if has_baggage do
        IO.puts("  ✅ Baggage propagator: configured")
      else
        IO.puts("  ⚠️  Baggage propagator: not configured (optional)")
      end

      true
    else
      IO.puts("  ❌ TraceContext propagator: NOT configured")
      false
    end
  end

  defp validate_otel_sampling do
    IO.puts("\n📋 Checking OTEL sampling configuration...")
    sampler = Application.get_env(:opentelemetry, :sampler)

    case sampler do
      nil ->
        IO.puts("  ⚠️  Sampler: default (always_on)")
        true

      {:always_on, _} ->
        IO.puts("  ✅ Sampler: always_on")
        true

      {:always_off, _} ->
        IO.puts("  ⚠️  Sampler: always_off (no traces will be sent!)")
        true

      {:probability, __opts} ->
        ratio = __opts[:probability] || 1.0
        IO.puts("  ✅ Sampler: probability (#{ratio * 100}%)")
        true

      other ->
        IO.puts("  ❌ Sampler: #{inspect(other)} (unknown type)")
        false
    end
  end

  defp validate_instrumentation_libraries do
    IO.puts("\n📋 Checking instrumentation libraries...")

    checks = [
      {:opentelemetry_phoenix, "Phoenix"},
      {:opentelemetry_ecto, "Ecto"},
      {:opentelemetry_oban, "Oban"}
    ]

    _results =
      Enum.map(checks, fn {app, name} ->
        config = Application.get_all_env(app)

        if config != [] do
          IO.puts("  ✅ #{name} instrumentation: configured")
          true
        else
          IO.puts("  ❌ #{name} instrumentation: NOT configured")
          false
        end
      end)

    Enum.all?(results)
  end

  defp validate_signoz_config do
    IO.puts("\n📋 Checking SigNoz-specific configuration...")
    signoz_config = Application.get_env(:indrajaal, :signoz, %{})

    enabled = signoz_config[:enabled]
    service_name = signoz_config[:service_name]
    environment = signoz_config[:environment]

    if enabled != false do
      IO.puts("  ✅ SigNoz enabled: #{enabled || true}")
      IO.puts("  ✅ Service name: #{service_name || "indrajaal"}")
      IO.puts("  ✅ Environment: #{environment || "development"}")
      true
    else
      IO.puts("  ❌ SigNoz: DISABLED")
      false
    end
  end
end

# Run the validator
LoggerOtelConfigValidator.run()
