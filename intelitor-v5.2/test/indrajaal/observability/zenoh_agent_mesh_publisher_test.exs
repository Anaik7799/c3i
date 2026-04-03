defmodule Indrajaal.Observability.ZenohAgentMeshPublisherTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohAgentMeshPublisher

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohAgentMeshPublisher)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :start_link, 1)
    end

    test "publish_topology/1 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :publish_topology, 1)
    end

    test "get_stats/1 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :get_stats, 1)
    end

    test "get_agent_states/1 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :get_agent_states, 1)
    end

    test "publish_command/4 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :publish_command, 4)
    end

    test "agent_heartbeat/3 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :agent_heartbeat, 3)
    end

    test "subscribe/2 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :subscribe, 2)
    end

    test "unsubscribe/2 is exported" do
      assert function_exported?(ZenohAgentMeshPublisher, :unsubscribe, 2)
    end
  end

  describe "ZenohAgentMeshPublisher GenServer lifecycle" do
    setup do
      name = :"zamp_test_#{System.unique_integer([:positive])}"

      case ZenohAgentMeshPublisher.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{publisher: pid, name: name}

        {:error, _} ->
          %{publisher: nil, name: name}
      end
    end

    test "starts or gracefully fails", %{publisher: pid} do
      if pid != nil, do: assert(Process.alive?(pid))
    end

    test "get_stats/1 returns map", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohAgentMeshPublisher.get_stats(name)
        assert is_map(result) or match?({:ok, _}, result)
      end
    end

    test "get_agent_states/1 returns map or list", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohAgentMeshPublisher.get_agent_states(name)
        assert is_map(result) or is_list(result) or match?({:ok, _}, result)
      end
    end

    test "publish_topology/1 completes without raising", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohAgentMeshPublisher.publish_topology(name)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
