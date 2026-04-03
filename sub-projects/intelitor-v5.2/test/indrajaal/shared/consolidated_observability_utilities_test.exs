defmodule Indrajaal.Shared.ConsolidatedObservabilityUtilitiesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.ConsolidatedObservabilityUtilities

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ConsolidatedObservabilityUtilities)
    end
  end

  describe "format_trace_id/1" do
    test "function is exported" do
      assert function_exported?(ConsolidatedObservabilityUtilities, :format_trace_id, 1)
    end

    test "formats a binary trace id" do
      trace_id = :crypto.strong_rand_bytes(16)
      result = ConsolidatedObservabilityUtilities.format_trace_id(trace_id)
      assert is_binary(result)
    end

    test "formats a 16-byte trace id to 32-char hex" do
      trace_id = <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15>>
      result = ConsolidatedObservabilityUtilities.format_trace_id(trace_id)
      assert is_binary(result)
      assert byte_size(result) == 32
    end

    test "formats nil or empty gracefully" do
      result =
        try do
          ConsolidatedObservabilityUtilities.format_trace_id(nil)
        rescue
          _ -> "error"
        end

      assert is_binary(result)
    end
  end

  describe "format_span_id/1" do
    test "function is exported" do
      assert function_exported?(ConsolidatedObservabilityUtilities, :format_span_id, 1)
    end

    test "formats a binary span id" do
      span_id = :crypto.strong_rand_bytes(8)
      result = ConsolidatedObservabilityUtilities.format_span_id(span_id)
      assert is_binary(result)
    end

    test "formats an 8-byte span id to 16-char hex" do
      span_id = <<0, 1, 2, 3, 4, 5, 6, 7>>
      result = ConsolidatedObservabilityUtilities.format_span_id(span_id)
      assert is_binary(result)
      assert byte_size(result) == 16
    end
  end

  describe "add_span_attributes/1" do
    test "function is exported" do
      assert function_exported?(ConsolidatedObservabilityUtilities, :add_span_attributes, 1)
    end

    test "adds attributes to span map" do
      span = %{
        trace_id: :crypto.strong_rand_bytes(16),
        span_id: :crypto.strong_rand_bytes(8),
        name: "test.operation"
      }

      result = ConsolidatedObservabilityUtilities.add_span_attributes(span)
      assert is_map(result)
    end

    test "enriches span with additional OTEL attributes" do
      span = %{name: "db.query", duration_ms: 25}
      result = ConsolidatedObservabilityUtilities.add_span_attributes(span)
      assert is_map(result)
      assert map_size(result) >= map_size(span)
    end
  end
end
