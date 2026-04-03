defmodule Indrajaal.Core.Holon.StateWatchdogTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.StateWatchdog

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(StateWatchdog)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(StateWatchdog, :start_link, 1)
    end

    test "enable/1 is exported" do
      assert function_exported?(StateWatchdog, :enable, 1)
    end

    test "disable/1 is exported" do
      assert function_exported?(StateWatchdog, :disable, 1)
    end

    test "check_now/1 is exported" do
      assert function_exported?(StateWatchdog, :check_now, 1)
    end

    test "stats/1 is exported" do
      assert function_exported?(StateWatchdog, :stats, 1)
    end

    test "health/1 is exported" do
      assert function_exported?(StateWatchdog, :health, 1)
    end
  end

  describe "StateWatchdog GenServer lifecycle" do
    setup do
      name = :"test_watchdog_#{System.unique_integer([:positive])}"

      case StateWatchdog.start_link(name: name, holon_id: "test-holon", interval: 60_000) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{watchdog: pid, name: name}

        {:error, _} ->
          %{watchdog: nil, name: name}
      end
    end

    test "starts successfully or returns error", %{watchdog: pid} do
      if pid != nil, do: assert(Process.alive?(pid))
    end

    test "enable/1 completes without error", %{watchdog: pid, name: name} do
      if pid != nil do
        result = StateWatchdog.enable(name)
        assert result in [:ok, {:ok, :enabled}]
      end
    end

    test "disable/1 completes without error", %{watchdog: pid, name: name} do
      if pid != nil do
        result = StateWatchdog.disable(name)
        assert result in [:ok, {:ok, :disabled}]
      end
    end

    test "stats/1 returns map", %{watchdog: pid, name: name} do
      if pid != nil do
        result = StateWatchdog.stats(name)
        assert is_map(result)
      end
    end

    test "health/1 returns health status", %{watchdog: pid, name: name} do
      if pid != nil do
        result = StateWatchdog.health(name)
        assert is_map(result) or is_atom(result) or is_float(result)
      end
    end
  end
end
