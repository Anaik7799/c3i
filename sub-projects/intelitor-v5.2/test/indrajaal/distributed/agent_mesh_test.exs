defmodule Indrajaal.Distributed.AgentMeshTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.AgentMesh

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AgentMesh)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(AgentMesh, :start_link, 1)
    end

    test "defines agents/0" do
      assert function_exported?(AgentMesh, :agents, 0)
    end

    test "defines agent_count/0" do
      assert function_exported?(AgentMesh, :agent_count, 0)
    end

    test "defines get_agent/1" do
      assert function_exported?(AgentMesh, :get_agent, 1)
    end

    test "defines agent_fquns/0" do
      assert function_exported?(AgentMesh, :agent_fquns, 0)
    end

    test "defines mesh_status/0" do
      assert function_exported?(AgentMesh, :mesh_status, 0)
    end

    test "defines publish_state/2" do
      assert function_exported?(AgentMesh, :publish_state, 2)
    end

    test "defines send_command/3" do
      assert function_exported?(AgentMesh, :send_command, 3)
    end

    test "defines broadcast_command/2" do
      assert function_exported?(AgentMesh, :broadcast_command, 2)
    end

    test "defines list_agents/0" do
      assert function_exported?(AgentMesh, :list_agents, 0)
    end

    test "defines get_all_metrics/0" do
      assert function_exported?(AgentMesh, :get_all_metrics, 0)
    end

    test "defines ping_all/0" do
      assert function_exported?(AgentMesh, :ping_all, 0)
    end
  end

  describe "agents/0 static data" do
    test "returns a list" do
      agents = AgentMesh.agents()
      assert is_list(agents)
    end

    test "returns 7 agents" do
      agents = AgentMesh.agents()
      assert length(agents) == 7
    end

    test "each agent has required fields" do
      for agent <- AgentMesh.agents() do
        assert Map.has_key?(agent, :id)
        assert Map.has_key?(agent, :module)
        assert Map.has_key?(agent, :type)
        assert Map.has_key?(agent, :namespace)
        assert Map.has_key?(agent, :name)
      end
    end
  end

  describe "agent_count/0" do
    test "returns 7" do
      assert AgentMesh.agent_count() == 7
    end
  end

  describe "get_agent/1" do
    test "returns agent for known id" do
      agent = AgentMesh.get_agent(:ooda_agent)
      assert is_map(agent)
      assert agent.id == :ooda_agent
    end

    test "returns nil for unknown id" do
      result = AgentMesh.get_agent(:nonexistent_agent)
      assert is_nil(result)
    end
  end

  describe "send_command/3 error handling" do
    test "returns error for unknown agent" do
      result = AgentMesh.send_command(:nonexistent_agent, :ping, %{})
      assert match?({:error, :agent_not_found}, result)
    end
  end

  describe "Supervisor" do
    test "defines child_spec/1" do
      assert function_exported?(AgentMesh, :child_spec, 1)
    end
  end
end
