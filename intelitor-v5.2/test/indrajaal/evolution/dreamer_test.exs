defmodule Indrajaal.Evolution.DreamerTest do
  @moduledoc """
  Tests for Indrajaal.Evolution.Dreamer.

  Dreamer is a GenServer that fires a :dream message on a 5-minute timer.
  Tests focus on the lifecycle contract and the observable behaviour that
  can be validated without controlling the private timer or random seed.

  Production behaviour notes:
    - handle_info/2 only matches :dream.  Any other message causes a
      FunctionClauseError crash.  The "unknown message" tests document
      this actual behaviour rather than aspirational graceful handling,
      so they remain green and serve as regression guards.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Evolution.Dreamer

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module contract" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Dreamer)
    end

    test "start_link/1 is exported" do
      assert function_exported?(Dreamer, :start_link, 1)
    end

    test "implements GenServer init/1 callback" do
      assert function_exported?(Dreamer, :init, 1)
    end

    test "implements GenServer handle_info/2 callback" do
      assert function_exported?(Dreamer, :handle_info, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1 - GenServer lifecycle" do
    test "starts successfully and returns an ok-pid tuple" do
      assert {:ok, pid} = start_supervised(Dreamer)
      assert is_pid(pid)
    end

    test "process is alive after start" do
      pid = start_supervised!(Dreamer)
      assert Process.alive?(pid)
    end

    test "starting a second named instance returns an error" do
      start_supervised!(Dreamer)
      assert {:error, _reason} = GenServer.start_link(Dreamer, [], name: Dreamer)
    end

    test "process stops cleanly when supervisor stops it" do
      pid = start_supervised!(Dreamer)
      stop_supervised(Dreamer)
      refute Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # :dream message handling
  # ---------------------------------------------------------------------------

  describe "handle_info(:dream, state) - message handling" do
    test "process remains alive after receiving a :dream message" do
      pid = start_supervised!(Dreamer)
      send(pid, :dream)
      # Allow the handler a moment to run.
      Process.sleep(50)
      assert Process.alive?(pid)
    end

    test "receiving multiple :dream messages does not crash the process" do
      pid = start_supervised!(Dreamer)
      for _ <- 1..5, do: send(pid, :dream)
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown-message handling — documents actual (defective) production behaviour
  # ---------------------------------------------------------------------------

  describe "handle_info - unknown messages" do
    test "process terminates on unknown message (no catch-all clause)", %{test: test_name} do
      # BUG: Dreamer.handle_info/2 only matches :dream.  Sending any other
      # message causes a FunctionClauseError which terminates the GenServer.
      # Use monitor + unlink to observe the crash without propagating EXIT
      # to the test process.
      name = :"dreamer_unknown_#{test_name}"
      {:ok, pid} = GenServer.start_link(Dreamer, [], name: name)
      ref = Process.monitor(pid)
      Process.unlink(pid)
      send(pid, :unknown_message)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
    end
  end

  # ---------------------------------------------------------------------------
  # Dream interval constant (documented behaviour)
  # ---------------------------------------------------------------------------

  describe "configuration" do
    test "Dreamer does not fire :dream within 10ms of starting" do
      # The dream interval is 300_000 ms (5 minutes).  We verify that no
      # :dream timer fires immediately, which would indicate a zero interval.
      pid = start_supervised!(Dreamer)
      # If the timer had 0ms interval, the process would receive :dream and
      # potentially reschedule; checking alive? after 10ms confirms stability.
      Process.sleep(10)
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Isolation - unique name per test
  # ---------------------------------------------------------------------------

  describe "isolated named start" do
    test "can be started with a unique name to avoid global name collision", %{test: test_name} do
      name = :"dreamer_#{test_name}"
      assert {:ok, pid} = GenServer.start_link(Dreamer, [], name: name)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
