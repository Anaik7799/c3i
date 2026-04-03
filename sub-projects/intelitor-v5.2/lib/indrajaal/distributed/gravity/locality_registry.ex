defmodule Indrajaal.Distributed.Gravity.LocalityRegistry do
  @moduledoc """
  ETS-based data locality tracking for gravity routing.

  Tracks where data resides across the cluster to enable "move compute to data"
  routing decisions. Uses ETS for sub-100us lookups.

  ## STAMP Constraints

  - SC-GRAV-001: Locality lookup < 100us
  - SC-GRAV-004: Route decision logged for audit

  ## Data Gravity Concept

  Data gravity is the tendency for services to aggregate around data.
  Large, frequently accessed data has higher "gravity" and should attract
  compute rather than being moved.

  ## Usage

      {:ok, registry} = LocalityRegistry.start_link()

      # Register data location
      LocalityRegistry.register(registry, "alarms/tenant-1/zone-a", "node-1@host", %{
        size_bytes: 1_000_000,
        access_count: 500
      })

      # Lookup where data lives
      info = LocalityRegistry.lookup(registry, "alarms/tenant-1/zone-a")
      # => %{primary_node: "node-1@host", size_bytes: 1_000_000, ...}

      # Calculate data gravity
      gravity = LocalityRegistry.get_data_gravity(registry, key)

  """

  use GenServer
  require Logger

  @type key :: String.t()
  @type node_id :: String.t()
  @type locality_info :: %{
          primary_node: node_id(),
          replica_nodes: [node_id()],
          size_bytes: non_neg_integer(),
          access_count: non_neg_integer(),
          last_accessed: DateTime.t(),
          registered_at: DateTime.t()
        }

  # Gravity calculation constants
  @size_weight 0.7
  @access_weight 0.3

  # ============================================================================
  # CLIENT API
  # ============================================================================

  @doc """
  Starts the locality registry.

  ## Options

  - `:name` - Process name (optional)

  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Registers a data key's location.
  """
  @spec register(GenServer.server(), key(), node_id(), map()) :: :ok
  def register(server \\ __MODULE__, key, primary_node, metadata \\ %{}) do
    GenServer.call(server, {:register, key, primary_node, metadata})
  end

  @doc """
  Looks up locality info for a key.

  Returns nil if key is not registered.
  """
  @spec lookup(GenServer.server(), key()) :: locality_info() | nil
  def lookup(server \\ __MODULE__, key) do
    GenServer.call(server, {:lookup, key})
  end

  @doc """
  Unregisters a data key.
  """
  @spec unregister(GenServer.server(), key()) :: :ok
  def unregister(server \\ __MODULE__, key) do
    GenServer.call(server, {:unregister, key})
  end

  @doc """
  Updates the last accessed timestamp for a key.
  """
  @spec update_access(GenServer.server(), key()) :: :ok
  def update_access(server \\ __MODULE__, key) do
    GenServer.call(server, {:update_access, key})
  end

  @doc """
  Finds all keys stored on a specific node.
  """
  @spec find_by_node(GenServer.server(), node_id()) :: [key()]
  def find_by_node(server \\ __MODULE__, node_id) do
    GenServer.call(server, {:find_by_node, node_id})
  end

  @doc """
  Calculates the "data gravity" for a key.

  Higher gravity means the data should attract compute rather than be moved.
  """
  @spec get_data_gravity(GenServer.server(), key()) :: float()
  def get_data_gravity(server \\ __MODULE__, key) do
    GenServer.call(server, {:get_data_gravity, key})
  end

  @doc """
  Finds the nearest replica node for a key relative to a calling node.
  """
  @spec find_nearest_replica(GenServer.server(), key(), node_id()) :: node_id() | nil
  def find_nearest_replica(server \\ __MODULE__, key, from_node) do
    GenServer.call(server, {:find_nearest_replica, key, from_node})
  end

  @doc """
  Returns registry metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server \\ __MODULE__) do
    GenServer.call(server, :metrics)
  end

  @doc """
  Returns health status.
  """
  @spec health(GenServer.server()) :: map()
  def health(server \\ __MODULE__) do
    GenServer.call(server, :health)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(_opts) do
    # Create ETS table for fast lookups
    table = :ets.new(:locality_registry, [:set, :protected, {:read_concurrency, true}])

    state = %{
      table: table,
      started_at: DateTime.utc_now()
    }

    Logger.info("[LocalityRegistry] Started with ETS table")

    {:ok, state}
  end

  @impl true
  def handle_call({:register, key, primary_node, metadata}, _from, state) do
    now = DateTime.utc_now()

    info = %{
      primary_node: primary_node,
      replica_nodes: Map.get(metadata, :replica_nodes, []),
      size_bytes: Map.get(metadata, :size_bytes, 0),
      access_count: Map.get(metadata, :access_count, 0),
      last_accessed: Map.get(metadata, :last_accessed, now),
      registered_at: now
    }

    :ets.insert(state.table, {key, info})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:lookup, key}, _from, state) do
    result =
      case :ets.lookup(state.table, key) do
        [{^key, info}] -> info
        [] -> nil
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:unregister, key}, _from, state) do
    :ets.delete(state.table, key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_access, key}, _from, state) do
    case :ets.lookup(state.table, key) do
      [{^key, info}] ->
        updated_info = %{
          info
          | last_accessed: DateTime.utc_now(),
            access_count: info.access_count + 1
        }

        :ets.insert(state.table, {key, updated_info})

      [] ->
        :ok
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:find_by_node, node_id}, _from, state) do
    keys =
      :ets.foldl(
        fn {key, info}, acc ->
          if info.primary_node == node_id do
            [key | acc]
          else
            acc
          end
        end,
        [],
        state.table
      )

    {:reply, keys, state}
  end

  @impl true
  def handle_call({:get_data_gravity, key}, _from, state) do
    gravity =
      case :ets.lookup(state.table, key) do
        [{^key, info}] ->
          calculate_gravity(info)

        [] ->
          0.0
      end

    {:reply, gravity, state}
  end

  @impl true
  def handle_call({:find_nearest_replica, key, from_node}, _from, state) do
    result =
      case :ets.lookup(state.table, key) do
        [{^key, info}] ->
          all_nodes = [info.primary_node | info.replica_nodes]
          find_closest_node(all_nodes, from_node)

        [] ->
          nil
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    {total_entries, total_size} =
      :ets.foldl(
        fn {_key, info}, {count, size} ->
          {count + 1, size + info.size_bytes}
        end,
        {0, 0},
        state.table
      )

    metrics = %{
      total_entries: total_entries,
      total_size_bytes: total_size,
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:health, _from, state) do
    health = %{
      status: :healthy,
      entry_count: :ets.info(state.table, :size),
      table_memory_bytes: :ets.info(state.table, :memory) * :erlang.system_info(:wordsize)
    }

    {:reply, health, state}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp calculate_gravity(info) do
    # Normalize size (assuming max ~1GB = 1_000_000_000 bytes)
    size_factor = min(1.0, info.size_bytes / 1_000_000_000)

    # Normalize access count (assuming max ~10_000 accesses)
    access_factor = min(1.0, info.access_count / 10_000)

    # Combined gravity score
    @size_weight * size_factor + @access_weight * access_factor
  end

  defp find_closest_node(nodes, from_node) do
    # Extract datacenter/region from node name (format: name@dc-region)
    from_dc = extract_datacenter(from_node)

    # Prefer nodes in same datacenter
    same_dc_nodes =
      Enum.filter(nodes, fn node ->
        extract_datacenter(node) == from_dc
      end)

    case same_dc_nodes do
      [first | _] -> first
      [] -> List.first(nodes)
    end
  end

  defp extract_datacenter(node_name) do
    case String.split(node_name, "@") do
      [_name, location] ->
        case String.split(location, "-") do
          [dc | _] -> dc
          _ -> location
        end

      _ ->
        node_name
    end
  end
end
