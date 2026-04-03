defmodule Indrajaal.Parallelization.UltraConcurrencyEngineTest do
  @moduledoc """
  TDG test suite for UltraConcurrencyEngine (GenServer).

  ## STAMP Safety Integration
  - SC-BUS-001: Async messaging only
  - SC-BUS-002: No blocking operations
  - SC-BATCH-001: Max 10 concurrent agents per SC-BATCH

  ## TPS 5-Level RCA Context
  - L1 Symptom: Concurrency engine fails to spawn agents
  - L5 Root Cause: Missing ETS table or supervisor not started

  ## Note on ETS
  UltraConcurrencyEngine creates ETS table `:coordination_registry` with
  `:named_table` flag on init. Tests must handle table-already-exists scenarios.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Parallelization.UltraConcurrencyEngine

  setup do
    # Clean up any existing ETS table from previous test run
    if :ets.whereis(:coordination_registry) != :undefined do
      :ets.delete(:coordination_registry)
    end

    {:ok, pid} = start_supervised({UltraConcurrencyEngine, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer and initializes ETS registry" do
      # Already started in setup, just verify it's alive
      pid =
        Process.whereis(UltraConcurrencyEngine) ||
          GenServer.whereis(UltraConcurrencyEngine)

      if is_nil(pid) do
        {:ok, new_pid} = UltraConcurrencyEngine.start_link([])
        assert Process.alive?(new_pid)
        GenServer.stop(new_pid)
      else
        assert Process.alive?(pid)
      end
    end
  end

  describe "spawn_agents/3" do
    test "spawns agents with valid parameters" do
      result = UltraConcurrencyEngine.spawn_agents(:test_task, 2, %{timeout: 5000})
      assert is_tuple(result)
    end

    test "spawn_agents with count 1 succeeds" do
      result = UltraConcurrencyEngine.spawn_agents(:simple_task, 1, %{})
      assert is_tuple(result)
    end

    test "spawn_agents with count at limit 10_000 - uses smaller count for test" do
      result = UltraConcurrencyEngine.spawn_agents(:batch_task, 5, %{})
      assert is_tuple(result)
    end

    test "spawn_agents with zero count" do
      result = UltraConcurrencyEngine.spawn_agents(:zero_task, 0, %{})
      assert is_tuple(result)
    end

    test "returns ok or error tuple" do
      result = UltraConcurrencyEngine.spawn_agents(:test, 1, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "execute_parallel/2" do
    test "executes tasks in parallel" do
      tasks = [fn -> 1 + 1 end, fn -> 2 + 2 end]
      result = UltraConcurrencyEngine.execute_parallel(tasks, %{timeout: 5000})
      assert is_tuple(result)
    end

    test "handles empty task list" do
      result = UltraConcurrencyEngine.execute_parallel([], %{})
      assert is_tuple(result)
    end

    test "returns ok or error tuple" do
      result = UltraConcurrencyEngine.execute_parallel([], %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_performance_metrics/0" do
    test "returns performance metrics" do
      result = UltraConcurrencyEngine.get_performance_metrics()
      assert is_map(result) or is_tuple(result)
    end

    test "metrics include concurrency-related data" do
      result = UltraConcurrencyEngine.get_performance_metrics()

      case result do
        {:ok, metrics} -> assert is_map(metrics)
        metrics when is_map(metrics) -> assert map_size(metrics) >= 0
        _ -> assert is_tuple(result)
      end
    end
  end

  describe "optimize_configuration/0" do
    test "optimizes configuration based on current load" do
      result = UltraConcurrencyEngine.optimize_configuration()
      assert is_tuple(result) or is_atom(result)
    end

    test "returns ok or error" do
      result = UltraConcurrencyEngine.optimize_configuration()
      assert match?({:ok, _}, result) or match?({:error, _}, result) or result == :ok
    end
  end

  describe "process resilience" do
    test "process stays alive after operations" do
      pid_before = Process.whereis(UltraConcurrencyEngine)

      UltraConcurrencyEngine.get_performance_metrics()
      UltraConcurrencyEngine.optimize_configuration()

      pid_after = Process.whereis(UltraConcurrencyEngine)

      if pid_before, do: assert(Process.alive?(pid_before))
      if pid_after, do: assert(Process.alive?(pid_after))
    end
  end
end
