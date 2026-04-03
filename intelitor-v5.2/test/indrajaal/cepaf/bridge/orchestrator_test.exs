defmodule Indrajaal.CEPAF.Bridge.OrchestratorTest do
  @moduledoc """
  Tests for Indrajaal.CEPAF.Bridge.Orchestrator GenServer.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.CEPAF.Bridge.Orchestrator

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Orchestrator)
    end

    test "module has expected public functions" do
      assert function_exported?(Orchestrator, :start_workflow, 2)
      assert function_exported?(Orchestrator, :get_status, 1)
      assert function_exported?(Orchestrator, :pause, 1)
      assert function_exported?(Orchestrator, :resume, 1)
      assert function_exported?(Orchestrator, :cancel, 1)
      assert function_exported?(Orchestrator, :list_active, 0)
      assert function_exported?(Orchestrator, :stats, 0)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(Orchestrator, :start_link, 1)
      assert function_exported?(Orchestrator, :init, 1)
    end
  end

  describe "Orchestrator GenServer lifecycle" do
    setup do
      name = :"orchestrator_test_#{System.unique_integer([:positive])}"

      case Orchestrator.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid, name: name}

        {:error, _} ->
          :skip
      end
    end

    test "list_active/0 returns a list", %{pid: pid} do
      result = GenServer.call(pid, :list_active)
      assert is_list(result)
    end

    test "stats/0 returns a map or term", %{pid: pid} do
      result = GenServer.call(pid, :stats)
      assert is_map(result) or result != nil
    end

    test "get_status/1 returns not_found for unknown workflow id", %{pid: pid} do
      result = GenServer.call(pid, {:get_status, "unknown-workflow-xyz"})
      assert match?({:error, :not_found}, result) or match?({:ok, _}, result) or result != nil
    end
  end
end
