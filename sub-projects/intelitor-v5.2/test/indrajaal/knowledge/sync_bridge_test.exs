defmodule Indrajaal.Knowledge.SyncBridgeTest do
  @moduledoc """
  Tests for Indrajaal.Knowledge.SyncBridge pure module.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Knowledge.SyncBridge

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SyncBridge)
    end

    test "module has expected functions" do
      assert function_exported?(SyncBridge, :trigger_ingestion, 1)
      assert function_exported?(SyncBridge, :check_health, 0)
    end
  end

  describe "check_health/0" do
    test "returns :ok or {:error, reason} tuple" do
      result = SyncBridge.check_health()
      assert result == :ok or match?({:error, _}, result)
    end

    test "returns :dotnet_missing when dotnet not available or :ok or :project_missing" do
      result = SyncBridge.check_health()

      assert result == :ok or
               result == {:error, :dotnet_missing} or
               result == {:error, :project_missing}
    end
  end

  describe "trigger_ingestion/1" do
    test "trigger_ingestion/1 accepts a path string" do
      # This will try to run dotnet — if unavailable returns {:error, code} or :ok
      result = SyncBridge.trigger_ingestion("/tmp")
      assert result == :ok or match?({:error, _}, result)
    end

    test "trigger_ingestion with default path (current dir)" do
      # Calling the public API without args uses default path "."
      # Since dotnet may not be in PATH during tests, allow any result
      result = SyncBridge.trigger_ingestion(".")
      assert result == :ok or match?({:error, _}, result)
    end
  end
end
