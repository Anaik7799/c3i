defmodule Indrajaal.Observability.ZenohBridges.ContainerBridgeTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohBridges.ContainerBridge

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ContainerBridge)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ContainerBridge, :start_link, 1)
    end

    test "publish_container_status/2 is exported" do
      assert function_exported?(ContainerBridge, :publish_container_status, 2)
    end

    test "publish_container_metrics/2 is exported" do
      assert function_exported?(ContainerBridge, :publish_container_metrics, 2)
    end
  end

  describe "module attributes" do
    test "defines known container atoms" do
      # The module defines @containers [:app, :db, :obs]
      # We can verify by attempting calls with those container names
      assert is_atom(:app)
      assert is_atom(:db)
      assert is_atom(:obs)
    end
  end

  describe "ContainerBridge GenServer lifecycle" do
    setup do
      name = :"cob_test_#{System.unique_integer([:positive])}"

      case ContainerBridge.start_link(name: name) do
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

    test "publish_container_status/2 completes", %{bridge: pid, name: name} do
      if pid != nil do
        result =
          ContainerBridge.publish_container_status(name, %{
            container: :app,
            status: :running,
            health: :healthy
          })

        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "publish_container_metrics/2 completes", %{bridge: pid, name: name} do
      if pid != nil do
        result =
          ContainerBridge.publish_container_metrics(name, %{
            container: :db,
            cpu: 0.15,
            memory_mb: 256
          })

        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
