defmodule Indrajaal.Distributed.Agents.BaseAgentTest do
  @moduledoc """
  TDG tests for Indrajaal.Distributed.Agents.BaseAgent.

  Tests the BaseAgent macro/behaviour definition.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.Agents.BaseAgent

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(BaseAgent)
    end

    test "defines handle_command callback" do
      callbacks = BaseAgent.behaviour_info(:callbacks)
      assert {:handle_command, 3} in callbacks
    end

    test "defines agent_init callback" do
      callbacks = BaseAgent.behaviour_info(:callbacks)
      assert {:agent_init, 1} in callbacks
    end

    test "defines agent_state callback" do
      callbacks = BaseAgent.behaviour_info(:callbacks)
      assert {:agent_state, 1} in callbacks
    end

    test "defines agent_metrics callback" do
      callbacks = BaseAgent.behaviour_info(:callbacks)
      assert {:agent_metrics, 1} in callbacks
    end

    test "handle_agent_info is optional" do
      optional_callbacks = BaseAgent.behaviour_info(:optional_callbacks)
      assert {:handle_agent_info, 2} in optional_callbacks
    end
  end
end
