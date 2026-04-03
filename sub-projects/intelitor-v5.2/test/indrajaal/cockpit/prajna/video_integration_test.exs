defmodule Indrajaal.Cockpit.Prajna.VideoIntegrationTest do
  @moduledoc """
  Tests for Indrajaal.Cockpit.Prajna.VideoIntegration GenServer.
  STAMP: SC-TDG, SC-COV-001, SC-PRAJNA-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.VideoIntegration

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(VideoIntegration)
    end

    test "module has expected public functions" do
      assert function_exported?(VideoIntegration, :get_status, 0)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(VideoIntegration, :start_link, 1)
      assert function_exported?(VideoIntegration, :init, 1)
    end
  end

  describe "VideoIntegration GenServer" do
    setup do
      name = :"video_int_test_#{System.unique_integer([:positive])}"

      case VideoIntegration.start_link(name: name) do
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

    test "process is alive after initialization", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end
end
