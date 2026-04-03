defmodule Indrajaal.Cortex.GDE.GDETest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.GDE (facade module).
  Tests module existence and public delegation API.
  STAMP: SC-GDE-001, SC-COG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.GDE

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(GDE)
    end
  end

  describe "public delegation API" do
    test "exports status/0" do
      assert function_exported?(GDE, :status, 0)
    end

    test "exports define_goal/3" do
      assert function_exported?(GDE, :define_goal, 3)
    end

    test "exports activate_goal/1" do
      assert function_exported?(GDE, :activate_goal, 1)
    end

    test "exports goal_status/1" do
      assert function_exported?(GDE, :goal_status, 1)
    end

    test "exports list_goals/1" do
      assert function_exported?(GDE, :list_goals, 1)
    end

    test "exports set_strategy/1" do
      assert function_exported?(GDE, :set_strategy, 1)
    end

    test "exports trigger_evolution/0" do
      assert function_exported?(GDE, :trigger_evolution, 0)
    end

    test "exports metrics/0" do
      assert function_exported?(GDE, :metrics, 0)
    end

    test "exports combined_stats/0" do
      assert function_exported?(GDE, :combined_stats, 0)
    end
  end
end
