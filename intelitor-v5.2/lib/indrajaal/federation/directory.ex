defmodule Indrajaal.Federation.Directory do
  @moduledoc """
  Federation Directory - Node Registry for v20.0.0

  Maintains the directory of all known Jain nodes:
  - Active members
  - Historical records
  - Node metadata
  - Network topology

  ## Directory Model

  The directory tracks:
  1. Node identity (ID, constitution hash)
  2. Network endpoints
  3. Membership status
  4. Health metrics
  5. Lineage information

  ## Storage
  - In-memory for active lookups
  - Persistent for history
  - Distributed for redundancy

  ## STAMP Constraints
  - SC-DIR-001: Directory MUST be eventually consistent
  - SC-DIR-002: Lookups MUST complete in < 10ms
  - SC-DIR-003: Updates MUST be atomic
  - SC-DIR-004: History MUST be immutable
  """

  use GenServer
  require Logger

  @type node_entry :: %{
          id: String.t(),
          constitution_hash: binary(),
          generation: non_neg_integer(),
          parent_id: String.t() | nil,
          endpoints: [endpoint()],
          membership: map(),
          health: map(),
          metadata: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type endpoint :: %{
          protocol: :tcp | :udp | :ws,
          host: String.t(),
          port: non_neg_integer()
        }

  @type query :: %{
          state: atom() | nil,
          generation: non_neg_integer() | nil,
          parent_id: String.t() | nil,
          limit: non_neg_integer()
        }

  # Maximum entries in history
  @max_history 10_000

  # --- Client API ---

  @doc """
  Starts the directory service.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a new node in the directory.
  """
  @spec register(node_entry()) :: :ok | {:error, term()}
  def register(entry) do
    GenServer.call(__MODULE__, {:register, entry})
  end

  @doc """
  Updates an existing node entry.
  """
  @spec update(String.t(), map()) :: :ok | {:error, term()}
  def update(node_id, updates) do
    GenServer.call(__MODULE__, {:update, node_id, updates})
  end

  @doc """
  Gets a node by ID.
  """
  @spec get_node(String.t()) :: {:ok, node_entry()} | {:error, :not_found}
  def get_node(node_id) do
    GenServer.call(__MODULE__, {:get_node, node_id})
  end

  @doc """
  Lists all nodes.
  """
  @spec list_nodes() :: [node_entry()]
  def list_nodes do
    GenServer.call(__MODULE__, :list_nodes)
  end

  @doc """
  Queries nodes with filters.
  """
  @spec query(query()) :: [node_entry()]
  def query(filters) do
    GenServer.call(__MODULE__, {:query, filters})
  end

  @doc """
  Removes a node from the directory.
  """
  @spec remove(String.t()) :: :ok
  def remove(node_id) do
    GenServer.call(__MODULE__, {:remove, node_id})
  end

  @doc """
  Gets the network topology.
  """
  @spec topology() :: map()
  def topology do
    GenServer.call(__MODULE__, :topology)
  end

  @doc """
  Gets directory statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Finds nodes by parent.
  """
  @spec find_children(String.t()) :: [node_entry()]
  def find_children(parent_id) do
    query(%{parent_id: parent_id, state: nil, generation: nil, limit: 100})
  end

  @doc """
  Gets lineage path for a node.
  """
  @spec get_lineage(String.t()) :: {:ok, [node_entry()]} | {:error, term()}
  def get_lineage(node_id) do
    GenServer.call(__MODULE__, {:get_lineage, node_id})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    state = %{
      nodes: %{},
      history: [],
      stats: %{
        total_registered: 0,
        total_removed: 0,
        queries: 0
      }
    }

    Logger.info("📖 Directory service starting")

    {:ok, state}
  end

  @impl true
  def handle_call({:register, entry}, _from, state) do
    if Map.has_key?(state.nodes, entry.id) do
      {:reply, {:error, :already_exists}, state}
    else
      entry =
        entry
        |> Map.put(:created_at, DateTime.utc_now())
        |> Map.put(:updated_at, DateTime.utc_now())

      new_nodes = Map.put(state.nodes, entry.id, entry)
      new_stats = Map.update!(state.stats, :total_registered, &(&1 + 1))

      # Add to history
      history_entry = %{
        action: :register,
        node_id: entry.id,
        timestamp: DateTime.utc_now()
      }

      new_history = add_to_history(state.history, history_entry)

      Logger.info("📖 Registered node #{entry.id}")

      {:reply, :ok, %{state | nodes: new_nodes, stats: new_stats, history: new_history}}
    end
  end

  @impl true
  def handle_call({:update, node_id, updates}, _from, state) do
    case Map.get(state.nodes, node_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      entry ->
        updated_entry =
          entry
          |> Map.merge(updates)
          |> Map.put(:updated_at, DateTime.utc_now())

        new_nodes = Map.put(state.nodes, node_id, updated_entry)

        {:reply, :ok, %{state | nodes: new_nodes}}
    end
  end

  @impl true
  def handle_call({:get_node, node_id}, _from, state) do
    case Map.get(state.nodes, node_id) do
      nil -> {:reply, {:error, :not_found}, state}
      entry -> {:reply, {:ok, entry}, state}
    end
  end

  @impl true
  def handle_call(:list_nodes, _from, state) do
    nodes = Map.values(state.nodes)
    {:reply, nodes, state}
  end

  @impl true
  def handle_call({:query, filters}, _from, state) do
    new_stats = Map.update!(state.stats, :queries, &(&1 + 1))

    results =
      state.nodes
      |> Map.values()
      |> apply_filters(filters)
      |> Enum.take(Map.get(filters, :limit, 100))

    {:reply, results, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:remove, node_id}, _from, state) do
    new_nodes = Map.delete(state.nodes, node_id)
    new_stats = Map.update!(state.stats, :total_removed, &(&1 + 1))

    # Add to history
    history_entry = %{
      action: :remove,
      node_id: node_id,
      timestamp: DateTime.utc_now()
    }

    new_history = add_to_history(state.history, history_entry)

    Logger.info("📖 Removed node #{node_id}")

    {:reply, :ok, %{state | nodes: new_nodes, stats: new_stats, history: new_history}}
  end

  @impl true
  def handle_call(:topology, _from, state) do
    topology = build_topology(state.nodes)
    {:reply, topology, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      state.stats
      |> Map.put(:active_nodes, map_size(state.nodes))
      |> Map.put(:history_size, length(state.history))

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:get_lineage, node_id}, _from, state) do
    lineage = build_lineage(state.nodes, node_id, [])
    {:reply, {:ok, lineage}, state}
  end

  # Private helpers

  defp apply_filters(nodes, filters) do
    nodes
    |> maybe_filter_state(filters[:state])
    |> maybe_filter_generation(filters[:generation])
    |> maybe_filter_parent(filters[:parent_id])
  end

  defp maybe_filter_state(nodes, nil), do: nodes

  defp maybe_filter_state(nodes, state) do
    Enum.filter(nodes, fn node -> node.membership.state == state end)
  end

  defp maybe_filter_generation(nodes, nil), do: nodes

  defp maybe_filter_generation(nodes, generation) do
    Enum.filter(nodes, fn node -> node.generation == generation end)
  end

  defp maybe_filter_parent(nodes, nil), do: nodes

  defp maybe_filter_parent(nodes, parent_id) do
    Enum.filter(nodes, fn node -> node.parent_id == parent_id end)
  end

  defp build_topology(nodes) do
    # Build parent-child relationships
    by_parent =
      nodes
      |> Map.values()
      |> Enum.group_by(fn node -> node.parent_id end)

    # Find roots (nodes with no parent)
    roots =
      nodes
      |> Map.values()
      |> Enum.filter(fn node -> is_nil(node.parent_id) end)
      |> Enum.map(fn node -> node.id end)

    %{
      total_nodes: map_size(nodes),
      roots: roots,
      by_generation: group_by_generation(nodes),
      parent_child_map: by_parent
    }
  end

  defp group_by_generation(nodes) do
    nodes
    |> Map.values()
    |> Enum.group_by(fn node -> node.generation end)
    |> Enum.map(fn {gen, gen_nodes} -> {gen, length(gen_nodes)} end)
    |> Map.new()
  end

  defp build_lineage(nodes, node_id, acc) do
    case Map.get(nodes, node_id) do
      nil ->
        Enum.reverse(acc)

      node ->
        new_acc = [node | acc]

        if is_nil(node.parent_id) do
          Enum.reverse(new_acc)
        else
          build_lineage(nodes, node.parent_id, new_acc)
        end
    end
  end

  defp add_to_history(history, entry) do
    [entry | history]
    |> Enum.take(@max_history)
  end
end
