defmodule Indrajaal.Distributed.Mesh.Gossip do
  @moduledoc """
  Gossip Protocol - Epidemic Information Dissemination for v20.0.0

  Implements SWIM-style gossip for membership and state propagation:
  - Probabilistic broadcast
  - Failure detection
  - State synchronization
  - Protocol multiplexing

  ## Gossip Model

  Information spreads like epidemic:
  - Infected nodes (have info) spread to susceptible nodes
  - Convergence in O(log N) rounds
  - Probabilistic guarantees

  ## Protocol Types
  - **Push**: Sender initiates
  - **Pull**: Receiver requests
  - **Push-Pull**: Bidirectional exchange

  ## STAMP Constraints
  - SC-GOS-001: Gossip MUST reach all nodes eventually
  - SC-GOS-002: Gossip round < 100ms
  - SC-GOS-003: Fan-out MUST be bounded (3-5 peers)
  - SC-GOS-004: State MUST converge within 10 rounds
  """

  use GenServer
  require Logger

  alias Indrajaal.Distributed.Mesh.Mycelium

  @type node_id :: String.t()
  @type gossip_type :: :membership | :state | :event
  @type protocol :: :push | :pull | :push_pull

  @type gossip_message :: %{
          id: String.t(),
          type: gossip_type(),
          origin: node_id(),
          payload: term(),
          version: non_neg_integer(),
          ttl: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @type state :: %{
          node_id: node_id(),
          membership: map(),
          state_vectors: map(),
          seen_messages: MapSet.t(),
          pending_acks: map(),
          config: map()
        }

  # Default fan-out (number of peers to gossip to)
  @default_fanout 3

  # Maximum TTL for messages
  @max_ttl 10

  # Gossip round interval (ms)
  @gossip_interval 1_000

  # Seen message retention
  @max_seen 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gossips a message to the network.
  """
  @spec gossip(gossip_type(), term()) :: :ok
  def gossip(type, payload) do
    GenServer.cast(__MODULE__, {:gossip, type, payload})
  end

  @doc """
  Gossips membership update.
  """
  @spec gossip_membership(map()) :: :ok
  def gossip_membership(update) do
    gossip(:membership, update)
  end

  @doc """
  Gossips state update.
  """
  @spec gossip_state(atom(), term(), non_neg_integer()) :: :ok
  def gossip_state(key, value, version) do
    gossip(:state, %{key: key, value: value, version: version})
  end

  @doc """
  Gossips event to network.
  """
  @spec gossip_event(term()) :: :ok
  def gossip_event(event) do
    gossip(:event, event)
  end

  @doc """
  Gets current membership view.
  """
  @spec membership() :: map()
  def membership do
    GenServer.call(__MODULE__, :membership)
  end

  @doc """
  Gets state vector for a key.
  """
  @spec get_state(atom()) :: {:ok, term(), non_neg_integer()} | {:error, :not_found}
  def get_state(key) do
    GenServer.call(__MODULE__, {:get_state, key})
  end

  @doc """
  Forces a sync with a specific peer.
  """
  @spec sync_with(node_id()) :: :ok | {:error, term()}
  def sync_with(peer_id) do
    GenServer.call(__MODULE__, {:sync_with, peer_id})
  end

  @doc """
  Gets gossip statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, generate_id())

    state = %{
      node_id: node_id,
      membership: %{},
      state_vectors: %{},
      seen_messages: MapSet.new(),
      pending_acks: %{},
      stats: %{
        messages_sent: 0,
        messages_received: 0,
        rounds_completed: 0
      },
      config: %{
        fanout: Keyword.get(opts, :fanout, @default_fanout),
        gossip_interval: Keyword.get(opts, :gossip_interval, @gossip_interval),
        protocol: Keyword.get(opts, :protocol, :push_pull)
      }
    }

    # Start gossip rounds
    Process.send_after(self(), :gossip_round, state.config.gossip_interval)

    Logger.info("📣 Gossip protocol started for #{node_id}")

    {:ok, state}
  end

  @impl true
  def handle_cast({:gossip, type, payload}, state) do
    message = create_message(type, payload, state)
    new_state = do_gossip(message, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:membership, _from, state) do
    {:reply, state.membership, state}
  end

  @impl true
  def handle_call({:get_state, key}, _from, state) do
    case Map.get(state.state_vectors, key) do
      nil -> {:reply, {:error, :not_found}, state}
      {value, version} -> {:reply, {:ok, value, version}, state}
    end
  end

  @impl true
  def handle_call({:sync_with, peer_id}, _from, state) do
    # Send pull request to peer
    pull_message = %{
      type: :pull_request,
      from: state.node_id,
      state_summary: summarize_state(state)
    }

    case Mycelium.send_message(peer_id, {:gossip, pull_message}) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        seen_messages: MapSet.size(state.seen_messages),
        state_keys: map_size(state.state_vectors),
        membership_size: map_size(state.membership)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:gossip_round, state) do
    # Select random peers
    peers = select_gossip_peers(state)

    # Perform gossip based on protocol
    new_state =
      case state.config.protocol do
        :push ->
          push_gossip(peers, state)

        :pull ->
          pull_gossip(peers, state)

        :push_pull ->
          push_pull_gossip(peers, state)
      end

    # Update stats
    updated_stats = %{new_state.stats | rounds_completed: new_state.stats.rounds_completed + 1}

    # Schedule next round
    Process.send_after(self(), :gossip_round, state.config.gossip_interval)

    {:noreply, %{new_state | stats: updated_stats}}
  end

  @impl true
  def handle_info({:gossip, message}, state) do
    new_state = handle_gossip_message(message, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:pull_request, from, summary}, state) do
    # Respond with delta
    delta = compute_delta(state, summary)

    if not Enum.empty?(delta) do
      Mycelium.send_message(from, {:gossip_response, state.node_id, delta})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:gossip_response, _from, delta}, state) do
    # Merge received delta
    new_state = merge_delta(state, delta)
    {:noreply, new_state}
  end

  # Private helpers

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  defp create_message(type, payload, state) do
    %{
      id: generate_id(),
      type: type,
      origin: state.node_id,
      payload: payload,
      version: System.monotonic_time(),
      ttl: @max_ttl,
      timestamp: DateTime.utc_now()
    }
  end

  defp do_gossip(message, state) do
    # Mark as seen
    new_seen = add_to_seen(state.seen_messages, message.id)

    # Select peers and send
    peers = select_gossip_peers(state)

    Enum.each(peers, fn peer_id ->
      Mycelium.send_message(peer_id, {:gossip, message})
    end)

    # Update stats
    new_stats = %{state.stats | messages_sent: state.stats.messages_sent + length(peers)}

    %{state | seen_messages: new_seen, stats: new_stats}
  end

  defp handle_gossip_message(message, state) do
    if MapSet.member?(state.seen_messages, message.id) do
      state
    else
      new_state = process_gossip(message, state)
      new_seen = add_to_seen(new_state.seen_messages, message.id)

      new_state =
        if message.ttl > 1 do
          forward_gossip_message(message, new_state)
        else
          new_state
        end

      new_stats = %{new_state.stats | messages_received: new_state.stats.messages_received + 1}

      %{new_state | seen_messages: new_seen, stats: new_stats}
    end
  end

  defp forward_gossip_message(message, state) do
    forwarded = %{message | ttl: message.ttl - 1}
    peers = select_gossip_peers(state)

    peers
    |> Enum.filter(&(&1 != message.origin))
    |> Enum.each(&Mycelium.send_message(&1, {:gossip, forwarded}))

    state
  end

  defp process_gossip(message, state) do
    case message.type do
      :membership ->
        merge_membership(state, message.payload)

      :state ->
        merge_state_update(state, message.payload)

      :event ->
        handle_event(state, message.payload)

      _ ->
        state
    end
  end

  defp merge_membership(state, update) do
    # Merge membership with conflict resolution (latest wins)
    new_membership =
      Map.merge(state.membership, update, fn _key, existing, incoming ->
        if incoming.timestamp > existing.timestamp, do: incoming, else: existing
      end)

    %{state | membership: new_membership}
  end

  defp merge_state_update(state, %{key: key, value: value, version: version}) do
    case Map.get(state.state_vectors, key) do
      nil ->
        new_vectors = Map.put(state.state_vectors, key, {value, version})
        %{state | state_vectors: new_vectors}

      {_, existing_version} when version > existing_version ->
        new_vectors = Map.put(state.state_vectors, key, {value, version})
        %{state | state_vectors: new_vectors}

      _ ->
        state
    end
  end

  defp handle_event(state, _event) do
    # Process event - could trigger local handlers
    state
  end

  defp select_gossip_peers(state) do
    # Get alive nodes from Mycelium
    nodes = Mycelium.nodes()

    # Select random subset
    nodes
    |> Enum.filter(&(&1.status == :alive))
    |> Enum.map(& &1.id)
    |> Enum.take_random(state.config.fanout)
  end

  defp push_gossip(peers, state) do
    # Send current state digest to peers
    digest = state_digest(state)

    Enum.each(peers, fn peer_id ->
      Mycelium.send_message(peer_id, {:gossip, digest})
    end)

    state
  end

  defp pull_gossip(peers, state) do
    # Request state from peers
    summary = summarize_state(state)

    Enum.each(peers, fn peer_id ->
      Mycelium.send_message(peer_id, {:pull_request, state.node_id, summary})
    end)

    state
  end

  defp push_pull_gossip(peers, state) do
    # Both push and pull
    state
    |> push_gossip(peers)
    |> pull_gossip(peers)
  end

  defp state_digest(state) do
    %{
      id: generate_id(),
      type: :state,
      origin: state.node_id,
      payload: %{
        membership: state.membership,
        state_versions: Enum.into(state.state_vectors, %{}, fn {k, {_, v}} -> {k, v} end)
      },
      version: System.monotonic_time(),
      ttl: 1,
      timestamp: DateTime.utc_now()
    }
  end

  defp summarize_state(state) do
    %{
      membership_keys: Map.keys(state.membership),
      state_versions: Enum.into(state.state_vectors, %{}, fn {k, {_, v}} -> {k, v} end)
    }
  end

  defp compute_delta(state, summary) do
    # Find state we have that peer doesn't
    state.state_vectors
    |> Enum.filter(fn {key, {_, version}} ->
      peer_version = Map.get(summary.state_versions, key, 0)
      version > peer_version
    end)
    |> Enum.into(%{})
  end

  defp merge_delta(state, delta) do
    new_vectors =
      Enum.reduce(delta, state.state_vectors, fn {key, {value, version}}, acc ->
        case Map.get(acc, key) do
          nil -> Map.put(acc, key, {value, version})
          {_, existing_v} when version > existing_v -> Map.put(acc, key, {value, version})
          _ -> acc
        end
      end)

    %{state | state_vectors: new_vectors}
  end

  defp add_to_seen(seen, message_id) do
    new_seen = MapSet.put(seen, message_id)

    # Limit size
    if MapSet.size(new_seen) > @max_seen do
      new_seen
      |> MapSet.to_list()
      |> Enum.take(@max_seen - 1000)
      |> MapSet.new()
    else
      new_seen
    end
  end
end
