# lib/indrajaal/kms/federation/protocol.ex
defmodule Indrajaal.KMS.Federation.Protocol do
  @moduledoc """
  Gossip-based federation protocol for L6/L7 peer discovery and state sync.

  WHAT: Implements a gossip protocol for federation peer management.
  Peers exchange version vectors and capability lists to maintain
  an eventually-consistent view of the federation mesh.

  WHY: L6 cluster coordination requires peers to discover each other
  and agree on protocol versions (SC-FRAC-006). Gossip provides
  partition-tolerant peer management.

  CONSTRAINTS:
  - SC-SMRITI-063: Federation protocol implementation
  - SC-FRAC-006: Version negotiation for AI protocols
  - SC-REG-010: Protocol version negotiation before communication
  - SC-DBCROSS-004: Cross-holon timeout < 100ms

  TECHNIQUES:
  | Technique | Purpose |
  |-----------|---------|
  | Gossip Protocol | Partition-tolerant peer discovery |
  | Version Vectors | Conflict-free state synchronization |
  | Capability Negotiation | Protocol version agreement |
  """
  use GenServer
  require Logger

  alias Indrajaal.KMS.Federation.VersionVectors

  @gossip_interval_ms 30_000
  @peer_timeout_ms 90_000
  @protocol_version "21.2.1"

  @type peer :: %{
          id: String.t(),
          endpoint: String.t(),
          version: String.t(),
          capabilities: [atom()],
          last_seen: integer(),
          status: :active | :suspect | :dead
        }

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the list of known federation peers."
  def get_peers do
    GenServer.call(__MODULE__, :get_peers)
  end

  @doc "Returns only active peers."
  def get_active_peers do
    GenServer.call(__MODULE__, :get_active_peers)
  end

  @doc "Registers a new federation peer."
  def register_peer(peer_id, endpoint, opts \\ []) do
    GenServer.call(__MODULE__, {:register_peer, peer_id, endpoint, opts})
  end

  @doc "Removes a peer from the federation."
  def remove_peer(peer_id) do
    GenServer.call(__MODULE__, {:remove_peer, peer_id})
  end

  @doc "Processes an incoming gossip message from a peer."
  def receive_gossip(from_peer_id, gossip_payload) do
    GenServer.cast(__MODULE__, {:gossip_received, from_peer_id, gossip_payload})
  end

  @doc "Returns the local node's gossip state for exchange."
  def get_gossip_state do
    GenServer.call(__MODULE__, :get_gossip_state)
  end

  # ---------------------------------------------------------------------------
  # Server Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, node_id())
    schedule_gossip()

    {:ok,
     %{
       node_id: node_id,
       peers: %{},
       version_vector: VersionVectors.new(node_id),
       protocol_version: @protocol_version,
       capabilities: [:fpps_consensus, :merkle_verify, :version_vectors]
     }}
  end

  @impl true
  def handle_call(:get_peers, _from, state) do
    peers = Map.values(state.peers)
    {:reply, peers, state}
  end

  @impl true
  def handle_call(:get_active_peers, _from, state) do
    now = System.monotonic_time(:millisecond)

    active =
      state.peers
      |> Map.values()
      |> Enum.filter(fn peer ->
        peer.status == :active and now - peer.last_seen < @peer_timeout_ms
      end)

    {:reply, active, state}
  end

  @impl true
  def handle_call({:register_peer, peer_id, endpoint, opts}, _from, state) do
    version = Keyword.get(opts, :version, @protocol_version)
    capabilities = Keyword.get(opts, :capabilities, [])

    case negotiate_version(version) do
      :ok ->
        peer = %{
          id: peer_id,
          endpoint: endpoint,
          version: version,
          capabilities: capabilities,
          last_seen: System.monotonic_time(:millisecond),
          status: :active
        }

        new_peers = Map.put(state.peers, peer_id, peer)

        new_vv =
          VersionVectors.increment(state.version_vector, state.node_id)

        Logger.debug("[Federation.Protocol] Registered peer #{peer_id} at #{endpoint}")
        {:reply, {:ok, peer}, %{state | peers: new_peers, version_vector: new_vv}}

      {:error, reason} ->
        Logger.warning("[Federation.Protocol] Rejected peer #{peer_id}: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:remove_peer, peer_id}, _from, state) do
    new_peers = Map.delete(state.peers, peer_id)
    Logger.debug("[Federation.Protocol] Removed peer #{peer_id}")
    {:reply, :ok, %{state | peers: new_peers}}
  end

  @impl true
  def handle_call(:get_gossip_state, _from, state) do
    gossip = %{
      node_id: state.node_id,
      protocol_version: state.protocol_version,
      capabilities: state.capabilities,
      peer_count: map_size(state.peers),
      version_vector: state.version_vector
    }

    {:reply, gossip, state}
  end

  @impl true
  def handle_cast({:gossip_received, from_peer_id, payload}, state) do
    now = System.monotonic_time(:millisecond)

    # Update the sending peer's last_seen timestamp
    updated_peers =
      Map.update(state.peers, from_peer_id, nil, fn
        nil -> nil
        peer -> %{peer | last_seen: now, status: :active}
      end)

    # Merge version vectors if provided
    new_vv =
      case Map.get(payload, :version_vector) do
        nil ->
          state.version_vector

        remote_vv ->
          VersionVectors.merge(state.version_vector, remote_vv)
      end

    # Merge any new peers from the gossip payload
    merged_peers =
      case Map.get(payload, :known_peers, []) do
        [] ->
          updated_peers

        remote_peers ->
          Enum.reduce(remote_peers, updated_peers, fn remote_peer, acc ->
            peer_id = remote_peer.id

            if Map.has_key?(acc, peer_id) do
              acc
            else
              Map.put(acc, peer_id, %{remote_peer | status: :suspect, last_seen: now})
            end
          end)
      end

    {:noreply, %{state | peers: merged_peers, version_vector: new_vv}}
  end

  @impl true
  def handle_info(:gossip_tick, state) do
    state = expire_dead_peers(state)
    schedule_gossip()
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private: version negotiation (SC-FRAC-006, SC-REG-010)
  # ---------------------------------------------------------------------------

  defp negotiate_version(remote_version) do
    local_parts = String.split(@protocol_version, ".")
    remote_parts = String.split(remote_version, ".")

    case {local_parts, remote_parts} do
      {[lmaj | _], [rmaj | _]} when lmaj == rmaj ->
        :ok

      _ ->
        {:error, :incompatible_major_version}
    end
  rescue
    _ -> {:error, :invalid_version_format}
  end

  # ---------------------------------------------------------------------------
  # Private: peer lifecycle
  # ---------------------------------------------------------------------------

  defp expire_dead_peers(state) do
    now = System.monotonic_time(:millisecond)

    updated_peers =
      state.peers
      |> Enum.map(fn {id, peer} ->
        age = now - peer.last_seen

        cond do
          age > @peer_timeout_ms -> {id, %{peer | status: :dead}}
          age > @peer_timeout_ms * 2 / 3 -> {id, %{peer | status: :suspect}}
          true -> {id, peer}
        end
      end)
      |> Enum.reject(fn {_id, peer} ->
        # Remove peers that have been dead for 3x the timeout
        peer.status == :dead and
          System.monotonic_time(:millisecond) - peer.last_seen > @peer_timeout_ms * 3
      end)
      |> Map.new()

    %{state | peers: updated_peers}
  end

  defp schedule_gossip do
    Process.send_after(self(), :gossip_tick, @gossip_interval_ms)
  end

  defp node_id do
    "#{node()}"
  end
end
