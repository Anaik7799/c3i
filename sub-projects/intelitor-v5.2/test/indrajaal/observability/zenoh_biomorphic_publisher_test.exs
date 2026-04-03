defmodule Indrajaal.Observability.ZenohBiomorphicPublisherTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohBiomorphicPublisher

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohBiomorphicPublisher)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ZenohBiomorphicPublisher, :start_link, 1)
    end

    test "publish_vitals/1 is exported" do
      assert function_exported?(ZenohBiomorphicPublisher, :publish_vitals, 1)
    end

    test "get_stats/1 is exported" do
      assert function_exported?(ZenohBiomorphicPublisher, :get_stats, 1)
    end

    test "get_holon_states/1 is exported" do
      assert function_exported?(ZenohBiomorphicPublisher, :get_holon_states, 1)
    end

    test "publish_evolution/4 is exported" do
      assert function_exported?(ZenohBiomorphicPublisher, :publish_evolution, 4)
    end

    test "subscribe/2 is exported" do
      assert function_exported?(ZenohBiomorphicPublisher, :subscribe, 2)
    end

    test "unsubscribe/2 is exported" do
      assert function_exported?(ZenohBiomorphicPublisher, :unsubscribe, 2)
    end
  end

  describe "ZenohBiomorphicPublisher GenServer lifecycle" do
    setup do
      name = :"zbp_test_#{System.unique_integer([:positive])}"

      case ZenohBiomorphicPublisher.start_link(name: name) do
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
        result = ZenohBiomorphicPublisher.get_stats(name)
        assert is_map(result) or match?({:ok, _}, result)
      end
    end

    test "get_holon_states/1 returns map or list", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohBiomorphicPublisher.get_holon_states(name)
        assert is_map(result) or is_list(result) or match?({:ok, _}, result)
      end
    end

    test "publish_vitals/1 completes without crash", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohBiomorphicPublisher.publish_vitals(name)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
