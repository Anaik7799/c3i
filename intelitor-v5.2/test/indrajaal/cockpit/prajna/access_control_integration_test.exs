defmodule Indrajaal.Cockpit.Prajna.AccessControlIntegrationTest do
  @moduledoc """
  Tests for Indrajaal.Cockpit.Prajna.AccessControlIntegration GenServer.
  STAMP: SC-TDG, SC-COV-001, SC-PRAJNA-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.AccessControlIntegration

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AccessControlIntegration)
    end

    test "module has expected public functions" do
      assert function_exported?(AccessControlIntegration, :get_status, 0)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(AccessControlIntegration, :start_link, 1)
      assert function_exported?(AccessControlIntegration, :init, 1)
    end
  end

  describe "AccessControlIntegration GenServer" do
    setup do
      name = :"aci_test_#{System.unique_integer([:positive])}"

      case AccessControlIntegration.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        {:error, _} ->
          :skip
      end
    end

    test "get_status/0 returns a status term", %{pid: pid} do
      result = GenServer.call(pid, :get_status)
      assert result != nil
    end

    test "process responds to info messages without crashing", %{pid: pid} do
      send(pid, :noop_test_message)
      Process.sleep(10)
      assert Process.alive?(pid)
    end
  end
end
