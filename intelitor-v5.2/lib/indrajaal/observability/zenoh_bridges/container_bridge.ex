defmodule Indrajaal.Observability.ZenohBridges.ContainerBridge do
  @moduledoc """
  Zenoh bridge for Container subsystem.

  WHAT: Provides Zenoh data/control plane for container management.
  WHY: SC-ZENOH-INT-001 requires all components to have Zenoh access.

  ## Topics
  - indrajaal/container/app/** - App container
  - indrajaal/container/db/** - DB container
  - indrajaal/container/obs/** - Obs container
  """

  use GenServer
  require Logger

  @prefix "indrajaal/container"
  @containers [:app, :db, :obs]

  # Use function to avoid compile-time warning for test-only module
  defp zenoh_coordinator_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def publish_container_status(container, status) when container in @containers do
    GenServer.cast(__MODULE__, {:publish, "#{container}/status", status})
  end

  def publish_container_metrics(container, metrics) when container in @containers do
    GenServer.cast(__MODULE__, {:publish, "#{container}/metrics", metrics})
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:publish, key, data}, state) do
    zenoh_publish("#{@prefix}/#{key}", data)
    {:noreply, state}
  end

  defp zenoh_publish(key, data) do
    module = zenoh_coordinator_module()

    if Code.ensure_loaded?(module) do
      {:ok, c} = module.start_link()
      module.publish(c, key, data)
      GenServer.stop(c)
    end
  end
end
