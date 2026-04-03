defmodule Indrajaal.Federation.PeerRegistry do
  @moduledoc """
  ## Design Intent

  L6 Federation Layer — tracks peer holons participating in the Indrajaal
  federation mesh.

  The PeerRegistry maintains a live, ETS-backed map of known peer holons:
  their metadata, last-seen heartbeat timestamps, and liveness status. A
  periodic sweep demotes stale peers from `:alive` → `:suspect` (no
  heartbeat in 30 s) → `:dead` (no heartbeat in 60 s).

  Peers announce themselves via PubSub and are discovered passively.
  Node attestation (Ed25519 verification flag) is tracked but the actual
  cryptographic check is delegated to `Indrajaal.Federation.Attestation`.

  Core responsibilities:
  - ETS-backed O(1) peer lookup by `peer_id`
  - Automatic stale peer detection (30 s → `:suspect`, 60 s → `:dead`)
  - Periodic self-announcement via PubSub `"federation:peers"`
  - Peer discovery via PubSub subscription to `"federation:peers"`
  - Ed25519 attestation flag tracking (SC-FED-006)

  ## STAMP Constraints

  - SC-FED-005: Membership management MUST be maintained — this registry
    is the authoritative source for known federation peers.
  - SC-FED-006: Attestation MUST use Ed25519 verification — the
    `:attested` flag per peer records whether attestation has been verified.
  - SC-DIST-001: FQUN MUST be present for all distributed mesh nodes.
  - SC-AGENT-001: All agents MUST have a FQUN (Fully Qualified Unit Name).
  - SC-HA-003: Zenoh 2oo3 quorum requires awareness of live peer set.

  ## Change History

  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — L6 peer registry |
  """

  use GenServer
  require Logger

  @pubsub_topic "federation:peers"
  @ets_table :federation_peer_registry

  # Liveness thresholds
  @suspect_after_ms 30_000
  @dead_after_ms 60_000

  # How often to run the staleness sweep
  @sweep_interval_ms 10_000

  # How often to announce ourselves to the federation
  @announce_interval_ms 20_000

  # ─── Types ───────────────────────────────────────────────────────────────────

  @type peer_status :: :alive | :suspect | :dead

  @type peer_entry :: %{
          peer_id: String.t(),
          fqun: String.t(),
          node_name: String.t() | nil,
          endpoints: [String.t()],
          metadata: map(),
          attested: boolean(),
          status: peer_status(),
          first_seen: DateTime.t(),
          last_seen: DateTime.t()
        }

  @type t :: %{
          local_peer_id: String.t(),
          local_fqun: String.t(),
          registered_count: non_neg_integer(),
          heartbeat_count: non_neg_integer(),
          sweep_count: non_neg_integer(),
          started_at: DateTime.t()
        }

  # ─── Public API ──────────────────────────────────────────────────────────────

  @doc "Start the PeerRegistry GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register or refresh a peer entry.

  If the peer is already known, updates `last_seen` and resets status
  to `:alive`. If new, creates a fresh entry.
  """
  @spec register_peer(peer_entry()) :: :ok
  def register_peer(%{peer_id: _} = peer_entry) do
    GenServer.cast(__MODULE__, {:register_peer, peer_entry})
  end

  @doc "Record a heartbeat from a known peer."
  @spec heartbeat(String.t()) :: :ok
  def heartbeat(peer_id) when is_binary(peer_id) do
    GenServer.cast(__MODULE__, {:heartbeat, peer_id})
  end

  @doc "Mark a peer as attested (Ed25519 signature verified)."
  @spec mark_attested(String.t()) :: :ok | {:error, :peer_not_found}
  def mark_attested(peer_id) when is_binary(peer_id) do
    GenServer.call(__MODULE__, {:mark_attested, peer_id})
  end

  @doc "Remove a peer from the registry."
  @spec remove_peer(String.t()) :: :ok
  def remove_peer(peer_id) when is_binary(peer_id) do
    GenServer.cast(__MODULE__, {:remove_peer, peer_id})
  end

  @doc "Look up a peer by ID from ETS (fast, <1ms)."
  @spec lookup(String.t()) :: {:ok, peer_entry()} | {:error, :not_found}
  def lookup(peer_id) when is_binary(peer_id) do
    if :ets.whereis(@ets_table) != :undefined do
      case :ets.lookup(@ets_table, peer_id) do
        [{^peer_id, entry}] -> {:ok, entry}
        [] -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

  @doc "List all known peers with a given status (or all if `nil`)."
  @spec list_peers(peer_status() | nil) :: [peer_entry()]
  def list_peers(status \\ nil) do
    if :ets.whereis(@ets_table) != :undefined do
      @ets_table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, entry} -> entry end)
      |> filter_by_status(status)
    else
      []
    end
  end

  @doc "Count peers by status."
  @spec peer_count(peer_status() | nil) :: non_neg_integer()
  def peer_count(status \\ nil) do
    list_peers(status) |> length()
  end

  @doc "Get the local peer ID."
  @spec local_peer_id() :: String.t()
  def local_peer_id do
    GenServer.call(__MODULE__, :local_peer_id)
  end

  @doc "Get registry statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ─── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    ensure_ets_table()

    local_peer_id = Keyword.get(opts, :peer_id, derive_local_peer_id())
    local_fqun = Keyword.get(opts, :fqun, derive_local_fqun())

    # Subscribe to peer announcements
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, @pubsub_topic)

    state = %{
      local_peer_id: local_peer_id,
      local_fqun: local_fqun,
      registered_count: 0,
      heartbeat_count: 0,
      sweep_count: 0,
      started_at: DateTime.utc_now()
    }

    # Schedule periodic sweeps and self-announcement
    schedule_sweep()
    schedule_announce()

    Logger.info(
      "[PeerRegistry] Online — peer_id=#{local_peer_id} " <>
        "fqun=#{local_fqun} — SC-FED-005, SC-FED-006"
    )

    {:ok, state}
  end

  @impl true
  def handle_cast({:register_peer, peer_entry}, state) do
    upsert_peer(peer_entry)
    publish_peer_update(:registered, peer_entry)

    Logger.debug(
      "[PeerRegistry] Registered peer=#{peer_entry.peer_id} " <>
        "fqun=#{Map.get(peer_entry, :fqun, "unknown")} status=#{peer_entry.status}"
    )

    {:noreply, %{state | registered_count: state.registered_count + 1}}
  end

  @impl true
  def handle_cast({:heartbeat, peer_id}, state) do
    case :ets.lookup(@ets_table, peer_id) do
      [{^peer_id, entry}] ->
        updated = %{entry | last_seen: DateTime.utc_now(), status: :alive}
        :ets.insert(@ets_table, {peer_id, updated})

      [] ->
        # Unknown peer announced heartbeat — log it
        Logger.debug("[PeerRegistry] Heartbeat from unknown peer=#{peer_id}")
    end

    {:noreply, %{state | heartbeat_count: state.heartbeat_count + 1}}
  end

  @impl true
  def handle_cast({:remove_peer, peer_id}, state) do
    if :ets.whereis(@ets_table) != :undefined do
      :ets.delete(@ets_table, peer_id)
      publish_peer_update(:removed, %{peer_id: peer_id})
      Logger.info("[PeerRegistry] Removed peer=#{peer_id}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:mark_attested, peer_id}, _from, state) do
    case :ets.lookup(@ets_table, peer_id) do
      [{^peer_id, entry}] ->
        updated = %{entry | attested: true}
        :ets.insert(@ets_table, {peer_id, updated})

        Logger.info("[PeerRegistry] ATTESTED peer=#{peer_id} — Ed25519 verified — SC-FED-006")

        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :peer_not_found}, state}
    end
  end

  @impl true
  def handle_call(:local_peer_id, _from, state) do
    {:reply, state.local_peer_id, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    alive = peer_count(:alive)
    suspect = peer_count(:suspect)
    dead = peer_count(:dead)

    stats = %{
      local_peer_id: state.local_peer_id,
      local_fqun: state.local_fqun,
      peers_alive: alive,
      peers_suspect: suspect,
      peers_dead: dead,
      peers_total: alive + suspect + dead,
      registered_count: state.registered_count,
      heartbeat_count: state.heartbeat_count,
      sweep_count: state.sweep_count,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    swept = run_staleness_sweep()
    schedule_sweep()

    if swept > 0 do
      Logger.debug("[PeerRegistry] Staleness sweep: #{swept} peer(s) status updated")
    end

    {:noreply, %{state | sweep_count: state.sweep_count + 1}}
  end

  @impl true
  def handle_info(:announce, state) do
    announce_self(state)
    schedule_announce()
    {:noreply, state}
  end

  @impl true
  def handle_info({:peer_announcement, announcement}, state) do
    # Received peer announcement from PubSub — register the peer
    if announcement.peer_id != state.local_peer_id do
      entry = %{
        peer_id: announcement.peer_id,
        fqun: Map.get(announcement, :fqun, "unknown"),
        node_name: Map.get(announcement, :node_name),
        endpoints: Map.get(announcement, :endpoints, []),
        metadata: Map.get(announcement, :metadata, %{}),
        attested: false,
        status: :alive,
        first_seen: DateTime.utc_now(),
        last_seen: DateTime.utc_now()
      }

      upsert_peer(entry)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[PeerRegistry] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ─── Private Helpers ─────────────────────────────────────────────────────────

  defp upsert_peer(%{peer_id: peer_id} = entry) do
    if :ets.whereis(@ets_table) != :undefined do
      updated_entry =
        case :ets.lookup(@ets_table, peer_id) do
          [{^peer_id, existing}] ->
            # Update last_seen and status, preserve first_seen and attested flag
            %{
              existing
              | last_seen: DateTime.utc_now(),
                status: :alive,
                endpoints: Map.get(entry, :endpoints, existing.endpoints),
                metadata: Map.merge(existing.metadata, Map.get(entry, :metadata, %{}))
            }

          [] ->
            # New peer — ensure required fields
            %{
              peer_id: peer_id,
              fqun: Map.get(entry, :fqun, "unknown"),
              node_name: Map.get(entry, :node_name),
              endpoints: Map.get(entry, :endpoints, []),
              metadata: Map.get(entry, :metadata, %{}),
              attested: Map.get(entry, :attested, false),
              status: :alive,
              first_seen: DateTime.utc_now(),
              last_seen: DateTime.utc_now()
            }
        end

      :ets.insert(@ets_table, {peer_id, updated_entry})
    end
  end

  defp run_staleness_sweep do
    if :ets.whereis(@ets_table) == :undefined do
      0
    else
      now = DateTime.utc_now()

      @ets_table
      |> :ets.tab2list()
      |> Enum.reduce(0, fn {peer_id, entry}, count ->
        age_ms = DateTime.diff(now, entry.last_seen, :millisecond)

        new_status =
          cond do
            age_ms >= @dead_after_ms -> :dead
            age_ms >= @suspect_after_ms -> :suspect
            true -> entry.status
          end

        if new_status != entry.status do
          updated = %{entry | status: new_status}
          :ets.insert(@ets_table, {peer_id, updated})
          publish_peer_update(:status_changed, updated)

          Logger.debug(
            "[PeerRegistry] Peer #{peer_id} status #{entry.status} → #{new_status} " <>
              "(age=#{age_ms}ms)"
          )

          count + 1
        else
          count
        end
      end)
    end
  end

  defp announce_self(state) do
    announcement = %{
      event: :peer_announcement,
      peer_id: state.local_peer_id,
      fqun: state.local_fqun,
      node_name: Atom.to_string(node()),
      endpoints: [],
      metadata: %{announced_at: DateTime.utc_now()},
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:peer_announcement, announcement})
  end

  defp publish_peer_update(event, peer) do
    message = %{
      event: event,
      peer_id: Map.get(peer, :peer_id, "unknown"),
      status: Map.get(peer, :status, :unknown),
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:peer_update, message})
  end

  defp filter_by_status(peers, nil), do: peers
  defp filter_by_status(peers, status), do: Enum.filter(peers, &(&1.status == status))

  defp ensure_ets_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  defp derive_local_peer_id do
    node_str = Atom.to_string(node())
    hash = :crypto.hash(:sha256, node_str) |> Base.encode16(case: :lower)
    "peer_#{String.slice(hash, 0, 12)}"
  end

  defp derive_local_fqun do
    node_str = Atom.to_string(node())
    "holon://#{node_str}/federation/peer"
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval_ms)
  end

  defp schedule_announce do
    Process.send_after(self(), :announce, @announce_interval_ms)
  end
end
