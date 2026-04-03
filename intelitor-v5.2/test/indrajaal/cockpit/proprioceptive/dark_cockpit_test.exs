defmodule Indrajaal.Cockpit.Proprioceptive.DarkCockpitTest do
  @moduledoc """
  TDG tests for Indrajaal.Cockpit.Proprioceptive.DarkCockpit.

  ## STAMP Safety Integration
  - NASA-STD-3000: Dark Cockpit HMI compliance
  - SC-PRAJNA-004: Cockpit state visibility

  ## TPS 5-Level RCA Context
  - L1 Symptom: HMI alerts not rendering correctly
  - L5 Root Cause: Dark cockpit level state machine corrupted
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Proprioceptive.DarkCockpit

  defp start_cockpit(test) do
    name = :"dark_cockpit_#{test}_#{System.unique_integer()}"
    start_supervised!({DarkCockpit, [name: name]})
    name
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      name = :"dc_start_#{System.unique_integer()}"
      assert {:ok, pid} = start_supervised({DarkCockpit, [name: name]})
      assert Process.alive?(pid)
    end
  end

  describe "register_indicator/3" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :register_indicator, 3)
    end
  end

  describe "set_level/3" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :set_level, 3)
    end
  end

  describe "clear/1" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :clear, 1)
    end
  end

  describe "clear_all/0" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :clear_all, 0)
    end
  end

  describe "acknowledge/1" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :acknowledge, 1)
    end
  end

  describe "current_state/0" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :current_state, 0)
    end
  end

  describe "active_alerts/0" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :active_alerts, 0)
    end
  end

  describe "critical_alerts/0" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :critical_alerts, 0)
    end
  end

  describe "render_ascii/0" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :render_ascii, 0)
    end
  end

  describe "render_json/0" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :render_json, 0)
    end
  end

  describe "stats/0" do
    test "is exported" do
      assert function_exported?(DarkCockpit, :stats, 0)
    end
  end

  describe "initial state" do
    test "process starts alive" do
      name = :"dc_alive_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({DarkCockpit, [name: name]})
      assert Process.alive?(pid)
    end

    test "GenServer behaviour implemented" do
      behaviours = DarkCockpit.__info__(:attributes)[:behaviour] || []
      assert GenServer in behaviours
    end
  end
end
