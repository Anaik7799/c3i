defmodule Indrajaal.Observability.Domains.ComplianceInstrumentationTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.Domains.ComplianceInstrumentation.

  ## STAMP Safety Integration
  - SC-OBS-065: Observability for all domain operations

  ## TPS 5-Level RCA Context
  - L1 Symptom: Compliance events without audit trail
  - L5 Root Cause: Missing compliance domain instrumentation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.Domains.ComplianceInstrumentation

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ComplianceInstrumentation)
    end

    test "setup/0 exported" do
      assert function_exported?(ComplianceInstrumentation, :setup, 0)
    end
  end

  describe "setup/0" do
    test "returns :ok" do
      result = ComplianceInstrumentation.setup()
      assert result == :ok
    end

    test "is idempotent" do
      ComplianceInstrumentation.setup()
      result = ComplianceInstrumentation.setup()
      assert result == :ok
    end
  end
end
