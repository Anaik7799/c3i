defmodule Indrajaal.Observability.ClusterInstrumentation do
  @moduledoc """
  Instrumenter for Distributed Clustering events.

  Listens to `libcluster` and Erlang distribution events to provide observability
  into the cluster topology and health. Also actively polls cluster size for metrics.

  ## Telemetry Events Handled
  * `[:libcluster, :handler, :nodeup]`
  * `[:libcluster, :handler, :nodedown]`
  * `[:libcluster, :handler, :reconnect]`

  ## Metrics Emitted
  * `[:indrajaal, :cluster, :size]` - Number of connected nodes

  ## STAMP Compliance
  * **SC-OBS-001**: Logs all cluster topology changes to ensure auditability of network partitions or node failures.
  """

  use GenServer
  require Logger

  # Poll cluster size every 15 seconds
  @poll_interval 15_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def setup do
    # Start the GenServer part of the instrumentation
    # In a real app, this should be added to the supervision tree, but we can start it here dynamically
    # if it's not already started. Better: Add to application.ex children.
    # For now, we'll just attach handlers here as the entry point.

    events = [
      [:libcluster, :handler, :nodeup],
      [:libcluster, :handler, :nodedown],
      [:libcluster, :handler, :reconnect]
    ]

    :telemetry.attach_many(
      "indrajaal-cluster-instrumentation",
      events,
      &handle_event/4,
      nil
    )
  end

  # GenServer Implementation

  def init(_opts) do
    # Attach telemetry handlers
    setup()
    # Start polling
    schedule_poll()
    {:ok, %{}}
  end

  def handle_info(:poll_metrics, state) do
    # Count connected nodes + self
    cluster_size = length(Node.list()) + 1

    :telemetry.execute(
      [:indrajaal, :cluster, :size],
      %{value: cluster_size},
      %{node: Node.self()}
    )

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll_metrics, @poll_interval)
  end

  # Telemetry Handlers

  def handle_event([:libcluster, :handler, :nodeup], _measurements, metadata, _config) do
    Logger.info("Cluster Node UP: #{inspect(metadata.node)}",
      node: metadata.node,
      topology: metadata.topology,
      event_type: "cluster_topology_change",
      change: "join"
    )
  end

  def handle_event([:libcluster, :handler, :nodedown], _measurements, metadata, _config) do
    Logger.warning("Cluster Node DOWN: #{inspect(metadata.node)}",
      node: metadata.node,
      topology: metadata.topology,
      event_type: "cluster_topology_change",
      change: "leave"
    )
  end

  def handle_event([:libcluster, :handler, :reconnect], _measurements, metadata, _config) do
    Logger.info("Cluster Node Reconnecting: #{inspect(metadata.node)}",
      node: metadata.node,
      topology: metadata.topology,
      event_type: "cluster_topology_change",
      change: "reconnect"
    )
  end
end
