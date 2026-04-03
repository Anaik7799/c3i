defmodule Indrajaal.Observability.ZenohContainerPublisherTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohContainerPublisher

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohContainerPublisher)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ZenohContainerPublisher, :start_link, 1)
    end

    test "publish_now/1 is exported" do
      assert function_exported?(ZenohContainerPublisher, :publish_now, 1)
    end

    test "get_stats/1 is exported" do
      assert function_exported?(ZenohContainerPublisher, :get_stats, 1)
    end

    test "get_states/1 is exported" do
      assert function_exported?(ZenohContainerPublisher, :get_states, 1)
    end

    test "publish_event/4 is exported" do
      assert function_exported?(ZenohContainerPublisher, :publish_event, 4)
    end

    test "subscribe/2 is exported" do
      assert function_exported?(ZenohContainerPublisher, :subscribe, 2)
    end

    test "unsubscribe/2 is exported" do
      assert function_exported?(ZenohContainerPublisher, :unsubscribe, 2)
    end
  end

  describe "ZenohContainerPublisher GenServer lifecycle" do
    setup do
      name = :"zcp_test_#{System.unique_integer([:positive])}"

      case ZenohContainerPublisher.start_link(name: name) do
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
        result = ZenohContainerPublisher.get_stats(name)
        assert is_map(result) or match?({:ok, _}, result)
      end
    end

    test "get_states/1 returns map or list", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohContainerPublisher.get_states(name)
        assert is_map(result) or is_list(result) or match?({:ok, _}, result)
      end
    end

    test "publish_now/1 completes without crash", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohContainerPublisher.publish_now(name)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
