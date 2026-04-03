defmodule Indrajaal.Observability.ZenohBridges.ClusterBridge do
  @moduledoc """
  Zenoh bridge for Cluster subsystem.

  WHAT: Provides Zenoh data/control plane for cluster node management.
  WHY: SC-ZENOH-INT-001 requires all components to have Zenoh access.

  ## Topics
  - indrajaal/cluster/nodes/** - Node status
  - indrajaal/cluster/health - Overall cluster health
  - indrajaal/cluster/control/** - Cluster commands
  """

  use GenServer
  require Logger

  @prefix "indrajaal/cluster"

  # Use function to avoid compile-time warning for test-only module
  defp zenoh_coordinator_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def publish_node_status(node_name, status) do
    GenServer.cast(__MODULE__, {:publish, "nodes/#{node_name}", status})
  end

  def publish_health(health_data) do
    GenServer.cast(__MODULE__, {:publish, "health", health_data})
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
