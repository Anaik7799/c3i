defmodule Indrajaal.Metabolism.EnergyGovernorTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Metabolism.EnergyGovernor

  # EnergyGovernor registers itself under its own module name so we cannot
  # use start_supervised with multiple instances. We use start_link + on_exit.

  setup do
    case Process.whereis(EnergyGovernor) do
      nil -> :ok
      pid -> Process.exit(pid, :kill)
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the GenServer and returns {:ok, pid}" do
      assert {:ok, pid} = EnergyGovernor.start_link()
      assert is_pid(pid)
      Process.exit(pid, :normal)
    end

    test "registers process under the module name" do
      {:ok, pid} = EnergyGovernor.start_link()
      assert Process.whereis(EnergyGovernor) == pid
      Process.exit(pid, :normal)
      # Allow time for deregistration
      Process.sleep(10)
    end

    test "started process is alive" do
      {:ok, pid} = EnergyGovernor.start_link()
      assert Process.alive?(pid)
      Process.exit(pid, :normal)
    end

    test "accepts an options list" do
      assert {:ok, pid} = EnergyGovernor.start_link([])
      assert Process.alive?(pid)
      Process.exit(pid, :normal)
    end

    test "second start_link fails because name is already taken" do
      {:ok, pid1} = EnergyGovernor.start_link()

      assert {:error, {:already_started, ^pid1}} = EnergyGovernor.start_link()

      Process.exit(pid1, :normal)
    end
  end
end
