defmodule Indrajaal.Observability.Domains.DispatchInstrumentationTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.Domains.DispatchInstrumentation.

  ## STAMP Safety Integration
  - SC-OBS-065: Observability for all domain operations

  ## TPS 5-Level RCA Context
  - L1 Symptom: Dispatch operations without telemetry
  - L5 Root Cause: Missing domain-specific instrumentation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.Domains.DispatchInstrumentation

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DispatchInstrumentation)
    end

    test "setup/0 exported" do
      assert function_exported?(DispatchInstrumentation, :setup, 0)
    end
  end

  describe "setup/0" do
    test "returns :ok" do
      result = DispatchInstrumentation.setup()
      assert result == :ok
    end

    test "is idempotent (calling twice does not crash)" do
      # First call
      DispatchInstrumentation.setup()
      # Second call should not crash (telemetry already attached)
      result = DispatchInstrumentation.setup()
      assert result == :ok
    end
  end
end
