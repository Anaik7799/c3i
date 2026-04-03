defmodule Indrajaal.Cockpit.Proprioceptive.IntentTest do
  @moduledoc """
  TDG tests for Indrajaal.Cockpit.Proprioceptive.Intent.

  ## STAMP Safety Integration
  - SC-PRAJNA-004: Cockpit intent recognition

  ## TPS 5-Level RCA Context
  - L1 Symptom: Intent not predicted from user actions
  - L5 Root Cause: Action history not retained or learned
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Proprioceptive.Intent

  describe "start_link/1" do
    test "starts GenServer successfully" do
      name = :"intent_#{System.unique_integer()}"
      assert {:ok, pid} = start_supervised({Intent, [name: name]})
      assert Process.alive?(pid)
    end
  end

  describe "function exports" do
    test "record_action/2 is exported" do
      assert function_exported?(Intent, :record_action, 2)
    end

    test "predict/0 is exported" do
      assert function_exported?(Intent, :predict, 0)
    end

    test "suggest_next/0 is exported" do
      assert function_exported?(Intent, :suggest_next, 0)
    end

    test "likely_intent/0 is exported" do
      assert function_exported?(Intent, :likely_intent, 0)
    end

    test "learn/2 is exported" do
      assert function_exported?(Intent, :learn, 2)
    end

    test "history/1 is exported" do
      assert function_exported?(Intent, :history, 1)
    end

    test "clear_history/0 is exported" do
      assert function_exported?(Intent, :clear_history, 0)
    end

    test "stats/0 is exported" do
      assert function_exported?(Intent, :stats, 0)
    end
  end

  describe "GenServer behaviour" do
    test "implements GenServer" do
      behaviours = Intent.__info__(:attributes)[:behaviour] || []
      assert GenServer in behaviours
    end

    test "process remains alive after start" do
      name = :"intent_alive_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({Intent, [name: name]})
      :timer.sleep(10)
      assert Process.alive?(pid)
    end
  end
end
