defmodule Indrajaal.Core.Holon.LegacyReplicator do
  @moduledoc """
  Eternal Legacy Replicator (Ω₈ Replicator).

  WHAT: Replicates Founder's history logs across the Tailscale mesh.
  WHY: Ω₀.2 requires genetic and legacy perpetuity; ensuring history survives any single node failure.
  CONSTRAINTS: MUST use cryptographic chain validation (SC-REG-001) during replication.
  """

  use GenServer
  require Logger
  alias Indrajaal.Mesh.TailscaleMesh
  alias Indrajaal.Core.Holon.FounderHistory

  # 1 minute heartbeat sync
  @replication_interval_ms 60_000

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers immediate replication of a new event to the mesh.
  """
  def replicate_event(event) do
    GenServer.cast(__MODULE__, {:replicate_event, event})
  end

  @doc """
  Requests missing history blocks from peers.
  """
  def sync_with_peers do
    GenServer.cast(__MODULE__, :sync_with_peers)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[LegacyReplicator] Activating Ω₈ Eternal Register...")
    schedule_sync()
    {:ok, %{peers_synced: 0}}
  end

  @impl true
  def handle_cast({:replicate_event, event}, state) do
    # Broadcast to Tailscale Mesh
    Logger.debug("[LegacyReplicator] Broadcasting event #{event.id} to mesh")
    TailscaleMesh.broadcast({:legacy_history_event, event})
    {:noreply, state}
  end

  @impl true
  def handle_cast(:sync_with_peers, state) do
    # Request latest hash from peers to detect gaps
    TailscaleMesh.broadcast({:request_latest_legacy_hash, node()})
    {:noreply, state}
  end

  @impl true
  def handle_info(:scheduled_sync, state) do
    sync_with_peers()
    schedule_sync()
    {:noreply, state}
  end

  # Handle incoming peer messages
  @impl true
  def handle_info({:legacy_history_event, event}, state) do
    # Verify chain integrity and store
    case FounderHistory.verify_and_store_remote_event(event) do
      :ok ->
        Logger.info("[LegacyReplicator] Synchronized event #{event.id} from peer")
        {:noreply, %{state | peers_synced: state.peers_synced + 1}}

      {:error, reason} ->
        Logger.warning("[LegacyReplicator] Rejected peer event #{event.id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # HELPERS
  # ============================================================

  defp schedule_sync do
    Process.send_after(self(), :scheduled_sync, @replication_interval_ms)
  end
end
