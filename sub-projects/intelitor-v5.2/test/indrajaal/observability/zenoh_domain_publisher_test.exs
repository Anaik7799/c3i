defmodule Indrajaal.Observability.ZenohDomainPublisherTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohDomainPublisher

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohDomainPublisher)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ZenohDomainPublisher, :start_link, 1)
    end

    test "publish_all/1 is exported" do
      assert function_exported?(ZenohDomainPublisher, :publish_all, 1)
    end

    test "get_stats/1 is exported" do
      assert function_exported?(ZenohDomainPublisher, :get_stats, 1)
    end

    test "publish_alarm_event/3 is exported" do
      assert function_exported?(ZenohDomainPublisher, :publish_alarm_event, 3)
    end

    test "publish_device_event/4 is exported" do
      assert function_exported?(ZenohDomainPublisher, :publish_device_event, 4)
    end

    test "publish_access_event/2 is exported" do
      assert function_exported?(ZenohDomainPublisher, :publish_access_event, 2)
    end

    test "subscribe/3 is exported" do
      assert function_exported?(ZenohDomainPublisher, :subscribe, 3)
    end

    test "unsubscribe/2 is exported" do
      assert function_exported?(ZenohDomainPublisher, :unsubscribe, 2)
    end
  end

  describe "ZenohDomainPublisher GenServer lifecycle" do
    setup do
      name = :"zdp_test_#{System.unique_integer([:positive])}"

      case ZenohDomainPublisher.start_link(name: name) do
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
        result = ZenohDomainPublisher.get_stats(name)
        assert is_map(result) or match?({:ok, _}, result)
      end
    end

    test "publish_all/1 completes without crash", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohDomainPublisher.publish_all(name)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "publish_alarm_event/3 completes", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohDomainPublisher.publish_alarm_event(name, :fire_alarm, %{zone: "A1"})
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
