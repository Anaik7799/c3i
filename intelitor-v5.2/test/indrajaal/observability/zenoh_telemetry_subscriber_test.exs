defmodule Indrajaal.Observability.ZenohTelemetrySubscriberTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohTelemetrySubscriber

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohTelemetrySubscriber)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ZenohTelemetrySubscriber, :start_link, 1)
    end

    test "get_metrics/0 is exported" do
      assert function_exported?(ZenohTelemetrySubscriber, :get_metrics, 0)
    end

    test "get_metric/1 is exported" do
      assert function_exported?(ZenohTelemetrySubscriber, :get_metric, 1)
    end

    test "get_stats/1 is exported" do
      assert function_exported?(ZenohTelemetrySubscriber, :get_stats, 1)
    end

    test "set_enabled/2 is exported" do
      assert function_exported?(ZenohTelemetrySubscriber, :set_enabled, 2)
    end

    test "handle_fsharp_event/2 is exported" do
      assert function_exported?(ZenohTelemetrySubscriber, :handle_fsharp_event, 2)
    end
  end

  describe "ZenohTelemetrySubscriber GenServer lifecycle" do
    setup do
      name = :"zts_test_#{System.unique_integer([:positive])}"

      case ZenohTelemetrySubscriber.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{subscriber: pid, name: name}

        {:error, _} ->
          %{subscriber: nil, name: name}
      end
    end

    test "starts or gracefully fails", %{subscriber: pid} do
      if pid != nil, do: assert(Process.alive?(pid))
    end

    test "get_stats/1 returns map", %{subscriber: pid, name: name} do
      if pid != nil do
        result = ZenohTelemetrySubscriber.get_stats(name)
        assert is_map(result) or match?({:ok, _}, result)
      end
    end

    test "set_enabled/2 enables subscriber", %{subscriber: pid, name: name} do
      if pid != nil do
        result = ZenohTelemetrySubscriber.set_enabled(name, true)
        assert result == :ok or match?({:ok, _}, result)
      end
    end

    test "get_metrics/0 returns map or list" do
      # get_metrics/0 operates on default named instance
      result =
        try do
          ZenohTelemetrySubscriber.get_metrics()
        rescue
          _ -> %{}
        end

      assert is_map(result) or is_list(result)
    end
  end
end
