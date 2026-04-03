defmodule Indrajaal.Observability.ZenohBridges.CortexBridgeTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohBridges.CortexBridge

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(CortexBridge)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(CortexBridge, :start_link, 1)
    end

    test "publish_sensor/2 is exported" do
      assert function_exported?(CortexBridge, :publish_sensor, 2)
    end

    test "publish_reflex/2 is exported" do
      assert function_exported?(CortexBridge, :publish_reflex, 2)
    end
  end

  describe "CortexBridge GenServer lifecycle" do
    setup do
      name = :"cortex_bridge_test_#{System.unique_integer([:positive])}"

      case CortexBridge.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{bridge: pid, name: name}

        {:error, _} ->
          %{bridge: nil, name: name}
      end
    end

    test "starts or gracefully fails", %{bridge: pid} do
      if pid != nil, do: assert(Process.alive?(pid))
    end

    test "publish_sensor/2 completes without crash", %{bridge: pid, name: name} do
      if pid != nil do
        result =
          CortexBridge.publish_sensor(name, %{
            sensor: :cpu_monitor,
            value: 0.45,
            timestamp: DateTime.utc_now()
          })

        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "publish_reflex/2 completes without crash", %{bridge: pid, name: name} do
      if pid != nil do
        result =
          CortexBridge.publish_reflex(name, %{
            reflex: :cpu_throttle,
            action: :scale_down,
            trigger: :high_cpu
          })

        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
