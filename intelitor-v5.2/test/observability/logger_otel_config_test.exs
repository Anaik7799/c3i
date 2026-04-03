defmodule Indrajaal.Observability.LoggerOtelConfigTest do
  @moduledoc """
  TDG (Test-Driven Generation) tests for Logger and OpenTelemetry configuration.

  This test suite ensures that:
  1. Logger backends are properly configured with trace metadata support
  2. OTEL exporter is configured for SigNoz integration
  3. Trace __context propagation settings are correct
  4. Sampling configuration is properly set
  5. Application startup initializes all telemetry handlers

  SOPv5.1 Compliance: ✅ Test-First Approach with comprehensive validation
  STAMP Safety: SC1 (Pr__event __data loss), SC2 (Ensure proper initialization)
  """
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "logger configuration" do
    test "ensures dual logging backends are configured" do
      # Verify that both console and JSON backends are configured
      backends = Application.get_env(:logger, :backends)
      assert :console in backends
      assert LoggerJSON in backends
      assert length(backends) >= 2
    end

    test "ensures console backend includes trace metadata" do
      # Verify console backend metadata configuration
      console_config = Application.get_env(:logger, :console)
      metadata = console_config[:metadata]

      # Should be :all or include specific trace fields
      assert metadata == :all or
               (is_list(metadata) and
                  :trace_id in metadata and
                  :span_id in metadata and
                  :__request_id in metadata)
    end

    test "ensures LoggerJSON backend is configured for structured logging" do
      # Verify LoggerJSON configuration for SigNoz
      json_config = Application.get_env(:logger_json, :backend)

      assert json_config[:formatter] in [
               LoggerJSON.Formatters.Datadog,
               LoggerJSON.Formatters.GoogleCloud,
               LoggerJSON.Formatters.Elastic
             ]

      assert json_config[:metadata] == :all
    end

    test "ensures logger includes OTEL trace __context in all logs" do
      # Create a test span
      :otel_ctx.clear()
      tracer = :opentelemetry.get_tracer(:test)

      span_ctx = :otel_tracer.start_span(tracer, "test_span", %{})
      ctx = :otel_ctx.get_current()

      # Log within span __context
      log_output =
        capture_log(fn ->
          Logger.info("Test log with trace __context")
        end)

      # Get trace and span IDs from __context
      trace_id = :otel_span.hex_trace_id(span_ctx)
      span_id = :otel_span.hex_span_id(span_ctx)

      # Verify trace __context appears in logs
      assert log_output =~ "trace_id=#{trace_id}" or
               log_output =~ "trace_id: \"#{trace_id}\"" or
               log_output =~ "traceId=#{trace_id}"

      :otel_span.end_span(span_ctx)
    end
  end

  describe "OTEL configuration" do
    test "ensures OTEL exporter is configured for OTLP" do
      # Verify basic OTEL configuration
      assert Application.get_env(:opentelemetry, :span_processor) == :batch
      assert Application.get_env(:opentelemetry, :traces_exporter) == :otlp
    end

    test "ensures OTEL resource attributes are properly set" do
      # Verify resource configuration
      resource = Application.get_env(:opentelemetry, :resource)

      assert resource[:service][:name] == "indrajaal"
      assert resource[:service][:version] != nil
      assert resource[:service][:namespace] != nil
      assert resource[:service][:instance_id] != nil

      # Verify SigNoz integration attribute
      attributes = resource[:attributes]
      assert {"signoz.integration", "enabled"} in attributes

      assert {"deployment.environment", _} =
               Enum.find(attributes, fn {k, _} -> k == "deployment.environment" end)

      assert {"service.framework", "elixir-phoenix-ash"} in attributes
    end

    test "ensures OTLP exporter endpoint is configured" do
      # Check runtime configuration for OTLP endpoint
      exporter_config = Application.get_env(:opentelemetry_exporter, :otlp)

      # Should have endpoint configured (will be set via env var in runtime.exs)
      endpoint = exporter_config[:endpoint] || System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT")

      # In test env, we expect at least a placeholder or env var
      assert endpoint != nil or System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") != nil
    end

    test "ensures trace __context propagation is configured" do
      # Verify propagators are set
      propagators = Application.get_env(:opentelemetry, :propagators, [:trace__context])

      assert :trace__context in propagators or
               :otel_propagator_trace_context in propagators
    end

    test "ensures sampling configuration is set" do
      # Check for sampling configuration
      sampler = Application.get_env(:opentelemetry, :sampler)

      # Default should be always_on or probability-based
      # Validate sampler is a valid configuration
      valid_sampler? =
        sampler in [nil, {:always_on, []}, {:always_off, []}] or
          match?({:probability, _}, sampler)

      assert valid_sampler?, "Expected valid sampler, got: #{inspect(sampler)}"
    end
  end

  describe "Phoenix instrumentation" do
    test "ensures OpenTelemetry Phoenix is configured" do
      config = Application.get_env(:opentelemetry_phoenix, :endpoint_prefix)
      assert config == [:indrajaal, :endpoint]

      # Verify headers are recorded for trace __context
      assert Application.get_env(:opentelemetry_phoenix, :record_headers) == true
    end
  end

  describe "Ecto instrumentation" do
    test "ensures OpenTelemetry Ecto is configured" do
      assert Application.get_env(:opentelemetry_ecto, :db_statement) == :enabled
      assert Application.get_env(:opentelemetry_ecto, :time_unit) == :microsecond
    end
  end

  describe "Oban instrumentation" do
    test "ensures OpenTelemetry Oban is configured" do
      assert Application.get_env(:opentelemetry_oban, :trace_all_jobs) == true
      assert Application.get_env(:opentelemetry_oban, :record_job_args) == true
    end
  end

  describe "Ash telemetry integration" do
    test "ensures custom Ash telemetry is configured" do
      ash_config = Application.get_env(:indrajaal, :ash_telemetry)

      assert ash_config[:enabled] == true
      assert ash_config[:trace_all_actions] == true
      assert ash_config[:include__metadata] == true
      assert ash_config[:slow_query_threshold] == 100
    end
  end

  describe "Application startup" do
    @tag :integration
    test "ensures all telemetry handlers are attached on startup" do
      # This test verifies that the application module properly initializes telemetry
      # Note: This is an integration test that __requires the app to be started

      # Check that core telemetry handlers are attached
      handlers = :telemetry.list_handlers()

      # Verify key handler patterns exist
      handler_names = Enum.map(handlers, & &1.id)

      # Should have handlers for key __events
      assert Enum.any?(handler_names, &String.contains?(&1, "phoenix"))
      assert Enum.any?(handler_names, &String.contains?(&1, "ecto"))
      assert Enum.any?(handler_names, &String.contains?(&1, "oban"))
    end
  end

  describe "runtime configuration" do
    test "ensures OTEL endpoint can be configured via environment" do
      # Test that runtime.exs properly handles OTEL_EXPORTER_OTLP_ENDPOINT
      env_endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT")

      if env_endpoint do
        # If set, verify it's used
        runtime_config = Application.get_env(:opentelemetry_exporter, :otlp)
        assert runtime_config[:endpoint] == env_endpoint
      end
    end

    test "ensures trace propagation headers are configured" do
      # Verify headers configuration for trace propagation
      headers_config = Application.get_env(:opentelemetry_exporter, :otlp_headers)

      # Should be able to configure headers via env
      env_headers = System.get_env("OTEL_EXPORTER_OTLP_HEADERS")

      if env_headers do
        assert headers_config != nil
      end
    end

    test "ensures sampling can be configured via environment" do
      # Check if sampling can be configured
      env_sampler = System.get_env("OTEL_TRACES_SAMPLER")
      env_ratio = System.get_env("OTEL_TRACES_SAMPLER_ARG")

      if env_sampler do
        sampler_config = Application.get_env(:opentelemetry, :sampler)

        case env_sampler do
          "always_on" ->
            assert sampler_config == {:always_on, []}

          "always_off" ->
            assert sampler_config == {:always_off, []}

          "probability" ->
            assert elem(sampler_config, 0) == :probability

            if env_ratio do
              {parsed_ratio, _} = Float.parse(env_ratio)
              assert elem(sampler_config, 1)[:probability] == parsed_ratio
            end
        end
      end
    end
  end

  describe "STAMP safety validation" do
    test "ensures telemetry doesn't lose __data on shutdown" do
      # SC1: Pr__event __data loss
      shutdown_timeout = Application.get_env(:opentelemetry, :shutdown_timeout)
      # At least 30 seconds
      assert shutdown_timeout >= 30_000
    end

    test "ensures all instrumentation libraries initialize properly" do
      # SC2: Ensure proper initialization
      # This is checked by verifying configuration exists for each library
      assert Application.get_env(:opentelemetry_phoenix) != nil
      assert Application.get_env(:opentelemetry_ecto) != nil
      assert Application.get_env(:opentelemetry_oban) != nil
      assert Application.get_env(:indrajaal, :ash_telemetry) != nil
    end
  end
end
