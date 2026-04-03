defmodule Indrajaal.Distributed.Mesh.Mycelium do
  @moduledoc """
  Mycelial Mesh Network - Distributed Communication Core for v20.0.0

  Implements a bio-inspired mesh network based on mycelium (fungal networks):
  - Self-organizing topology
  - Redundant pathways
  - Resource sharing
  - Adaptive routing

  ## Mycelium Model

  Network as living organism:
  - Nodes = Hyphal tips (growing points)
  - Edges = Hyphae (nutrient channels)
  - Clusters = Fungal bodies

  ## Network Properties
  - **Resilient**: Multiple paths between any two nodes
  - **Adaptive**: Network topology changes with demand
  - **Efficient**: Shortest-path routing with caching
  - **Self-healing**: Automatic reconnection on failure

  ## STAMP Constraints
  - SC-MYC-001: Network MUST maintain connectivity
  - SC-MYC-002: Partition detection < 5s
  - SC-MYC-003: Message delivery MUST be reliable
  - SC-MYC-004: Network state MUST be eventually consistent
  """

  use GenServer
  require Logger

  # Reserved for future integration
  # alias Indrajaal.Distributed.Mesh.{Gossip, Discovery, Routing}

  @type node_id :: String.t()
  @type node_info :: %{
          id: node_id(),
          address: String.t(),
          port: non_neg_integer(),
          status: :alive | :suspected | :dead,
          last_seen: DateTime.t(),
          metadata: map()
        }

  @type connection :: %{
          from: node_id(),
          to: node_id(),
          latency_ms: non_neg_integer(),
          bandwidth: non_neg_integer(),
          established: DateTime.t()
        }

  @type mesh_state :: %{
          self_id: node_id(),
          nodes: map(),
          connections: [connection()],
          topology: map(),
          config: map()
        }

  # Heartbeat interval (ms)
  @heartbeat_interval 5_000

  # Node timeout (ms)
  @node_timeout 15_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Joins the mesh network.
  """
  @spec join(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def join(seed_address, seed_port) do
    GenServer.call(__MODULE__, {:join, seed_address, seed_port})
  end

  @doc """
  Leaves the mesh network.
  """
  @spec leave() :: :ok
  def leave do
    GenServer.call(__MODULE__, :leave)
  end

  @doc """
  Gets list of known nodes.
  """
  @spec nodes() :: [node_info()]
  def nodes do
    GenServer.call(__MODULE__, :nodes)
  end

  @doc """
  Gets node info by ID.
  """
  @spec get_node(node_id()) :: {:ok, node_info()} | {:error, :not_found}
  def get_node(node_id) do
    GenServer.call(__MODULE__, {:get_node, node_id})
  end

  @doc """
  Sends a message to a node.
  """
  @spec send_message(node_id(), term()) :: :ok | {:error, term()}
  def send_message(target, message) do
    GenServer.call(__MODULE__, {:send_message, target, message})
  end

  @doc """
  Broadcasts a message to all nodes.
  """
  @spec broadcast(term()) :: :ok
  def broadcast(message) do
    GenServer.cast(__MODULE__, {:broadcast, message})
  end

  @doc """
  Gets mesh topology.
  """
  @spec topology() :: map()
  def topology do
    GenServer.call(__MODULE__, :topology)
  end

  @doc """
  Gets mesh statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Registers a message handler.
  """
  @spec register_handler(atom(), function()) :: :ok
  def register_handler(message_type, handler) do
    GenServer.cast(__MODULE__, {:register_handler, message_type, handler})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    self_id = Keyword.get(opts, :node_id, generate_node_id())

    state = %{
      self_id: self_id,
      nodes: %{},
      connections: [],
      topology: %{},
      handlers: %{},
      config: %{
        heartbeat_interval: Keyword.get(opts, :heartbeat_interval, @heartbeat_interval),
        node_timeout: Keyword.get(opts, :node_timeout, @node_timeout),
        max_connections: Keyword.get(opts, :max_connections, 10)
      }
    }

    # Start heartbeat
    Process.send_after(self(), :heartbeat, state.config.heartbeat_interval)

    Logger.info("🍄 Mycelium node #{self_id} initialized")

    {:ok, state}
  end

  @impl true
  def handle_call({:join, seed_address, seed_port}, _from, state) do
    # Connect to seed node
    case connect_to_seed(seed_address, seed_port, state) do
      {:ok, seed_info} ->
        # Add seed to known nodes
        new_nodes = Map.put(state.nodes, seed_info.id, seed_info)

        # Request peer list from seed
        send(self(), {:request_peers, seed_info.id})

        Logger.info("Joined mesh via seed #{seed_info.id}")
        {:reply, :ok, %{state | nodes: new_nodes}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:leave, _from, state) do
    # Notify peers of departure
    Enum.each(state.nodes, fn {node_id, _} ->
      send_to_node(node_id, {:node_leaving, state.self_id}, state)
    end)

    Logger.info("Leaving mesh network")
    {:reply, :ok, %{state | nodes: %{}, connections: []}}
  end

  @impl true
  def handle_call(:nodes, _from, state) do
    nodes = Map.values(state.nodes)
    {:reply, nodes, state}
  end

  @impl true
  def handle_call({:get_node, node_id}, _from, state) do
    case Map.get(state.nodes, node_id) do
      nil -> {:reply, {:error, :not_found}, state}
      node -> {:reply, {:ok, node}, state}
    end
  end

  @impl true
  def handle_call({:send_message, target, message}, _from, state) do
    case send_to_node(target, message, state) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:topology, _from, state) do
    topology = build_topology(state)
    {:reply, topology, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      self_id: state.self_id,
      num_nodes: map_size(state.nodes),
      num_connections: length(state.connections),
      alive_nodes: count_by_status(state.nodes, :alive),
      suspected_nodes: count_by_status(state.nodes, :suspected),
      dead_nodes: count_by_status(state.nodes, :dead)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:broadcast, message}, state) do
    # Broadcast to all alive nodes
    Enum.each(state.nodes, fn {node_id, node} ->
      if node.status == :alive do
        send_to_node(node_id, {:broadcast, state.self_id, message}, state)
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:register_handler, message_type, handler}, state) do
    new_handlers = Map.put(state.handlers, message_type, handler)
    {:noreply, %{state | handlers: new_handlers}}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    # Send heartbeat to all nodes
    now = DateTime.utc_now()

    new_nodes =
      Enum.into(state.nodes, %{}, fn {node_id, node} ->
        # Check for timeout
        age = DateTime.diff(now, node.last_seen, :millisecond)

        new_status =
          cond do
            age > state.config.node_timeout * 2 -> :dead
            age > state.config.node_timeout -> :suspected
            true -> :alive
          end

        # Send heartbeat to alive/suspected nodes
        if new_status != :dead do
          send_to_node(node_id, {:heartbeat, state.self_id, now}, state)
        end

        {node_id, %{node | status: new_status}}
      end)

    # Remove dead nodes after grace period
    rejected_nodes =
      Enum.reject(new_nodes, fn {_, node} ->
        node.status == :dead
      end)

    cleaned_nodes = Map.new(rejected_nodes)

    # Schedule next heartbeat
    Process.send_after(self(), :heartbeat, state.config.heartbeat_interval)

    {:noreply, %{state | nodes: cleaned_nodes}}
  end

  @impl true
  def handle_info({:heartbeat, from_id, timestamp}, state) do
    # Update last_seen for the sender
    case Map.get(state.nodes, from_id) do
      nil ->
        # Unknown node, request info
        {:noreply, state}

      node ->
        updated = %{node | last_seen: timestamp, status: :alive}
        new_nodes = Map.put(state.nodes, from_id, updated)
        {:noreply, %{state | nodes: new_nodes}}
    end
  end

  @impl true
  def handle_info({:request_peers, _from_id}, state) do
    # Would request and integrate peers from the sender
    {:noreply, state}
  end

  @impl true
  def handle_info({:node_leaving, node_id}, state) do
    Logger.info("Node #{node_id} is leaving the mesh")
    new_nodes = Map.delete(state.nodes, node_id)
    {:noreply, %{state | nodes: new_nodes}}
  end

  @impl true
  def handle_info({:message, from_id, message_type, payload}, state) do
    # Dispatch to registered handler
    case Map.get(state.handlers, message_type) do
      nil ->
        Logger.debug("No handler for message type: #{message_type}")

      handler ->
        try do
          handler.(from_id, payload)
        rescue
          e -> Logger.error("Handler error: #{inspect(e)}")
        end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:broadcast, from_id, message}, state) do
    # Handle broadcast (could deduplicate and re-broadcast)
    Logger.debug("Broadcast from #{from_id}: #{inspect(message)}")
    {:noreply, state}
  end

  # Private helpers

  defp generate_node_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    hex_string = Base.encode16(random_bytes, case: :lower)
    "node_#{hex_string}"
  end

  defp connect_to_seed(address, port, _state) do
    # Simulated connection - in production would establish TCP/UDP
    # Add validation to potentially return error
    if is_binary(address) and is_integer(port) and port > 0 do
      seed_info = %{
        id: "seed_#{address}_#{port}",
        address: address,
        port: port,
        status: :alive,
        last_seen: DateTime.utc_now(),
        metadata: %{}
      }

      {:ok, seed_info}
    else
      {:error, :invalid_seed_address}
    end
  end

  defp send_to_node(node_id, message, state) do
    case Map.get(state.nodes, node_id) do
      nil ->
        {:error, :unknown_node}

      node ->
        if node.status == :alive do
          # Simulated send - in production would use actual network
          Logger.debug("Sending to #{node_id}: #{inspect(message)}")
          :ok
        else
          {:error, :node_not_alive}
        end
    end
  end

  defp build_topology(state) do
    nodes =
      Enum.map(state.nodes, fn {id, node} ->
        %{id: id, status: node.status}
      end)

    %{
      self: state.self_id,
      nodes: nodes,
      connections: state.connections
    }
  end

  defp count_by_status(nodes, status) do
    nodes
    |> Map.values()
    |> Enum.count(&(&1.status == status))
  end
end
