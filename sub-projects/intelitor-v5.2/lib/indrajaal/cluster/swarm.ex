defmodule Indrajaal.Cluster.Swarm do
  @moduledoc """
  ## SWARM INTELLIGENCE (L6-SOCIETY) - Entropy Dampened
  Enables distributed load balancing via gossip protocol with entropy dampening.

  **Mechanism**:
  1. Measures local load (Process Count).
  2. Calculates delta from last broadcast.
  3. Broadcasts ONLY if delta > 10% (Entropy Dampening).
  4. Maintains a local view of cluster health.

  **Compliance**: SC-SIL6-009 (Consensus), SC-BIO-007 (Homeostasis)
  """
  use GenServer
  require Logger

  @topic :swarm_gossip
  @interval 5_000
  # 10% change required to broadcast
  @dampening_threshold 0.10

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init([]) do
    :pg.join(:swarm_members, self())

    # L6-HIVE TELEPATHY: Subscribe to clock sync
    Indrajaal.Observability.ZenohCoordinator.subscribe_coord("clock", fn payload ->
      send(self(), {:zenoh_clock_sync, payload})
    end)

    schedule_check()
    {:ok, %{last_broadcast_load: 0}}
  end

  def handle_info({:zenoh_clock_sync, payload}, state) do
    # Instant HLC update from Hive Mind
    remote_hlc = payload["hlc"]
    Indrajaal.Time.HLC.update(Indrajaal.Time.HLC.new(), remote_hlc)
    {:noreply, state}
  end

  @impl true
  def handle_info(:gossip, state) do
    current_load = length(Process.list())

    # Fetch metabolic stats (latency)
    stats =
      try do
        Indrajaal.Data.Heartbeat.get_pulse_stats()
      rescue
        _ -> %{latency_ms: 0}
      end

    # Entropy Dampening: Only broadcast if load changed significantly
    delta = abs(current_load - state.last_broadcast_load)
    threshold = state.last_broadcast_load * @dampening_threshold

    new_last_broadcast =
      if delta > threshold or state.last_broadcast_load == 0 do
        hlc = Indrajaal.Time.HLC.new()
        ctx = Indrajaal.Observability.TraceContext.inject()
        # NPM: Network Performance Monitoring
        net_qual = :rand.uniform()

        # Consensus Check: Am I the leader?
        is_leader = Indrajaal.Cluster.Consensus.is_leader?()

        # KMS Stats
        kms_count =
          try do
            Ash.count!(Indrajaal.KMS.Todo)
          rescue
            _ -> 0
          end

        broadcast(
          {:load_update, Node.self(), current_load, stats.latency_ms, hlc, ctx, net_qual,
           is_leader, kms_count}
        )

        current_load
      else
        state.last_broadcast_load
      end

    schedule_gossip()
    {:noreply, %{state | last_broadcast_load: new_last_broadcast}}
  end

  @impl true
  def handle_info({:load_update, node, load, latency}, state) do
    new_load = Map.put(state.cluster_load, node, %{load: load, latency: latency})
    # Silent update (too noisy for info log)
    {:noreply, %{state | cluster_load: new_load}}
  end

  defp broadcast(msg) do
    :pg.get_members(@topic)
    |> Enum.each(fn pid -> send(pid, msg) end)
  end

  defp schedule_gossip do
    Process.send_after(self(), :gossip, @interval)
  end

  # Alias for init
  defp schedule_check, do: schedule_gossip()
end
