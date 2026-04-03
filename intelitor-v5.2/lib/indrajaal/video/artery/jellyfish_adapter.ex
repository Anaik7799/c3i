defmodule Indrajaal.Video.Artery.JellyfishAdapter do
  @moduledoc """
  Jellyfish SFU (Selective Forwarding Unit) adapter for symmetric NAT fallback.

  Provides integration with Jellyfish media server when P2P WebRTC
  connections fail due to symmetric NAT or firewall restrictions.

  ## STAMP Constraints

  - SC-ARTERY-002: P2P preferred, SFU fallback
  - SC-ARTERY-003: Jellyfish SFU only when P2P fails

  ## Architecture

  ```
  P2P FAILS                    SFU FALLBACK
  ├─ Symmetric NAT             ├─ Jellyfish server
  ├─ Firewall blocks           ├─ Room per stream
  ├─ ICE timeout               ├─ Peer tokens
  └─ Trigger fallback          └─ Relay via SFU
  ```

  ## Usage

      config = %{server_url: "http://jellyfish:5002", api_key: "key"}
      {:ok, adapter} = JellyfishAdapter.start_link(config: config)

      # Create room for stream
      {:ok, room} = JellyfishAdapter.create_room(adapter, "stream-1")

      # Add peers to room
      {:ok, peer} = JellyfishAdapter.add_peer(adapter, "stream-1", "peer-1")

      # Get SFU endpoint for WebSocket connection
      endpoint = JellyfishAdapter.get_sfu_endpoint(adapter, peer.token)

  """

  use GenServer
  require Logger

  @type stream_id :: String.t()
  @type peer_id :: String.t()

  @type config :: %{
          server_url: String.t(),
          api_key: String.t()
        }

  @type room :: %{
          room_id: String.t(),
          stream_id: stream_id(),
          created_at: DateTime.t()
        }

  @type peer :: %{
          peer_id: peer_id(),
          token: String.t(),
          joined_at: DateTime.t()
        }

  # ============================================================================
  # CLIENT API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    config = Keyword.fetch!(opts, :config)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, config, gen_opts)
  end

  @doc """
  Creates a room for stream relay via SFU.
  """
  @spec create_room(GenServer.server(), stream_id()) :: {:ok, room()}
  def create_room(server, stream_id) do
    GenServer.call(server, {:create_room, stream_id})
  end

  @doc """
  Adds a peer to a room.
  """
  @spec add_peer(GenServer.server(), stream_id(), peer_id()) ::
          {:ok, peer()} | {:error, :room_not_found}
  def add_peer(server, stream_id, peer_id) do
    GenServer.call(server, {:add_peer, stream_id, peer_id})
  end

  @doc """
  Removes a peer from a room.
  """
  @spec remove_peer(GenServer.server(), stream_id(), peer_id()) :: :ok
  def remove_peer(server, stream_id, peer_id) do
    GenServer.call(server, {:remove_peer, stream_id, peer_id})
  end

  @doc """
  Gets all peers in a room.
  """
  @spec get_peers(GenServer.server(), stream_id()) :: [peer()]
  def get_peers(server, stream_id) do
    GenServer.call(server, {:get_peers, stream_id})
  end

  @doc """
  Lists all active rooms.
  """
  @spec list_rooms(GenServer.server()) :: [room()]
  def list_rooms(server) do
    GenServer.call(server, :list_rooms)
  end

  @doc """
  Destroys a room and removes all peers.
  """
  @spec destroy_room(GenServer.server(), stream_id()) :: :ok
  def destroy_room(server, stream_id) do
    GenServer.call(server, {:destroy_room, stream_id})
  end

  @doc """
  Gets the SFU WebSocket endpoint for a peer token.
  """
  @spec get_sfu_endpoint(GenServer.server(), String.t()) :: String.t()
  def get_sfu_endpoint(server, token) do
    GenServer.call(server, {:get_sfu_endpoint, token})
  end

  @doc """
  Returns adapter metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server) do
    GenServer.call(server, :metrics)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(config) do
    state = %{
      config: config,
      rooms: %{},
      metrics: %{
        rooms_created: 0,
        peers_added: 0,
        rooms_destroyed: 0
      },
      started_at: DateTime.utc_now()
    }

    Logger.info("[JellyfishAdapter] Started with server: #{config.server_url}")

    {:ok, state}
  end

  @impl true
  def handle_call({:create_room, stream_id}, _from, state) do
    case Map.get(state.rooms, stream_id) do
      nil ->
        room = %{
          room_id: "room-#{generate_id()}",
          stream_id: stream_id,
          peers: %{},
          created_at: DateTime.utc_now()
        }

        new_rooms = Map.put(state.rooms, stream_id, room)
        new_metrics = %{state.metrics | rooms_created: state.metrics.rooms_created + 1}

        Logger.info("[JellyfishAdapter] Created room: #{room.room_id} for stream: #{stream_id}")

        {:reply, {:ok, room}, %{state | rooms: new_rooms, metrics: new_metrics}}

      existing_room ->
        {:reply, {:ok, existing_room}, state}
    end
  end

  @impl true
  def handle_call({:add_peer, stream_id, peer_id}, _from, state) do
    case Map.get(state.rooms, stream_id) do
      nil ->
        {:reply, {:error, :room_not_found}, state}

      room ->
        peer = %{
          peer_id: peer_id,
          token: generate_peer_token(),
          joined_at: DateTime.utc_now()
        }

        updated_peers = Map.put(room.peers, peer_id, peer)
        updated_room = %{room | peers: updated_peers}
        new_rooms = Map.put(state.rooms, stream_id, updated_room)
        new_metrics = %{state.metrics | peers_added: state.metrics.peers_added + 1}

        Logger.debug("[JellyfishAdapter] Added peer: #{peer_id} to room: #{room.room_id}")

        {:reply, {:ok, peer}, %{state | rooms: new_rooms, metrics: new_metrics}}
    end
  end

  @impl true
  def handle_call({:remove_peer, stream_id, peer_id}, _from, state) do
    case Map.get(state.rooms, stream_id) do
      nil ->
        {:reply, :ok, state}

      room ->
        updated_peers = Map.delete(room.peers, peer_id)
        updated_room = %{room | peers: updated_peers}
        new_rooms = Map.put(state.rooms, stream_id, updated_room)

        Logger.debug("[JellyfishAdapter] Removed peer: #{peer_id} from room: #{room.room_id}")

        {:reply, :ok, %{state | rooms: new_rooms}}
    end
  end

  @impl true
  def handle_call({:get_peers, stream_id}, _from, state) do
    case Map.get(state.rooms, stream_id) do
      nil ->
        {:reply, [], state}

      room ->
        peers = Map.values(room.peers)
        {:reply, peers, state}
    end
  end

  @impl true
  def handle_call(:list_rooms, _from, state) do
    rooms =
      state.rooms
      |> Map.values()
      |> Enum.map(fn room ->
        %{room_id: room.room_id, stream_id: room.stream_id, created_at: room.created_at}
      end)

    {:reply, rooms, state}
  end

  @impl true
  def handle_call({:destroy_room, stream_id}, _from, state) do
    new_rooms = Map.delete(state.rooms, stream_id)
    new_metrics = %{state.metrics | rooms_destroyed: state.metrics.rooms_destroyed + 1}

    Logger.info("[JellyfishAdapter] Destroyed room for stream: #{stream_id}")

    {:reply, :ok, %{state | rooms: new_rooms, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:get_sfu_endpoint, token}, _from, state) do
    # Convert HTTP URL to WebSocket URL
    ws_url =
      state.config.server_url
      |> String.replace("http://", "ws://")
      |> String.replace("https://", "wss://")

    endpoint = "#{ws_url}/socket/peer/websocket?token=#{token}"
    {:reply, endpoint, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    total_peers =
      state.rooms
      |> Map.values()
      |> Enum.map(fn room -> map_size(room.peers) end)
      |> Enum.sum()

    metrics = %{
      active_rooms: map_size(state.rooms),
      total_peers: total_peers,
      rooms_created: state.metrics.rooms_created,
      peers_added: state.metrics.peers_added,
      rooms_destroyed: state.metrics.rooms_destroyed,
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp generate_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    rand_bytes |> Base.encode16(case: :lower)
  end

  defp generate_peer_token do
    rand_bytes = :crypto.strong_rand_bytes(32)
    rand_bytes |> Base.url_encode64(padding: false)
  end
end
