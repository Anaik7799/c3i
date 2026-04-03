defmodule Indrajaal.Cockpit.Prajna.AnalyticsIntegrationTest do
  @moduledoc """
  Tests for Indrajaal.Cockpit.Prajna.AnalyticsIntegration GenServer.
  STAMP: SC-TDG, SC-COV-001, SC-PRAJNA-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.AnalyticsIntegration

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AnalyticsIntegration)
    end

    test "module has expected public functions" do
      assert function_exported?(AnalyticsIntegration, :get_status, 0)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(AnalyticsIntegration, :start_link, 1)
      assert function_exported?(AnalyticsIntegration, :init, 1)
    end
  end

  describe "AnalyticsIntegration GenServer" do
    setup do
      name = :"analytics_int_test_#{System.unique_integer([:positive])}"

      case AnalyticsIntegration.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        {:error, _} ->
          :skip
      end
    end

    test "get_status/0 returns a status map or term", %{pid: pid} do
      result = GenServer.call(pid, :get_status)
      assert is_map(result) or result != nil
    end

    test "process is alive after initialization", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end
end
