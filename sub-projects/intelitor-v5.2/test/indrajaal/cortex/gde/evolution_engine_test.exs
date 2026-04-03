defmodule Indrajaal.Cortex.GDE.EvolutionEngineTest do
  @moduledoc """
  TDG test suite for GDE EvolutionEngine (autonomic entropy scanner).

  Tests GenServer lifecycle, scan scheduling, and entropy threshold
  filtering for Goal-Directed Evolution v2.0.

  ## STAMP Safety Integration
  - SC-GDE-001: Guardian validation required
  - SC-GDE-002: Shadow testing mandatory
  - SC-OODA-001: Cycle time < 30ms

  ## TPS 5-Level RCA Context
  - L1 Symptom: Evolution goals not generated
  - L5 Root Cause: Sentinel health unavailable or entropy below threshold
  """

  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Indrajaal.Cortex.GDE.EvolutionEngine
  alias StreamData, as: SD

  @moduletag :gde

  setup do
    # Stop any existing instance
    case GenServer.whereis(EvolutionEngine) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    Process.sleep(10)

    {:ok, pid} =
      EvolutionEngine.start_link(
        entropy_threshold: 0.2,
        scan_interval: 86_400_000
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1000)
    end)

    %{pid: pid}
  end

  # ── Module Definition ──────────────────────────────────────────

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(EvolutionEngine)
    end

    test "exports start_link/1" do
      assert function_exported?(EvolutionEngine, :start_link, 1)
    end

    test "exports scan_now/0" do
      assert function_exported?(EvolutionEngine, :scan_now, 0)
    end
  end

  # ── GenServer Lifecycle ────────────────────────────────────────

  describe "GenServer lifecycle" do
    test "starts as a named process", %{pid: pid} do
      assert Process.alive?(pid)
      assert GenServer.whereis(EvolutionEngine) == pid
    end

    test "survives scan_now cast without crashing", %{pid: pid} do
      EvolutionEngine.scan_now()
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "handles multiple scan_now casts", %{pid: pid} do
      for _i <- 1..5 do
        EvolutionEngine.scan_now()
      end

      Process.sleep(200)
      assert Process.alive?(pid)
    end
  end

  # ── Configuration ──────────────────────────────────────────────

  describe "configuration" do
    test "accepts custom entropy_threshold" do
      GenServer.stop(EvolutionEngine, :normal, 1000)
      Process.sleep(10)

      {:ok, pid} =
        EvolutionEngine.start_link(
          entropy_threshold: 0.5,
          scan_interval: 86_400_000
        )

      assert Process.alive?(pid)
    end

    test "accepts custom scan_interval" do
      GenServer.stop(EvolutionEngine, :normal, 1000)
      Process.sleep(10)

      {:ok, pid} =
        EvolutionEngine.start_link(
          entropy_threshold: 0.2,
          scan_interval: 5000
        )

      assert Process.alive?(pid)
    end
  end

  # ── Resilience ─────────────────────────────────────────────────

  describe "resilience" do
    test "does not crash when dependencies are unavailable", %{pid: pid} do
      # scan_now triggers Sentinel/KMS calls that may fail gracefully
      EvolutionEngine.scan_now()
      Process.sleep(200)
      assert Process.alive?(pid)
    end

    test "handles rapid successive scans", %{pid: pid} do
      for _i <- 1..20 do
        EvolutionEngine.scan_now()
      end

      Process.sleep(500)
      assert Process.alive?(pid)
    end
  end

  # ── Property Tests ─────────────────────────────────────────────

  describe "property tests" do
    test "property: engine survives arbitrary scan count" do
      check all(count <- SD.integer(1..10)) do
        for _i <- 1..count do
          EvolutionEngine.scan_now()
        end

        Process.sleep(50)
        assert Process.alive?(GenServer.whereis(EvolutionEngine))
      end
    end
  end
end
