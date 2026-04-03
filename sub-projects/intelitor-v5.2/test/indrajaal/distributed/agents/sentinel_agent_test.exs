defmodule Indrajaal.Distributed.Agents.SentinelAgentTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.Agents.SentinelAgent

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SentinelAgent)
    end
  end

  describe "public API (injected by BaseAgent)" do
    test "defines start_link/1" do
      assert function_exported?(SentinelAgent, :start_link, 1)
    end

    test "defines ping/0" do
      assert function_exported?(SentinelAgent, :ping, 0)
    end

    test "defines get_state/0" do
      assert function_exported?(SentinelAgent, :get_state, 0)
    end

    test "defines get_metrics/0" do
      assert function_exported?(SentinelAgent, :get_metrics, 0)
    end

    test "defines get_fqun/0" do
      assert function_exported?(SentinelAgent, :get_fqun, 0)
    end
  end

  describe "BaseAgent callbacks" do
    test "defines agent_init/1" do
      assert function_exported?(SentinelAgent, :agent_init, 1)
    end

    test "defines agent_state/1" do
      assert function_exported?(SentinelAgent, :agent_state, 1)
    end

    test "defines agent_metrics/1" do
      assert function_exported?(SentinelAgent, :agent_metrics, 1)
    end

    test "defines handle_command/3" do
      assert function_exported?(SentinelAgent, :handle_command, 3)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(SentinelAgent, :child_spec, 1)
    end
  end
end
