defmodule Indrajaal.Evolution.SystemEvolutionTest do
  @moduledoc """
  Tests for Indrajaal.Evolution.SystemEvolution.

  SystemEvolution is a GenServer that periodically queries KMS for the next
  pending task and broadcasts it via telemetry.

  IMPORTANT — Global name registration:
    start_link/1 always registers under `name: __MODULE__` regardless of
    any opts passed.  This means only one instance may run at a time, so
    the suite uses async: false and a fresh_se/0 helper that clears any
    residual process before each test that needs a live instance.

  Known production defects (not tested here to avoid test-process crashes):
    1. handle_info(:evolve, state) returns a bare reference (from
       schedule_check/0) instead of {:noreply, state}, terminating the
       GenServer on every :evolve message.
    2. handle_info/2 has no catch-all clause, so unknown messages cause a
       FunctionClauseError crash.
    These defects are documented in this moduledoc as a record for future
    fix validation.  Tests for crashing GenServers require monitor-based
    isolation to avoid propagating EXIT signals to the test process.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Evolution.SystemEvolution

  # ---------------------------------------------------------------------------
  # Helper — start a fresh SystemEvolution, stopping any leftover instance.
  # ---------------------------------------------------------------------------

  defp fresh_se do
    case GenServer.whereis(SystemEvolution) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1_000)
    end

    {:ok, pid} = SystemEvolution.start_link([])
    pid
  end

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module contract" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SystemEvolution)
    end

    test "start_link/1 is exported" do
      assert function_exported?(SystemEvolution, :start_link, 1)
    end

    test "propose_mutation/1 is exported" do
      assert function_exported?(SystemEvolution, :propose_mutation, 1)
    end

    test "init/1 callback is exported" do
      assert function_exported?(SystemEvolution, :init, 1)
    end

    test "handle_info/2 callback is exported" do
      assert function_exported?(SystemEvolution, :handle_info, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1 - GenServer lifecycle" do
    test "returns a pid and the process is alive" do
      pid = fresh_se()
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "process stops cleanly on GenServer.stop/1" do
      pid = fresh_se()
      :ok = GenServer.stop(pid, :normal)
      refute Process.alive?(pid)
    end

    test "only one instance may run at a time (hardcoded __MODULE__ name)" do
      pid = fresh_se()
      assert {:error, {:already_started, ^pid}} = SystemEvolution.start_link([])
      GenServer.stop(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # propose_mutation/1 — pure Logger call, no GenServer dependency
  # ---------------------------------------------------------------------------

  describe "propose_mutation/1" do
    test "returns :ok for a binary mutation description" do
      # propose_mutation/1 only calls Logger.info then returns :ok directly.
      # No GenServer interaction — works whether or not the process is alive.
      assert :ok = SystemEvolution.propose_mutation("Optimize Cortex Layer")
    end

    test "returns :ok for a map mutation description" do
      assert :ok = SystemEvolution.propose_mutation(%{type: :code_change, module: "Cortex"})
    end

    test "returns :ok for an atom mutation description" do
      assert :ok = SystemEvolution.propose_mutation(:evolve_synapse)
    end

    test "returns :ok for an integer mutation description" do
      assert :ok = SystemEvolution.propose_mutation(42)
    end

    test "is idempotent — calling twice returns :ok both times" do
      assert :ok = SystemEvolution.propose_mutation("Mutation A")
      assert :ok = SystemEvolution.propose_mutation("Mutation A")
    end

    test "works with an empty string" do
      assert :ok = SystemEvolution.propose_mutation("")
    end
  end

  # ---------------------------------------------------------------------------
  # :evolve message — monitored crash detection (no link to test process)
  # ---------------------------------------------------------------------------

  describe "handle_info(:evolve, state) - timer message" do
    test "process terminates after receiving :evolve (known production bug)" do
      # Use GenServer.start/3 (no link) + monitor to observe the crash without
      # propagating the EXIT signal to the test process.
      # The bug: handle_info(:evolve, state) returns a bare reference from
      # schedule_check/0 instead of {:noreply, state}.
      pid = fresh_se()
      ref = Process.monitor(pid)
      # Unlink so the crash EXIT does not propagate to this test process.
      Process.unlink(pid)
      send(pid, :evolve)

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown-message handling — monitored crash detection
  # ---------------------------------------------------------------------------

  describe "handle_info - unknown messages" do
    test "process terminates on unexpected message (no catch-all clause)" do
      # Use monitor + unlink to observe the crash without propagating EXIT.
      pid = fresh_se()
      ref = Process.monitor(pid)
      Process.unlink(pid)
      send(pid, :unexpected_message)

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
    end
  end
end
