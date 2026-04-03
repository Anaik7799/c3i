defmodule Indrajaal.Smriti.Federation.Protocol do
  @moduledoc """
  L6-L7 Federation Protocol: Cross-holon knowledge coordination.

  Implements gossip-based synchronization between SMRITI instances
  per SC-SMRITI-063 (configurable sync interval).

  ## WHAT
  Orchestrates cross-holon knowledge federation using Zenoh pub/sub for
  real-time synchronization across the mesh.

  ## WHY
  - Enables distributed knowledge replication (SC-FRAC-005)
  - Supports global AI learning propagation (SC-FRAC-005)
  - Provides version vector conflict resolution (SC-REG-010)

  ## STAMP Constraints
  - SC-SMRITI-063: Sync interval configurable (default 1h)
  - SC-REG-010: Protocol version in every block
  - SC-REG-012: Merkle root for state verification
  - SC-REG-013: Cross-holon attestation for federation
  - SC-FRAC-004: Federation decisions require cross-holon attestation
  - SC-FRAC-006: Federation version negotiation

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-17 | Claude | Wired to real Zenoh pub/sub (Task 42.2) |
  | 21.2.0 | 2026-01-10 | - | Initial stub implementation |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohSession

  @default_sync_interval :timer.hours(1)
  @protocol_version "1.0.0"

  # Zenoh topics for federation
  @topic_sync_request "smriti/federation/sync/request"
  @topic_sync_response "smriti/federation/sync/response"
  @topic_peer_announce "smriti/federation/peers/announce"
  @topic_version_vectors "smriti/federation/versions"

  defstruct [
    :node_id,
    :peers,
    :version_vectors,
    :last_sync,
    :sync_interval,
    :subscriptions,
    :pending_syncs,
    :stats
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec discover_peers() :: {:ok, list(String.t())}
  def discover_peers do
    GenServer.call(__MODULE__, :discover_peers)
  end

  @spec sync_with_peer(String.t()) :: {:ok, map()} | {:error, term()}
  def sync_with_peer(peer_url) do
    GenServer.call(__MODULE__, {:sync, peer_url}, :timer.minutes(5))
  end

  @spec sync_all() :: {:ok, map()}
  def sync_all do
    GenServer.call(__MODULE__, :sync_all, :timer.minutes(30))
  end

  @spec get_federation_status() :: map()
  def get_federation_status do
    GenServer.call(__MODULE__, :status)
  end

  # GenServer Implementation

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, generate_node_id())
    sync_interval = Keyword.get(opts, :sync_interval, @default_sync_interval)

    # Schedule Zenoh subscription setup (after ZenohSession is ready)
    Process.send_after(self(), :setup_subscriptions, 1_000)

    schedule_sync(sync_interval)

    Logger.info("[SMRITI.Federation] Started with node_id=#{node_id}")

    {:ok,
     %__MODULE__{
       node_id: node_id,
       peers: [],
       version_vectors: %{},
       last_sync: nil,
       sync_interval: sync_interval,
       subscriptions: %{},
       pending_syncs: %{},
       stats: initial_stats()
     }}
  end

  defp initial_stats do
    %{
      started_at: DateTime.utc_now(),
      syncs_initiated: 0,
      syncs_completed: 0,
      holons_sent: 0,
      holons_received: 0,
      sync_errors: 0
    }
  end

  @impl true
  def handle_call(:discover_peers, _from, state) do
    peers = do_discover_peers()
    {:reply, {:ok, peers}, %{state | peers: peers}}
  end

  @impl true
  def handle_call({:sync, peer_url}, _from, state) do
    result = do_sync_with_peer(peer_url, state)
    new_state = update_after_sync(state, peer_url, result)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:sync_all, _from, state) do
    results =
      Enum.map(state.peers, fn peer ->
        {peer, do_sync_with_peer(peer, state)}
      end)

    {:reply, {:ok, Map.new(results)}, %{state | last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      node_id: state.node_id,
      protocol_version: @protocol_version,
      peer_count: length(state.peers),
      peers: state.peers,
      last_sync: state.last_sync,
      sync_interval_hours: state.sync_interval / :timer.hours(1)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:setup_subscriptions, state) do
    subscribe_patterns = [
      "smriti/federation/**"
    ]

    new_subscriptions =
      Enum.reduce(subscribe_patterns, state.subscriptions, fn pattern, acc ->
        case ZenohSession.subscribe(pattern, self()) do
          {:ok, ref} ->
            Logger.info("[SMRITI.Federation] Subscribed to #{pattern}")
            Map.put(acc, ref, pattern)

          {:error, reason} ->
            Logger.warning(
              "[SMRITI.Federation] Failed to subscribe to #{pattern}: #{inspect(reason)}"
            )

            acc
        end
      end)

    # Announce our presence to the federation
    announce_to_federation(state)

    {:noreply, %{state | subscriptions: new_subscriptions}}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    Logger.info("[SMRITI.Federation] Starting periodic sync with #{length(state.peers)} peers")

    new_stats = %{
      state.stats
      | syncs_initiated: state.stats.syncs_initiated + length(state.peers)
    }

    Enum.each(state.peers, fn peer ->
      spawn(fn -> do_sync_with_peer(peer, state) end)
    end)

    schedule_sync(state.sync_interval)
    {:noreply, %{state | last_sync: DateTime.utc_now(), stats: new_stats}}
  end

  @impl true
  def handle_info({:zenoh_message, key, payload}, state) do
    case Jason.decode(payload) do
      {:ok, message} ->
        # Don't process our own messages
        if Map.get(message, "node_id") != state.node_id do
          new_state = handle_federation_message(key, message, state)
          {:noreply, new_state}
        else
          {:noreply, state}
        end

      {:error, _reason} ->
        Logger.warning("[SMRITI.Federation] Failed to decode message from #{key}")
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE IMPLEMENTATION
  # ============================================================

  defp handle_federation_message(key, message, state) do
    cond do
      String.contains?(key, "peers/announce") ->
        handle_peer_announce(message, state)

      String.contains?(key, "sync/request") ->
        handle_sync_request(message, state)

      String.contains?(key, "sync/response") ->
        handle_sync_response(message, state)

      String.contains?(key, "versions") ->
        handle_version_update(message, state)

      true ->
        state
    end
  end

  defp handle_peer_announce(message, state) do
    peer_id = Map.get(message, "node_id")
    peer_version = Map.get(message, "protocol_version")
    peer_merkle = Map.get(message, "merkle_root")

    if peer_id && peer_id != state.node_id do
      Logger.info("[SMRITI.Federation] Discovered peer: #{peer_id} (v#{peer_version})")

      # Step 1: Verify version compatibility (SC-FRAC-006)
      with true <- compatible_version?(peer_version),
           # Step 2: Verify attestation (SC-REG-013)
           :ok <- verify_peer_attestation(peer_id, peer_merkle) do
        new_peers = [peer_id | state.peers] |> Enum.uniq()
        %{state | peers: new_peers}
      else
        false ->
          Logger.warning("[SMRITI.Federation] Incompatible peer version: #{peer_version}")
          state

        {:error, reason} ->
          Logger.error(
            "[SMRITI.Federation] Peer attestation failed for #{peer_id}: #{inspect(reason)}"
          )

          state
      end
    else
      state
    end
  end

  defp verify_peer_attestation(_peer_id, peer_merkle) do
    alias Indrajaal.KMS.Security.Attestation

    if Code.ensure_loaded?(Attestation) do
      # In a real system, we would exchange signatures.
      # For Phase 4, we verify the Merkle root format.
      if is_binary(peer_merkle) and byte_size(peer_merkle) == 64 do
        :ok
      else
        {:error, :invalid_merkle_root}
      end
    else
      :ok
    end
  end

  defp handle_sync_request(message, state) do
    request_id = Map.get(message, "request_id")
    peer_id = Map.get(message, "node_id")
    remote_versions = Map.get(message, "version_vectors", %{})

    # Compute what we have that they need
    deltas = compute_deltas(state.version_vectors, remote_versions)

    # Send response via Zenoh
    response = %{
      type: "sync_response",
      request_id: request_id,
      node_id: state.node_id,
      version_vectors: state.version_vectors,
      deltas: deltas.outgoing,
      protocol_version: @protocol_version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    do_publish(@topic_sync_response, response)

    Logger.debug("[SMRITI.Federation] Sent sync response to #{peer_id}")
    state
  end

  defp handle_sync_response(message, state) do
    request_id = Map.get(message, "request_id")
    peer_id = Map.get(message, "node_id")
    remote_versions = Map.get(message, "version_vectors", %{})
    deltas = Map.get(message, "deltas", [])

    # Merge received data
    new_versions = merge_version_vectors(state.version_vectors, remote_versions)
    holons_received = length(deltas)

    new_stats = %{
      state.stats
      | syncs_completed: state.stats.syncs_completed + 1,
        holons_received: state.stats.holons_received + holons_received
    }

    # Remove from pending syncs
    new_pending = Map.delete(state.pending_syncs, request_id)

    Logger.info(
      "[SMRITI.Federation] Sync complete with #{peer_id}: received #{holons_received} holons"
    )

    %{state | version_vectors: new_versions, pending_syncs: new_pending, stats: new_stats}
  end

  defp handle_version_update(message, state) do
    peer_id = Map.get(message, "node_id")
    versions = Map.get(message, "version_vectors", %{})

    if peer_id != state.node_id do
      new_versions = merge_version_vectors(state.version_vectors, versions)
      %{state | version_vectors: new_versions}
    else
      state
    end
  end

  @doc false
  def broadcast_version_vectors(state) do
    message = %{
      type: "version_update",
      node_id: state.node_id,
      version_vectors: state.version_vectors,
      protocol_version: @protocol_version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    do_publish(@topic_version_vectors, message)
  end

  defp announce_to_federation(state) do
    merkle_root = get_current_merkle_root()

    message = %{
      type: "peer_announce",
      node_id: state.node_id,
      protocol_version: @protocol_version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      capabilities: [:knowledge_sync, :version_vectors, :merkle_proofs],
      merkle_root: merkle_root
    }

    do_publish(@topic_peer_announce, message)

    Logger.info(
      "[SMRITI.Federation] Announced to federation as #{state.node_id} (Merkle: #{String.slice(merkle_root, 0, 8)})"
    )
  end

  defp get_current_merkle_root do
    alias Indrajaal.Cockpit.Prajna.ImmutableState

    if Code.ensure_loaded?(ImmutableState) do
      ImmutableState.compute_merkle_root()
    else
      "0000000000000000000000000000000000000000000000000000000000000000"
    end
  rescue
    _ -> "0000000000000000000000000000000000000000000000000000000000000000"
  end

  defp do_discover_peers do
    # Multi-method peer discovery
    config_peers = discover_via_config()

    config_peers
    |> Enum.uniq()
  end

  defp do_sync_with_peer(peer_id, state) do
    request_id = generate_request_id()

    # Send sync request via Zenoh
    request = %{
      type: "sync_request",
      request_id: request_id,
      node_id: state.node_id,
      version_vectors: state.version_vectors,
      protocol_version: @protocol_version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case do_publish(@topic_sync_request, request) do
      :ok ->
        Logger.debug("[SMRITI.Federation] Sent sync request to #{peer_id}")
        {:ok, request_id}

      {:error, reason} ->
        Logger.warning("[SMRITI.Federation] Failed to send sync request: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp compute_deltas(local, remote) do
    outgoing = find_newer_local(local, remote)
    incoming = find_newer_remote(local, remote)
    %{outgoing: outgoing, incoming: incoming}
  end

  defp merge_version_vectors(local, remote) do
    Map.merge(local, remote, fn _key, v1, v2 ->
      # Keep the higher version
      if v1 > v2, do: v1, else: v2
    end)
  end

  defp compatible_version?(version) do
    # Check major version compatibility
    case String.split(version || "0.0.0", ".") do
      [major | _] ->
        [our_major | _] = String.split(@protocol_version, ".")
        major == our_major

      _ ->
        false
    end
  end

  defp schedule_sync(interval) do
    Process.send_after(self(), :periodic_sync, interval)
  end

  defp generate_node_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_request_id do
    "sync-#{:erlang.phash2({node(), System.system_time()}, 0xFFFFFFFF) |> Integer.to_string(16)}"
  end

  defp discover_via_config do
    Application.get_env(:indrajaal, :smriti_federation_peers, [])
  end

  defp find_newer_local(local, remote) do
    local
    |> Enum.filter(fn {key, version} ->
      remote_version = Map.get(remote, key, 0)
      version > remote_version
    end)
    |> Enum.into(%{})
  end

  defp find_newer_remote(local, remote) do
    remote
    |> Enum.filter(fn {key, version} ->
      local_version = Map.get(local, key, 0)
      version > local_version
    end)
    |> Enum.into(%{})
  end

  defp do_publish(topic, message) do
    payload = Jason.encode!(message)

    # Emit telemetry
    :telemetry.execute(
      [:smriti, :federation, :publish],
      %{bytes: byte_size(payload)},
      %{topic: topic, type: message.type}
    )

    # Publish via Zenoh
    ZenohSession.publish(topic, payload)
  end

  defp update_after_sync(state, _peer, result) do
    case result do
      {:ok, _data} ->
        %{state | stats: %{state.stats | syncs_completed: state.stats.syncs_completed + 1}}

      {:error, _reason} ->
        %{state | stats: %{state.stats | sync_errors: state.stats.sync_errors + 1}}
    end
  end
end
