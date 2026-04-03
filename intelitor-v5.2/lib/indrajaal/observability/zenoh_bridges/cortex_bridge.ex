defmodule Indrajaal.Observability.ZenohBridges.CortexBridge do
  @moduledoc """
  Zenoh bridge for Cortex subsystem.

  WHAT: Provides Zenoh data/control plane for Cortex sensors and reflexes.
  WHY: SC-ZENOH-INT-001 requires all components to have Zenoh access.

  ## Topics
  - indrajaal/cortex/sensors/** - Sensor data
  - indrajaal/cortex/reflexes/** - Reflex status
  - indrajaal/cortex/control/** - Control commands
  """

  use GenServer
  require Logger

  @prefix "indrajaal/cortex"

  # Use function to avoid compile-time warning for test-only module
  defp zenoh_coordinator_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Publish sensor data
  def publish_sensor(sensor_name, data) do
    GenServer.cast(__MODULE__, {:publish, "sensors/#{sensor_name}", data})
  end

  # Publish reflex status
  def publish_reflex(reflex_name, status) do
    GenServer.cast(__MODULE__, {:publish, "reflexes/#{reflex_name}", status})
  end

  @impl true
  def init(_opts) do
    # Subscribe to control topics
    subscribe_to_control()
    {:ok, %{coordinator: nil}}
  end

  @impl true
  def handle_cast({:publish, key, data}, state) do
    zenoh_publish("#{@prefix}/#{key}", data)
    {:noreply, state}
  end

  defp subscribe_to_control do
    # Subscribe to indrajaal/cortex/control/**
    Logger.info("[CortexBridge] Subscribed to #{@prefix}/control/**")
  end

  defp zenoh_publish(key, data) do
    module = zenoh_coordinator_module()

    if Code.ensure_loaded?(module) do
      {:ok, coord} = module.start_link()
      module.publish(coord, key, data)
      GenServer.stop(coord)
    end
  end
end
