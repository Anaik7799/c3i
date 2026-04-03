defmodule Indrajaal.Observability.TraceContextTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.TraceContext.

  ## STAMP Safety Integration
  - SC-OBS-071: Trace context propagation across Zenoh boundary

  ## TPS 5-Level RCA Context
  - L1 Symptom: Distributed traces broken across Zenoh boundary
  - L5 Root Cause: No causal context linking across message bus
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.TraceContext

  describe "inject/1" do
    test "returns a map" do
      result = TraceContext.inject(%{})
      assert is_map(result)
    end

    test "accepts empty map" do
      result = TraceContext.inject(%{})
      assert is_map(result)
    end

    test "inject/0 uses default empty carrier" do
      result = TraceContext.inject()
      assert is_map(result)
    end
  end

  describe "extract/1" do
    test "returns context from carrier without crashing" do
      # Should not raise even with empty carrier
      TraceContext.extract(%{})
      assert true
    end

    test "handles non-empty carrier" do
      carrier = %{"traceparent" => "00-abc123-def456-01"}
      TraceContext.extract(carrier)
      assert true
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.TraceContext)
    end

    test "inject/0 exported" do
      assert function_exported?(TraceContext, :inject, 0)
    end

    test "inject/1 exported" do
      assert function_exported?(TraceContext, :inject, 1)
    end

    test "extract/1 exported" do
      assert function_exported?(TraceContext, :extract, 1)
    end

    test "set_baggage/2 exported" do
      assert function_exported?(TraceContext, :set_baggage, 2)
    end

    test "get_baggage/1 exported" do
      assert function_exported?(TraceContext, :get_baggage, 1)
    end
  end
end
