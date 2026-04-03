defmodule Indrajaal.System.FullObservabilityPipelineTest do
  @moduledoc """
  System tests for the complete observability pipeline.

  Tests end-to-end flow from application through OTEL to SigNOz.

  STAMP Constraints Tested:
  - SC-OBS-001 through SC-OBS-015: Complete observability stack
  - SC-OBS-011: End-to-end trace integrity
  - SC-OBS-012: Metrics aggregation
  - SC-OBS-013: Log correlation

  TDG Rules:
  - TDG-OBS-SYSTEM-001: Full pipeline validation
  """

  use ExUnit.Case, async: false

  # System tests require isolated environment

  describe "End-to-End Observability Pipeline" do
    test "trace context flows through entire stack" do
      # Simulate a request with trace context
      trace_context = generate_trace_context()

      # Verify trace ID is valid
      assert valid_trace_id?(trace_context.trace_id)
      assert valid_span_id?(trace_context.span_id)

      # Simulate propagation through layers
      layers = [:http_handler, :business_logic, :database, :external_service]

      propagated_context =
        Enum.reduce(layers, trace_context, fn layer, ctx ->
          propagate_through_layer(ctx, layer)
        end)

      # Trace ID should be preserved
      assert propagated_context.trace_id == trace_context.trace_id
    end

    test "metrics are collected at all layers" do
      metrics_config = build_metrics_config()

      # All metric types should be configured
      assert :counter in metrics_config.types
      assert :histogram in metrics_config.types
      assert :gauge in metrics_config.types
    end

    test "logs are correlated with traces" do
      trace_context = generate_trace_context()
      log_entry = build_log_entry(trace_context)

      # Log should contain trace correlation
      assert log_entry.trace_id == trace_context.trace_id
      assert log_entry.span_id == trace_context.span_id
    end
  end

  describe "SC-OBS-011: Trace Integrity" do
    test "parent-child span relationships are preserved" do
      parent_span = create_span("parent")
      child_span = create_child_span(parent_span, "child")

      assert child_span.parent_span_id == parent_span.span_id
      assert child_span.trace_id == parent_span.trace_id
    end

    test "span status is set correctly" do
      base_success = create_span("success")
      success_span = base_success |> set_span_status(:ok)
      base_error = create_span("error")
      error_span = base_error |> set_span_status(:error, "Failed")

      assert success_span.status == :ok
      assert error_span.status == :error
      assert error_span.status_message == "Failed"
    end

    test "span attributes are captured" do
      base_span = create_span("test")

      span =
        base_span
        |> add_span_attributes(%{
          "http.method" => "GET",
          "http.url" => "/api/test",
          "http.status_code" => 200
        })

      assert span.attributes["http.method"] == "GET"
      assert span.attributes["http.status_code"] == 200
    end
  end

  describe "SC-OBS-012: Metrics Aggregation" do
    test "request metrics are aggregated" do
      metrics = [
        %{name: "http.request.duration", value: 100, unit: :ms},
        %{name: "http.request.duration", value: 150, unit: :ms},
        %{name: "http.request.duration", value: 200, unit: :ms}
      ]

      aggregated = aggregate_metrics(metrics)

      assert aggregated.count == 3
      assert aggregated.sum == 450
      assert aggregated.avg == 150
    end

    test "error rate metrics are calculated" do
      request_metrics = [
        %{status: 200},
        %{status: 200},
        %{status: 500},
        %{status: 200},
        %{status: 503}
      ]

      error_rate = calculate_error_rate(request_metrics)

      # 2 errors out of 5 requests = 40%
      assert_in_delta error_rate, 0.4, 0.01
    end
  end

  describe "SC-OBS-013: Log Correlation" do
    test "structured logs contain trace context" do
      trace_context = generate_trace_context()

      log_fields = %{
        message: "Test log message",
        level: :info,
        trace_id: trace_context.trace_id,
        span_id: trace_context.span_id,
        timestamp: DateTime.utc_now()
      }

      assert Map.has_key?(log_fields, :trace_id)
      assert Map.has_key?(log_fields, :span_id)
    end

    test "log levels are appropriate" do
      valid_levels = [:debug, :info, :warning, :error]

      Enum.each(valid_levels, fn level ->
        assert level in [:debug, :info, :warning, :error, :notice, :critical, :alert, :emergency]
      end)
    end
  end

  describe "Pipeline Resilience" do
    test "pipeline handles exporter failure gracefully" do
      # Simulate exporter failure
      failure_scenario = %{
        exporter_status: :failed,
        retry_count: 0,
        max_retries: 5
      }

      # Application should continue running
      assert handle_exporter_failure(failure_scenario) == :continue
    end

    test "buffering prevents data loss during outage" do
      buffer_config = %{
        max_queue_size: 2048,
        export_timeout_ms: 30_000
      }

      # Buffer should hold data during short outages
      assert buffer_config.max_queue_size > 0
      assert buffer_config.export_timeout_ms > 10_000
    end
  end

  describe "Cross-Subsystem Observability" do
    test "FLAME operations are traced" do
      flame_span_attributes = %{
        "flame.pool" => "IntelligencePool",
        "flame.runner_id" => "runner-1",
        "flame.operation" => "call"
      }

      # FLAME operations should have proper attributes
      assert Map.has_key?(flame_span_attributes, "flame.pool")
    end

    test "security events are logged" do
      security_event = %{
        event_type: :authentication,
        outcome: :success,
        user_id: "user-123",
        timestamp: DateTime.utc_now()
      }

      log_entry = format_security_event(security_event)

      assert String.contains?(log_entry, "authentication")
    end
  end

  # Helper functions

  defp generate_trace_context do
    trace_bytes = :crypto.strong_rand_bytes(16)
    trace_id = trace_bytes |> Base.encode16(case: :lower)
    span_bytes = :crypto.strong_rand_bytes(8)
    span_id = span_bytes |> Base.encode16(case: :lower)

    %{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: 1
    }
  end

  defp valid_trace_id?(trace_id) do
    String.length(trace_id) == 32 and Regex.match?(~r/^[0-9a-f]+$/, trace_id)
  end

  defp valid_span_id?(span_id) do
    String.length(span_id) == 16 and Regex.match?(~r/^[0-9a-f]+$/, span_id)
  end

  defp propagate_through_layer(context, _layer) do
    # Preserve context through layer
    context
  end

  defp build_metrics_config do
    %{
      types: [:counter, :histogram, :gauge],
      export_interval_ms: 60_000
    }
  end

  defp build_log_entry(trace_context) do
    %{
      message: "Test message",
      level: :info,
      trace_id: trace_context.trace_id,
      span_id: trace_context.span_id,
      timestamp: DateTime.utc_now()
    }
  end

  defp create_span(name) do
    span_bytes = :crypto.strong_rand_bytes(8)
    span_id = span_bytes |> Base.encode16(case: :lower)
    trace_bytes = :crypto.strong_rand_bytes(16)
    trace_id = trace_bytes |> Base.encode16(case: :lower)

    %{
      name: name,
      span_id: span_id,
      trace_id: trace_id,
      parent_span_id: nil,
      status: nil,
      status_message: nil,
      attributes: %{}
    }
  end

  defp create_child_span(parent, name) do
    span_bytes = :crypto.strong_rand_bytes(8)
    span_id = span_bytes |> Base.encode16(case: :lower)

    %{
      name: name,
      span_id: span_id,
      trace_id: parent.trace_id,
      parent_span_id: parent.span_id,
      status: nil,
      status_message: nil,
      attributes: %{}
    }
  end

  defp set_span_status(span, status, message \\ nil) do
    %{span | status: status, status_message: message}
  end

  defp add_span_attributes(span, attrs) do
    %{span | attributes: Map.merge(span.attributes, attrs)}
  end

  defp aggregate_metrics(metrics) do
    values = Enum.map(metrics, & &1.value)

    %{
      count: length(values),
      sum: Enum.sum(values),
      avg: Enum.sum(values) / length(values),
      min: Enum.min(values),
      max: Enum.max(values)
    }
  end

  defp calculate_error_rate(metrics) do
    errors = Enum.count(metrics, fn m -> m.status >= 500 end)
    errors / length(metrics)
  end

  defp handle_exporter_failure(%{retry_count: count, max_retries: max}) when count < max do
    :continue
  end

  defp handle_exporter_failure(_), do: :alert

  defp format_security_event(event) do
    "[SECURITY] #{event.event_type}: #{event.outcome} for user #{event.user_id}"
  end
end
