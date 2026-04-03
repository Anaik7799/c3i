defmodule Indrajaal.Observability.Domains.ShiftsInstrumentationTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.Domains.ShiftsInstrumentation.

  ## STAMP Safety Integration
  - SC-OBS-065: Observability for all domain operations
  - SC-OBS-066: Audit trail for shift management changes

  ## TPS 5-Level RCA Context
  - L1 Symptom: Shift management changes without telemetry
  - L5 Root Cause: Missing shifts domain instrumentation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.Domains.ShiftsInstrumentation

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ShiftsInstrumentation)
    end

    test "setup/0 exported" do
      assert function_exported?(ShiftsInstrumentation, :setup, 0)
    end
  end

  describe "setup/0" do
    test "returns :ok" do
      result = ShiftsInstrumentation.setup()
      assert result == :ok
    end

    test "is idempotent" do
      ShiftsInstrumentation.setup()
      result = ShiftsInstrumentation.setup()
      assert result == :ok
    end
  end
end
