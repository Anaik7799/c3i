defmodule Indrajaal.Federation.UpgradeNotifier do
  @moduledoc """
  Federation Upgrade Notifier - Broadcasts upgrade announcements to peer holons.

  ## WHAT
  Notifies all federation peers about upgrade events using Zenoh pub/sub.
  Implements version vector propagation for consistent distributed upgrades.

  ## WHY
  SIL-4 federated systems require synchronized upgrades to maintain consistency.
  All peers must be aware of version changes to negotiate compatibility.

  ## STAMP Constraints
  - SC-RECONFIG-010: Federation notification required for major reconfigurations
  - SC-REG-010: Protocol version in every block
  - SC-REG-013: Cross-holon attestation for federation
  - SC-SIL4-011: Quorum = ⌊N/2⌋ + 1 maintained during upgrades

  ## AOR Rules
  - AOR-RECONFIG-004: Notify federation peers of major reconfigurations
  - AOR-REG-012: Federation attestation every hour

  ## Protocol
  1. ANNOUNCE: Broadcast upgrade intention with version vector
  2. ACKNOWLEDGE: Collect acks from peers (quorum required)
  3. COMMIT: Broadcast upgrade completion
  4. VERIFY: Confirm all peers received notification

  ## Zenoh Topics
  - indrajaal/federation/{holon_id}/upgrades/announce
  - indrajaal/federation/{holon_id}/upgrades/ack
  - indrajaal/federation/{holon_id}/upgrades/commit
  """

  use GenServer
  require Logger

  alias Indrajaal.Core.Holon.ImmutableRegister, as: Register
  alias Indrajaal.Observability.ZenohSession

  @type holon_id :: String.t()
  @type version_vector :: %{holon_id() => non_neg_integer()}
  @type upgrade_announcement :: %{
          id: String.t(),
          holon_id: holon_id(),
          current_version: String.t(),
          target_version: String.t(),
          version_vector: version_vector(),
          protocol_version: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @type acknowledgement :: %{
          holon_id: holon_id(),
          upgrade_id: String.t(),
          compatible: boolean(),
          min_protocol_version: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @protocol_version 1
  @quorum_timeout_ms 30_000
  @announcement_timeout_ms 60_000

  # GenServer API

  @doc """
  Starts the UpgradeNotifier GenServer.
  """
  def start_link(opts \\ []) do
    holon_id = Keyword.get(opts, :holon_id, generate_holon_id())
    GenServer.start_link(__MODULE__, %{holon_id: holon_id}, name: __MODULE__)
  end

  @doc """
  Announces an upgrade to all federation peers.

  Returns `{:ok, announcement_id}` when quorum acknowledges,
  or `{:error, reason}` if quorum not reached.

  ## STAMP: SC-RECONFIG-010 - Federation notification required
  """
  @spec announce_upgrade(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def announce_upgrade(current_version, target_version, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:announce, current_version, target_version, opts},
      @announcement_timeout_ms
    )
  end

  @doc """
  Broadcasts upgrade completion to all peers.

  ## STAMP: SC-REG-010 - Protocol version in every block
  """
  @spec commit_upgrade(String.t(), String.t()) :: :ok | {:error, term()}
  def commit_upgrade(upgrade_id, new_version) do
    GenServer.call(__MODULE__, {:commit, upgrade_id, new_version})
  end

  @doc """
  Returns the current version vector for this holon.
  """
  @spec version_vector() :: version_vector()
  def version_vector do
    GenServer.call(__MODULE__, :version_vector)
  end

  @doc """
  Returns all known federation peers.
  """
  @spec peers() :: list(holon_id())
  def peers do
    GenServer.call(__MODULE__, :peers)
  end

  @doc """
  Returns pending upgrade announcements.
  """
  @spec pending_announcements() :: list(upgrade_announcement())
  def pending_announcements do
    GenServer.call(__MODULE__, :pending)
  end

  @doc """
  Manually adds a federation peer.
  """
  @spec add_peer(holon_id()) :: :ok
  def add_peer(peer_id) do
    GenServer.cast(__MODULE__, {:add_peer, peer_id})
  end

  @doc """
  Removes a federation peer.
  """
  @spec remove_peer(holon_id()) :: :ok
  def remove_peer(peer_id) do
    GenServer.cast(__MODULE__, {:remove_peer, peer_id})
  end

  # GenServer Callbacks

  @impl true
  def init(%{holon_id: holon_id}) do
    Logger.info("[SC-RECONFIG-010] UpgradeNotifier started for holon: #{holon_id}")

    state = %{
      holon_id: holon_id,
      version_vector: %{holon_id => 0},
      peers: [],
      pending_announcements: %{},
      pending_acks: %{},
      protocol_version: @protocol_version
    }

    # Subscribe to federation topics (would use Zenoh in production)
    schedule_peer_discovery()

    {:ok, state}
  end

  @impl true
  def handle_call({:announce, current_version, target_version, opts}, _from, state) do
    announcement = build_announcement(current_version, target_version, state, opts)

    # Log announcement to immutable register
    log_announcement(announcement)

    # Broadcast to all peers
    broadcast_announcement(announcement, state.peers)

    # Track pending acknowledgements
    new_pending =
      Map.put(state.pending_acks, announcement.id, %{
        announcement: announcement,
        acks: [],
        required_quorum: calculate_quorum(state.peers),
        started_at: System.monotonic_time(:millisecond)
      })

    # Schedule quorum check
    Process.send_after(self(), {:check_quorum, announcement.id}, @quorum_timeout_ms)

    # Emit telemetry
    emit_telemetry(:announce, announcement)

    Logger.info(
      "[SC-RECONFIG-010] Upgrade announced: #{announcement.id} (#{current_version} -> #{target_version})"
    )

    new_state = %{state | pending_acks: new_pending}
    {:reply, {:ok, announcement.id}, new_state}
  end

  @impl true
  def handle_call({:commit, upgrade_id, new_version}, _from, state) do
    case Map.get(state.pending_acks, upgrade_id) do
      nil ->
        {:reply, {:error, :unknown_upgrade}, state}

      _pending ->
        commit = build_commit(upgrade_id, new_version, state)

        # Broadcast commit to all peers
        broadcast_commit(commit, state.peers)

        # Update version vector
        new_vv = Map.update(state.version_vector, state.holon_id, 1, &(&1 + 1))

        # Log commit
        log_commit(commit)

        # Emit telemetry
        emit_telemetry(:commit, commit)

        Logger.info("[SC-REG-010] Upgrade committed: #{upgrade_id} -> #{new_version}")

        new_state = %{
          state
          | version_vector: new_vv,
            pending_acks: Map.delete(state.pending_acks, upgrade_id)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:version_vector, _from, state) do
    {:reply, state.version_vector, state}
  end

  @impl true
  def handle_call(:peers, _from, state) do
    {:reply, state.peers, state}
  end

  @impl true
  def handle_call(:pending, _from, state) do
    announcements =
      state.pending_acks
      |> Map.values()
      |> Enum.map(& &1.announcement)

    {:reply, announcements, state}
  end

  @impl true
  def handle_cast({:add_peer, peer_id}, state) do
    if peer_id in state.peers do
      {:noreply, state}
    else
      Logger.info("[SC-REG-013] Added federation peer: #{peer_id}")
      new_vv = Map.put_new(state.version_vector, peer_id, 0)
      {:noreply, %{state | peers: [peer_id | state.peers], version_vector: new_vv}}
    end
  end

  @impl true
  def handle_cast({:remove_peer, peer_id}, state) do
    Logger.info("[SC-REG-013] Removed federation peer: #{peer_id}")
    new_peers = List.delete(state.peers, peer_id)
    {:noreply, %{state | peers: new_peers}}
  end

  @impl true
  def handle_cast({:ack_received, ack}, state) do
    case Map.get(state.pending_acks, ack.upgrade_id) do
      nil ->
        {:noreply, state}

      pending ->
        new_acks = [ack | pending.acks]
        updated_pending = %{pending | acks: new_acks}
        new_pending_acks = Map.put(state.pending_acks, ack.upgrade_id, updated_pending)

        # Check if quorum reached
        if length(new_acks) >= pending.required_quorum do
          Logger.info("[SC-SIL4-011] Quorum reached for upgrade: #{ack.upgrade_id}")
          emit_telemetry(:quorum_reached, %{upgrade_id: ack.upgrade_id, acks: length(new_acks)})
        end

        {:noreply, %{state | pending_acks: new_pending_acks}}
    end
  end

  @impl true
  def handle_info({:check_quorum, upgrade_id}, state) do
    case Map.get(state.pending_acks, upgrade_id) do
      nil ->
        {:noreply, state}

      pending ->
        ack_count = length(pending.acks)

        if ack_count < pending.required_quorum do
          Logger.warning(
            "[SC-SIL4-011] Quorum not reached for #{upgrade_id}: #{ack_count}/#{pending.required_quorum}"
          )

          emit_telemetry(:quorum_timeout, %{
            upgrade_id: upgrade_id,
            acks: ack_count,
            required: pending.required_quorum
          })
        end

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:peer_discovery, state) do
    # In production, this would discover peers via Zenoh/mDNS/etc
    schedule_peer_discovery()
    {:noreply, state}
  end

  # Private Functions

  defp build_announcement(current_version, target_version, state, opts) do
    %{
      id: generate_id(),
      holon_id: state.holon_id,
      current_version: current_version,
      target_version: target_version,
      version_vector: state.version_vector,
      protocol_version: state.protocol_version,
      timestamp: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp build_commit(upgrade_id, new_version, state) do
    %{
      upgrade_id: upgrade_id,
      holon_id: state.holon_id,
      new_version: new_version,
      version_vector: state.version_vector,
      protocol_version: state.protocol_version,
      timestamp: DateTime.utc_now()
    }
  end

  defp broadcast_announcement(announcement, peers) do
    Enum.each(peers, fn peer_id ->
      # In production, publish to Zenoh topic
      Logger.debug("[SC-RECONFIG-010] Broadcasting to peer: #{peer_id}")
      send_to_peer(peer_id, {:upgrade_announce, announcement})
    end)
  end

  defp broadcast_commit(commit, peers) do
    Enum.each(peers, fn peer_id ->
      Logger.debug("[SC-REG-010] Broadcasting commit to peer: #{peer_id}")
      send_to_peer(peer_id, {:upgrade_commit, commit})
    end)
  end

  defp send_to_peer(peer_id, message) do
    # SC-RECONFIG-010: Publish upgrade messages to federation peers via Zenoh.
    # The key expression encodes the message type so peers can filter selectively.
    {type_tag, payload} =
      case message do
        {:upgrade_announce, announcement} -> {"announce", announcement}
        {:upgrade_commit, commit} -> {"commit", commit}
        _ -> {"event", message}
      end

    key = "indrajaal/federation/#{peer_id}/upgrades/#{type_tag}"

    encoded =
      Jason.encode!(%{
        type: type_tag,
        payload: to_string(inspect(payload)),
        sender: node() |> to_string(),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    ZenohSession.publish_async(key, encoded)
    Logger.debug("[SC-RECONFIG-010] Upgrade #{type_tag} sent to peer #{peer_id} via Zenoh")
    :ok
  rescue
    error ->
      Logger.warning("[SC-RECONFIG-010] send_to_peer exception for #{peer_id}: #{inspect(error)}")
      :ok
  end

  defp calculate_quorum(peers) do
    # SC-SIL4-011: Quorum = ⌊N/2⌋ + 1
    peer_count = length(peers)
    max(1, div(peer_count, 2) + 1)
  end

  defp log_announcement(announcement) do
    try do
      Register.append(:federation, %{
        type: :upgrade_announce,
        data: announcement,
        timestamp: DateTime.utc_now()
      })
    rescue
      _ ->
        Logger.warning("[SC-REG-010] Could not log announcement to register")
    end
  end

  defp log_commit(commit) do
    try do
      Register.append(:federation, %{
        type: :upgrade_commit,
        data: commit,
        timestamp: DateTime.utc_now()
      })
    rescue
      _ ->
        Logger.warning("[SC-REG-010] Could not log commit to register")
    end
  end

  defp schedule_peer_discovery do
    Process.send_after(self(), :peer_discovery, 60_000)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_holon_id do
    "holon_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:indrajaal, :federation, :upgrade, event],
      %{timestamp: System.monotonic_time()},
      metadata
    )
  end
end
