defmodule Indrajaal.Cluster.Zenoh.TracePropagatorTest do
  @moduledoc """
  TDG-Compliant tests for TracePropagator module.

  Tests OTEL trace context propagation in Zenoh messages.

  STAMP Constraints:
  - SC-ZENOH-TRACE-001: Trace context in all cross-node messages
  - SC-ZENOH-TRACE-002: W3C Trace Context format
  - SC-OBS-069: Dual logging integration
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cluster.Zenoh.TracePropagator

  describe "TracePropagator.inject/1" do
    test "SC-ZENOH-TRACE-001: injects trace context into message" do
      message = %{type: :alarm_event, alarm_id: "alm-123"}

      result = TracePropagator.inject(message)

      assert Map.has_key?(result, :_trace_context)
      assert is_map(result._trace_context)
    end

    test "includes traceparent header" do
      message = %{data: "test"}

      result = TracePropagator.inject(message)

      assert Map.has_key?(result._trace_context, :traceparent)
      assert is_binary(result._trace_context.traceparent)
    end

    test "includes span_id and trace_id" do
      message = %{data: "test"}

      result = TracePropagator.inject(message)

      assert Map.has_key?(result._trace_context, :trace_id)
      assert Map.has_key?(result._trace_context, :span_id)
    end

    test "preserves original message data" do
      message = %{type: :test, value: 42, nested: %{key: "val"}}

      result = TracePropagator.inject(message)

      assert result.type == :test
      assert result.value == 42
      assert result.nested.key == "val"
    end

    test "works with binary message" do
      message = "binary payload"

      result = TracePropagator.inject(message)

      assert is_map(result)
      assert result.payload == "binary payload"
      assert Map.has_key?(result, :_trace_context)
    end
  end

  describe "TracePropagator.extract/1" do
    test "SC-ZENOH-TRACE-001: extracts trace context from message" do
      trace_context = %{
        traceparent: "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
        trace_id: "0af7651916cd43dd8448eb211c80319c",
        span_id: "b7ad6b7169203331"
      }

      message = %{data: "test", _trace_context: trace_context}

      {:ok, extracted} = TracePropagator.extract(message)

      assert extracted.trace_id == "0af7651916cd43dd8448eb211c80319c"
      assert extracted.span_id == "b7ad6b7169203331"
    end

    test "returns error for message without trace context" do
      message = %{data: "no trace"}

      assert {:error, :no_trace_context} = TracePropagator.extract(message)
    end

    test "returns error for invalid trace context" do
      message = %{data: "test", _trace_context: "invalid"}

      assert {:error, :invalid_trace_context} = TracePropagator.extract(message)
    end
  end

  describe "TracePropagator.create_child_span/2" do
    test "creates child span from parent context" do
      parent_context = %{
        trace_id: "0af7651916cd43dd8448eb211c80319c",
        span_id: "b7ad6b7169203331"
      }

      child = TracePropagator.create_child_span(parent_context, "child_operation")

      assert child.trace_id == parent_context.trace_id
      assert child.parent_span_id == parent_context.span_id
      assert child.span_id != parent_context.span_id
      assert child.operation == "child_operation"
    end

    test "generates new span_id for child" do
      parent_context = %{
        trace_id: "0af7651916cd43dd8448eb211c80319c",
        span_id: "b7ad6b7169203331"
      }

      child1 = TracePropagator.create_child_span(parent_context, "op1")
      child2 = TracePropagator.create_child_span(parent_context, "op2")

      assert child1.span_id != child2.span_id
    end
  end

  describe "TracePropagator.format_traceparent/1" do
    test "SC-ZENOH-TRACE-002: formats according to W3C Trace Context" do
      context = %{
        trace_id: "0af7651916cd43dd8448eb211c80319c",
        span_id: "b7ad6b7169203331",
        trace_flags: "01"
      }

      traceparent = TracePropagator.format_traceparent(context)

      # W3C format: version-trace_id-span_id-flags
      assert traceparent == "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    end

    test "uses default trace_flags if not provided" do
      context = %{
        trace_id: "abc123",
        span_id: "def456"
      }

      traceparent = TracePropagator.format_traceparent(context)

      assert String.ends_with?(traceparent, "-01")
    end
  end

  describe "TracePropagator.parse_traceparent/1" do
    test "parses valid traceparent header" do
      traceparent = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

      {:ok, context} = TracePropagator.parse_traceparent(traceparent)

      assert context.version == "00"
      assert context.trace_id == "0af7651916cd43dd8448eb211c80319c"
      assert context.span_id == "b7ad6b7169203331"
      assert context.trace_flags == "01"
    end

    test "returns error for invalid format" do
      # Only 2 parts - definitely invalid format
      invalid = "invalid-format"

      assert {:error, :invalid_traceparent} = TracePropagator.parse_traceparent(invalid)
    end

    test "returns error for wrong version" do
      wrong_version = "99-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

      assert {:error, :unsupported_version} = TracePropagator.parse_traceparent(wrong_version)
    end
  end

  describe "TracePropagator.generate_trace_id/0" do
    test "generates 32-character hex string" do
      trace_id = TracePropagator.generate_trace_id()

      assert String.length(trace_id) == 32
      assert String.match?(trace_id, ~r/^[0-9a-f]+$/)
    end

    test "generates unique ids" do
      ids = for _ <- 1..100, do: TracePropagator.generate_trace_id()
      unique_ids = Enum.uniq(ids)

      assert length(unique_ids) == 100
    end
  end

  describe "TracePropagator.generate_span_id/0" do
    test "generates 16-character hex string" do
      span_id = TracePropagator.generate_span_id()

      assert String.length(span_id) == 16
      assert String.match?(span_id, ~r/^[0-9a-f]+$/)
    end

    test "generates unique ids" do
      ids = for _ <- 1..100, do: TracePropagator.generate_span_id()
      unique_ids = Enum.uniq(ids)

      assert length(unique_ids) == 100
    end
  end

  describe "TracePropagator with_span/3" do
    test "creates span and yields to function" do
      result =
        TracePropagator.with_span("test_operation", fn context ->
          assert Map.has_key?(context, :trace_id)
          assert Map.has_key?(context, :span_id)
          {:ok, "result"}
        end)

      assert result == {:ok, "result"}
    end

    test "propagates errors from function" do
      result =
        TracePropagator.with_span("failing_op", fn _context ->
          {:error, :something_went_wrong}
        end)

      assert result == {:error, :something_went_wrong}
    end
  end
end
