defmodule Indrajaal.Metabolism.ResourceWatchdogTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Metabolism.ResourceWatchdog

  describe "start_link/1" do
    test "starts the GenServer and returns {:ok, pid}" do
      result = start_supervised({ResourceWatchdog, []})
      assert {:ok, pid} = result
      assert is_pid(pid)
    end

    test "started process is alive" do
      {:ok, pid} = start_supervised({ResourceWatchdog, []})
      assert Process.alive?(pid)
    end

    test "can be started with an empty options list" do
      assert {:ok, _pid} = start_supervised({ResourceWatchdog, []})
    end

    test "does not register under a named process by default" do
      {:ok, _pid} = start_supervised({ResourceWatchdog, []})
      # ResourceWatchdog does not register itself globally; no name conflict expected
      assert Process.whereis(ResourceWatchdog) == nil
    end

    test "two separate watchdogs can be started independently" do
      {:ok, pid1} = start_supervised({ResourceWatchdog, []}, id: :wdog1)
      {:ok, pid2} = start_supervised({ResourceWatchdog, []}, id: :wdog2)
      assert pid1 != pid2
      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
    end
  end
end
