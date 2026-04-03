defmodule Indrajaal.Observability.Domains.AssetManagementInstrumentationTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.Domains.AssetManagementInstrumentation.

  ## STAMP Safety Integration
  - SC-OBS-065: Observability for all domain operations

  ## TPS 5-Level RCA Context
  - L1 Symptom: Asset lifecycle events without telemetry
  - L5 Root Cause: Missing asset management domain instrumentation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.Domains.AssetManagementInstrumentation

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AssetManagementInstrumentation)
    end

    test "setup/0 exported" do
      assert function_exported?(AssetManagementInstrumentation, :setup, 0)
    end
  end

  describe "setup/0" do
    test "returns :ok" do
      result = AssetManagementInstrumentation.setup()
      assert result == :ok
    end

    test "is idempotent" do
      AssetManagementInstrumentation.setup()
      result = AssetManagementInstrumentation.setup()
      assert result == :ok
    end
  end
end
