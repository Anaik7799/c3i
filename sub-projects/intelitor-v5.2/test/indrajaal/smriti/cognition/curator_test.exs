defmodule Indrajaal.Smriti.Cognition.CuratorTest do
  @moduledoc """
  TDG test suite for Smriti.Cognition.Curator.

  ## STAMP Safety Integration
  - SC-AI-001: AI agents persist context via SMRITI
  - SC-SMRITI-001: Vector search latency < 100ms

  ## TPS 5-Level RCA Context
  - L1 Symptom: Knowledge curation fails silently
  - L5 Root Cause: Missing entropy threshold enforcement
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Smriti.Cognition.Curator

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Curator)
    end

    test "start_link/1 is exported" do
      assert function_exported?(Curator, :start_link, 1)
    end

    test "curate/2 is exported" do
      assert function_exported?(Curator, :curate, 2)
    end
  end

  describe "start_link/1 lifecycle" do
    test "starts successfully with empty opts" do
      name = :"curator_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(Curator, [], name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end

  describe "curate/2 without running server" do
    test "returns error when GenServer is not started" do
      result =
        try do
          Curator.curate("test content", %{})
        rescue
          _ -> {:error, :server_not_running}
        catch
          :exit, _ -> {:error, :server_not_running}
        end

      assert match?({:error, _}, result)
    end
  end
end
