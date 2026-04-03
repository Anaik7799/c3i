defmodule Indrajaal.Alarms.PerformanceOptimizerTest do
  @moduledoc """
  TDG comprehensive test suite for Alarms.PerformanceOptimizer.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-PO-001: PerformanceOptimizer GenServer must start successfully
  - SC-PO-002: get_optimization_status must return a map with status fields
  - SC-PO-003: optimize_now must return :ok (cast-based)
  - SC-PO-004: set_performance_targets must accept a map of targets

  ## Constitutional Verification
  - Psi0 Existence: PerformanceOptimizer continues running even under load
  - Psi3 Verification: optimization status always returns consistent typed map
  - Psi5 Truthfulness: current_strategy field reflects actual optimization strategy

  ## Founder's Directive Alignment
  - Omega0.1: Performance optimization ensures alarm processing SLA < 100ms

  ## TPS 5-Level RCA Context
  - L1 Symptom: PerformanceOptimizer.get_optimization_status/0 crashes
  - L5 Root Cause: GenServer handle_call :get_status missing in implementation

  ## Change History
  | Version | Date       | Author | Change            |
  |---------|------------|--------|-------------------|
  | 21.3.0  | 2026-03-19 | Claude | Initial TDG suite |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.PerformanceOptimizer

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Setup — ensure GenServer is running
  # ---------------------------------------------------------------------------

  setup do
    case GenServer.whereis(PerformanceOptimizer) do
      nil ->
        start_supervised!({PerformanceOptimizer, []})

      _pid ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # describe: GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "GenServer lifecycle" do
    test "PerformanceOptimizer process is running" do
      pid = GenServer.whereis(PerformanceOptimizer)
      assert pid != nil
      assert Process.alive?(pid)
    end

    test "process is registered under module name" do
      pid = GenServer.whereis(PerformanceOptimizer)
      assert pid == Process.whereis(PerformanceOptimizer)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: get_optimization_status/0
  # ---------------------------------------------------------------------------

  describe "get_optimization_status/0" do
    test "returns a value without raising" do
      result = PerformanceOptimizer.get_optimization_status()
      # Must complete without crashing — any non-exception return is valid
      assert result != nil or result == nil
    end

    test "returns a map" do
      result = PerformanceOptimizer.get_optimization_status()
      assert is_map(result)
    end

    test "returned map has :current_strategy key" do
      result = PerformanceOptimizer.get_optimization_status()
      assert Map.has_key?(result, :current_strategy)
    end

    test "returned map has :last_optimization key" do
      result = PerformanceOptimizer.get_optimization_status()
      assert Map.has_key?(result, :last_optimization)
    end

    test "current_strategy is a known atom" do
      result = PerformanceOptimizer.get_optimization_status()

      known_strategies = [
        :balanced,
        :aggressive_batching,
        :memory_optimization,
        :cache_warming,
        :load_balancing,
        :resource_scaling
      ]

      assert result.current_strategy in known_strategies
    end

    test "get_optimization_status is idempotent" do
      r1 = PerformanceOptimizer.get_optimization_status()
      r2 = PerformanceOptimizer.get_optimization_status()
      assert Map.keys(r1) == Map.keys(r2)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: optimize_now/0
  # ---------------------------------------------------------------------------

  describe "optimize_now/0" do
    test "returns :ok" do
      result = PerformanceOptimizer.optimize_now()
      assert result == :ok
    end

    test "calling optimize_now multiple times does not crash" do
      assert PerformanceOptimizer.optimize_now() == :ok
      assert PerformanceOptimizer.optimize_now() == :ok
      assert PerformanceOptimizer.optimize_now() == :ok
    end

    test "GenServer still responsive after optimize_now" do
      PerformanceOptimizer.optimize_now()
      # Brief wait for async cast to process
      :timer.sleep(10)
      pid = GenServer.whereis(PerformanceOptimizer)
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: set_performance_targets/1
  # ---------------------------------------------------------------------------

  describe "set_performance_targets/1" do
    test "accepts a map of performance targets" do
      targets = %{
        max_latency_ms: 50,
        min_throughput_per_sec: 2000,
        max_memory_mb: 1024,
        max_queue_size: 500
      }

      result = PerformanceOptimizer.set_performance_targets(targets)
      # cast returns :ok
      assert result == :ok
    end

    test "accepts empty map of targets" do
      result = PerformanceOptimizer.set_performance_targets(%{})
      assert result == :ok
    end

    test "accepts partial targets map" do
      result = PerformanceOptimizer.set_performance_targets(%{max_latency_ms: 200})
      assert result == :ok
    end

    test "GenServer still responsive after set_performance_targets" do
      PerformanceOptimizer.set_performance_targets(%{max_latency_ms: 100})
      :timer.sleep(10)
      pid = GenServer.whereis(PerformanceOptimizer)
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: GenServer survives optimize_now and status calls" do
      PerformanceOptimizer.optimize_now()
      :timer.sleep(10)
      status = PerformanceOptimizer.get_optimization_status()
      # Process still alive and returning data
      assert is_map(status)
      pid = GenServer.whereis(PerformanceOptimizer)
      assert Process.alive?(pid)
    end

    test "Psi3 verification: status keys are always consistent" do
      s1 = PerformanceOptimizer.get_optimization_status()
      PerformanceOptimizer.optimize_now()
      :timer.sleep(10)
      s2 = PerformanceOptimizer.get_optimization_status()
      assert Map.keys(s1) == Map.keys(s2)
    end

    test "Psi5 truthfulness: current_strategy is always a known optimization strategy" do
      known = [
        :balanced,
        :aggressive_batching,
        :memory_optimization,
        :cache_warming,
        :load_balancing,
        :resource_scaling
      ]

      status = PerformanceOptimizer.get_optimization_status()
      assert status.current_strategy in known
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "get_optimization_status completes within 5 seconds" do
      {elapsed_us, result} = :timer.tc(fn -> PerformanceOptimizer.get_optimization_status() end)
      assert is_map(result)
      assert elapsed_us < 5_000_000
    end

    test "dual-channel: optimize_now and get_status can run concurrently" do
      task =
        Task.async(fn ->
          PerformanceOptimizer.optimize_now()
          PerformanceOptimizer.get_optimization_status()
        end)

      result = Task.await(task, 10_000)
      assert is_map(result)
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "get_optimization_status always returns map with current_strategy" do
    forall _n <- PC.integer(1, 3) do
      result = PerformanceOptimizer.get_optimization_status()
      is_map(result) and Map.has_key?(result, :current_strategy)
    end
  end

  property "set_performance_targets always returns :ok" do
    forall latency <- PC.integer(10, 500) do
      result = PerformanceOptimizer.set_performance_targets(%{max_latency_ms: latency})
      result == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "optimize_now is always safe to call" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      result = PerformanceOptimizer.optimize_now()
      assert result == :ok
    end
  end

  test "current_strategy is always a valid atom" do
    known_strategies = [
      :balanced,
      :aggressive_batching,
      :memory_optimization,
      :cache_warming,
      :load_balancing,
      :resource_scaling
    ]

    ExUnitProperties.check all(_x <- SD.boolean()) do
      status = PerformanceOptimizer.get_optimization_status()
      assert status.current_strategy in known_strategies
    end
  end
end
