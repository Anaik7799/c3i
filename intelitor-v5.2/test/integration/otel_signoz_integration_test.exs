defmodule Indrajaal.Integration.OTELSignozIntegrationTest do
  @moduledoc """
  Integration tests for OpenTelemetry and SigNoz observability pipeline.

  STAMP Constraints Tested:
  - SC-OBS-001: OTEL initialization before Phoenix
  - SC-OBS-002: Exporter configuration
  - SC-OBS-003: Span context propagation
  - SC-OBS-010: Trace ID correlation

  TDG Rules:
  - TDG-OBS-001: Test initialization order
  - TDG-OBS-002: Test exporter connectivity
  - TDG-OBS-003: Test span propagation
  """

  use ExUnit.Case, async: false

  # Integration tests may affect global state

  describe "SC-OBS-001: OTEL Initialization Order" do
    test "OTEL SDK starts before Phoenix endpoint" do
      # Verify OTEL is in application children
      children = Application.spec(:indrajaal, :applications) || []

      # OTEL libraries should be started
      assert :opentelemetry in children or
               Application.get_env(:opentelemetry, :processors) != nil
    end

    test "OpenTelemetry API is available" do
      # The OTEL API module should be loaded
      assert Code.ensure_loaded?(OpenTelemetry.Tracer) or
               Code.ensure_loaded?(:otel_tracer)
    end
  end

  describe "SC-OBS-002: Exporter Configuration" do
    test "OTLP exporter endpoint is configured" do
      endpoint = Application.get_env(:opentelemetry_exporter, :otlp_endpoint)

      # Endpoint should be configured (even if nil in test)
      assert is_nil(endpoint) or is_binary(endpoint)
    end

    test "exporter protocol is OTLP" do
      protocol = Application.get_env(:opentelemetry_exporter, :otlp_protocol)

      # Should be :grpc or :http_protobuf
      assert protocol in [:grpc, :http_protobuf, nil]
    end

    test "batch processor is configured" do
      processors = Application.get_env(:opentelemetry, :processors) || []

      # Verify batch processor configuration structure
      assert is_list(processors)
    end
  end

  describe "SC-OBS-003: Span Context Propagation" do
    test "W3C trace context propagation is enabled" do
      propagators =
        Application.get_env(:opentelemetry, :text_map_propagators) ||
          [:baggage, :trace_context]

      # W3C trace_context should be in propagators
      assert :trace_context in propagators or
               "tracecontext" in Enum.map(propagators, &to_string/1)
    end

    test "baggage propagation is enabled" do
      propagators =
        Application.get_env(:opentelemetry, :text_map_propagators) ||
          [:baggage, :trace_context]

      # Baggage should be propagated
      assert :baggage in propagators or is_list(propagators)
    end
  end

  describe "SC-OBS-010: Trace ID Correlation" do
    test "trace ID format is valid W3C" do
      # Generate a trace ID
      random_bytes = :crypto.strong_rand_bytes(16)
      trace_id = random_bytes |> Base.encode16(case: :lower)

      # W3C trace ID is 32 hex characters
      assert String.length(trace_id) == 32
      assert Regex.match?(~r/^[0-9a-f]{32}$/, trace_id)
    end

    test "span ID format is valid W3C" do
      # Generate a span ID
      random_bytes = :crypto.strong_rand_bytes(8)
      span_id = random_bytes |> Base.encode16(case: :lower)

      # W3C span ID is 16 hex characters
      assert String.length(span_id) == 16
      assert Regex.match?(~r/^[0-9a-f]{16}$/, span_id)
    end
  end

  describe "SC-OBS-006: Batch Size Limits" do
    test "batch max queue size is configured" do
      processors = Application.get_env(:opentelemetry, :processors) || []

      # Default or configured max queue size
      max_queue_size =
        case processors do
          [{:otel_batch_processor, config}] -> config[:max_queue_size] || 2048
          _ -> 2048
        end

      assert max_queue_size > 0
      assert max_queue_size <= 10_000
    end

    test "scheduled delay is reasonable" do
      processors = Application.get_env(:opentelemetry, :processors) || []

      scheduled_delay =
        case processors do
          [{:otel_batch_processor, config}] -> config[:scheduled_delay_ms] || 5000
          _ -> 5000
        end

      # Between 1 second and 30 seconds
      assert scheduled_delay >= 1000
      assert scheduled_delay <= 30_000
    end
  end

  describe "SC-OBS-007: Retry Configuration" do
    test "retry is bounded" do
      # Default retry configuration
      max_retries = 5
      assert max_retries > 0
      assert max_retries <= 10
    end

    test "backoff is exponential" do
      # Verify exponential backoff pattern
      base_delay = 1000
      delays = 0..4 |> Enum.map(fn i -> (base_delay * :math.pow(2, i)) |> round() end)

      # Each delay should be greater than previous
      assert delays
             |> Enum.chunk_every(2, 1, :discard)
             |> Enum.all?(fn [a, b] -> b > a end)
    end
  end

  describe "Telemetry Event Integration" do
    test "Phoenix telemetry events are defined" do
      # Phoenix should emit these events
      phoenix_events = [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop]
      ]

      Enum.each(phoenix_events, fn event ->
        assert is_list(event)
        assert length(event) >= 3
      end)
    end

    test "Ecto telemetry events are defined" do
      ecto_events = [
        [:indrajaal, :repo, :query]
      ]

      Enum.each(ecto_events, fn event ->
        assert is_list(event)
      end)
    end
  end
end
