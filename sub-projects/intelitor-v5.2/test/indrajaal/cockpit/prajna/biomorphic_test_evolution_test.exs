defmodule Indrajaal.Cockpit.Prajna.BiomorphicTestEvolutionTest do
  @moduledoc """
  TDG test suite for Cockpit.Prajna.BiomorphicTestEvolution.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - OODA: 30s cycle interval validated

  ## STAMP Safety Integration
  - SC-TEST-EVO-001: OODA cycle < 30s
  - SC-TEST-EVO-002: Coverage tracking mandatory (fitness score)
  - SC-TEST-EVO-006: Fitness score > 0.7 required

  ## Constitutional Verification
  - Ψ₀ Existence: get_status/0 and get_fitness/0 safe to call without server
  - Ψ₁ Regeneration: Evolution state tracked via generation counter

  ## TPS 5-Level RCA Context
  - L1 Symptom: generate_tests returns {:error, :not_started} when server not running
  - L5 Root Cause: Guard in generate_tests checks GenServer.whereis before calling
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.Prajna.BiomorphicTestEvolution

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(BiomorphicTestEvolution) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(50)
    :ok
  end

  # ============================================================================
  # Functions safe to call without a running server
  # ============================================================================

  describe "get_fitness/0 without server" do
    test "returns a map (initial_fitness) when server is not started" do
      result = BiomorphicTestEvolution.get_fitness()
      assert is_map(result)
    end

    test "fitness map has :coverage_score key" do
      fitness = BiomorphicTestEvolution.get_fitness()
      assert Map.has_key?(fitness, :coverage_score)
    end

    test "fitness map has :pass_rate key" do
      fitness = BiomorphicTestEvolution.get_fitness()
      assert Map.has_key?(fitness, :pass_rate)
    end

    test "fitness map has :mutation_score key" do
      fitness = BiomorphicTestEvolution.get_fitness()
      assert Map.has_key?(fitness, :mutation_score)
    end

    test "fitness map has :diversity key" do
      fitness = BiomorphicTestEvolution.get_fitness()
      assert Map.has_key?(fitness, :diversity)
    end

    test "fitness map has :overall key" do
      fitness = BiomorphicTestEvolution.get_fitness()
      assert Map.has_key?(fitness, :overall)
    end

    test "all fitness scores are numeric" do
      fitness = BiomorphicTestEvolution.get_fitness()

      assert is_float(fitness.coverage_score) or is_integer(fitness.coverage_score)
      assert is_float(fitness.pass_rate) or is_integer(fitness.pass_rate)
      assert is_float(fitness.mutation_score) or is_integer(fitness.mutation_score)
      assert is_float(fitness.diversity) or is_integer(fitness.diversity)
      assert is_float(fitness.overall) or is_integer(fitness.overall)
    end
  end

  describe "get_status/0 without server" do
    test "returns {:status: :not_started} when server not running" do
      result = BiomorphicTestEvolution.get_status()
      assert %{status: :not_started} = result
    end

    test "returns a map" do
      result = BiomorphicTestEvolution.get_status()
      assert is_map(result)
    end
  end

  describe "get_state/0 without server" do
    test "returns same result as get_status/0" do
      status = BiomorphicTestEvolution.get_status()
      state = BiomorphicTestEvolution.get_state()
      assert status == state
    end

    test "returns {:status: :not_started} when server not running" do
      result = BiomorphicTestEvolution.get_state()
      assert %{status: :not_started} = result
    end
  end

  describe "generate_tests/2 without server" do
    test "returns {:error, :not_started} when server not running" do
      result = BiomorphicTestEvolution.generate_tests("lib/some_module.ex")
      assert {:error, :not_started} = result
    end

    test "returns error for any path when server not running" do
      result = BiomorphicTestEvolution.generate_tests("lib/indrajaal/alarms/alarm.ex", level: 1)
      assert {:error, :not_started} = result
    end
  end

  describe "evolve/0 without server" do
    test "returns {:error, :not_started} when server not running" do
      result = BiomorphicTestEvolution.evolve()
      assert {:error, :not_started} = result
    end
  end

  describe "generate_all_levels/2 without server" do
    test "returns {:error, :not_started} when server not running" do
      result = BiomorphicTestEvolution.generate_all_levels("lib/some_module.ex")
      assert {:error, :not_started} = result
    end
  end

  describe "watch_module/1 without server" do
    test "returns :ok even when server not running (cast is fire-and-forget)" do
      result = BiomorphicTestEvolution.watch_module("lib/some_module.ex")
      assert result == :ok
    end
  end

  describe "stop/0 without server" do
    test "returns :ok when server is not running" do
      result = BiomorphicTestEvolution.stop()
      assert result == :ok
    end
  end

  # ============================================================================
  # GenServer lifecycle
  # ============================================================================

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      assert {:ok, pid} = BiomorphicTestEvolution.start_link([])
      assert Process.alive?(pid)
      on_exit(fn -> BiomorphicTestEvolution.stop() end)
    end

    test "registers under module name" do
      {:ok, pid} = BiomorphicTestEvolution.start_link([])
      assert Process.whereis(BiomorphicTestEvolution) == pid
      on_exit(fn -> BiomorphicTestEvolution.stop() end)
    end

    test "second start_link returns already_started error" do
      {:ok, pid} = BiomorphicTestEvolution.start_link([])

      assert {:error, {:already_started, ^pid}} = BiomorphicTestEvolution.start_link([])

      on_exit(fn -> BiomorphicTestEvolution.stop() end)
    end
  end

  # ============================================================================
  # Functions when server is running
  # ============================================================================

  describe "get_fitness/0 with server" do
    setup do
      {:ok, _pid} = BiomorphicTestEvolution.start_link([])
      on_exit(fn -> BiomorphicTestEvolution.stop() end)
      :ok
    end

    test "returns a map with fitness components" do
      fitness = BiomorphicTestEvolution.get_fitness()
      assert is_map(fitness)
      assert Map.has_key?(fitness, :overall)
    end

    test "fitness overall is a float between 0 and 1" do
      fitness = BiomorphicTestEvolution.get_fitness()
      assert is_float(fitness.overall) or is_integer(fitness.overall)
      overall = fitness.overall * 1.0
      assert overall >= 0.0
      assert overall <= 1.0
    end
  end

  describe "get_status/0 with server" do
    setup do
      {:ok, _pid} = BiomorphicTestEvolution.start_link([])
      on_exit(fn -> BiomorphicTestEvolution.stop() end)
      :ok
    end

    test "returns a map" do
      result = BiomorphicTestEvolution.get_status()
      assert is_map(result)
    end

    test "status is :running when server is alive" do
      result = BiomorphicTestEvolution.get_status()
      assert result.status == :running
    end

    test "status has :generation key" do
      result = BiomorphicTestEvolution.get_status()
      assert Map.has_key?(result, :generation)
    end

    test "initial generation is 0" do
      result = BiomorphicTestEvolution.get_status()
      assert result.generation == 0
    end

    test "status has :fitness key" do
      result = BiomorphicTestEvolution.get_status()
      assert Map.has_key?(result, :fitness)
    end

    test "status has :ooda_state key" do
      result = BiomorphicTestEvolution.get_status()
      assert Map.has_key?(result, :ooda_state)
    end

    test "status has :modules_watched as list" do
      result = BiomorphicTestEvolution.get_status()
      assert Map.has_key?(result, :modules_watched)
      assert is_list(result.modules_watched)
    end

    test "initial modules_watched is empty" do
      result = BiomorphicTestEvolution.get_status()
      assert result.modules_watched == []
    end

    test "status has :pending_mutations count" do
      result = BiomorphicTestEvolution.get_status()
      assert Map.has_key?(result, :pending_mutations)
      assert is_integer(result.pending_mutations)
    end

    test "status has :last_cycle as DateTime" do
      result = BiomorphicTestEvolution.get_status()
      assert Map.has_key?(result, :last_cycle)
      assert %DateTime{} = result.last_cycle
    end

    test "status has :evolution_history_size" do
      result = BiomorphicTestEvolution.get_status()
      assert Map.has_key?(result, :evolution_history_size)
      assert is_integer(result.evolution_history_size)
    end
  end

  describe "watch_module/1 with server" do
    setup do
      {:ok, _pid} = BiomorphicTestEvolution.start_link([])
      on_exit(fn -> BiomorphicTestEvolution.stop() end)
      :ok
    end

    test "returns :ok" do
      result = BiomorphicTestEvolution.watch_module("lib/some_module.ex")
      assert result == :ok
    end

    test "watched module appears in status after watch" do
      BiomorphicTestEvolution.watch_module("lib/some_module.ex")
      # Give the cast time to be processed
      Process.sleep(20)
      status = BiomorphicTestEvolution.get_status()
      assert "lib/some_module.ex" in status.modules_watched
    end

    test "multiple modules can be watched" do
      BiomorphicTestEvolution.watch_module("lib/module_a.ex")
      BiomorphicTestEvolution.watch_module("lib/module_b.ex")
      Process.sleep(20)
      status = BiomorphicTestEvolution.get_status()
      assert "lib/module_a.ex" in status.modules_watched
      assert "lib/module_b.ex" in status.modules_watched
    end
  end

  describe "evolve/0 with server" do
    setup do
      {:ok, _pid} = BiomorphicTestEvolution.start_link([])
      on_exit(fn -> BiomorphicTestEvolution.stop() end)
      :ok
    end

    test "returns {:ok, map} tuple" do
      result = BiomorphicTestEvolution.evolve()
      assert {:ok, map} = result
      assert is_map(map)
    end

    test "evolve result has :generation key" do
      {:ok, result} = BiomorphicTestEvolution.evolve()
      assert Map.has_key?(result, :generation)
    end

    test "evolve increments generation" do
      status_before = BiomorphicTestEvolution.get_status()
      BiomorphicTestEvolution.evolve()
      status_after = BiomorphicTestEvolution.get_status()
      assert status_after.generation > status_before.generation
    end
  end

  describe "stop/0 with server" do
    test "stops the running server" do
      {:ok, pid} = BiomorphicTestEvolution.start_link([])
      assert Process.alive?(pid)

      assert :ok = BiomorphicTestEvolution.stop()

      Process.sleep(50)
      refute Process.alive?(pid)
    end

    test "stop is idempotent when server is not running" do
      {:ok, pid} = BiomorphicTestEvolution.start_link([])
      BiomorphicTestEvolution.stop()
      Process.sleep(50)

      # Calling stop again should return :ok
      assert :ok = BiomorphicTestEvolution.stop()
      refute Process.alive?(pid)
    end
  end
end
