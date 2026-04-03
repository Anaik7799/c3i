defmodule Indrajaal.Distributed.Mesh.Holography do
  @moduledoc """
  State Holography - Distributed State Replication for v20.0.0

  Implements holographic state distribution:
  - Every node contains the whole (to some resolution)
  - State is reconstructable from any subset
  - Graceful degradation with fewer nodes

  ## Holographic Model

  State as hologram:
  - Full state = superposition of partial states
  - Any fragment contains information about whole
  - Resolution increases with more fragments

  ## Replication Strategies
  - **Full**: Complete state on every node
  - **Sharded**: Partitioned with replicas
  - **Erasure**: Reed-Solomon coded fragments
  - **CRDT**: Conflict-free replicated data types

  ## STAMP Constraints
  - SC-HOL-001: State MUST be recoverable from N-1 nodes
  - SC-HOL-002: Consistency level MUST be configurable
  - SC-HOL-003: Replication factor MUST be >= 3
  - SC-HOL-004: State version MUST be tracked
  """

  use GenServer
  require Logger

  alias Indrajaal.Distributed.Mesh.{Mycelium, Gossip}

  @type node_id :: String.t()
  @type state_key :: atom() | String.t()
  @type replication_strategy :: :full | :sharded | :erasure | :crdt
  @type consistency_level :: :one | :quorum | :all

  @type state_entry :: %{
          key: state_key(),
          value: term(),
          version: non_neg_integer(),
          replicas: [node_id()],
          strategy: replication_strategy(),
          updated_at: DateTime.t()
        }

  @type holo_state :: %{
          node_id: node_id(),
          local_state: map(),
          version_vectors: map(),
          config: map()
        }

  # Default replication factor
  @default_replication_factor 3

  # Sync interval
  @sync_interval 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sets a value in distributed state.
  """
  @spec put(state_key(), term(), Keyword.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def put(key, value, opts \\ []) do
    GenServer.call(__MODULE__, {:put, key, value, opts})
  end

  @doc """
  Gets a value from distributed state.
  """
  @spec get(state_key(), Keyword.t()) :: {:ok, term(), non_neg_integer()} | {:error, :not_found}
  def get(key, opts \\ []) do
    GenServer.call(__MODULE__, {:get, key, opts})
  end

  @doc """
  Deletes a value from distributed state.
  """
  @spec delete(state_key()) :: :ok
  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  @doc """
  Gets all keys in distributed state.
  """
  @spec keys() :: [state_key()]
  def keys do
    GenServer.call(__MODULE__, :keys)
  end

  @doc """
  Forces sync with other nodes.
  """
  @spec sync() :: :ok
  def sync do
    GenServer.cast(__MODULE__, :sync)
  end

  @doc """
  Gets replication status for a key.
  """
  @spec replication_status(state_key()) :: {:ok, map()} | {:error, :not_found}
  def replication_status(key) do
    GenServer.call(__MODULE__, {:replication_status, key})
  end

  @doc """
  Gets holography statistics.
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
      local_state: %{},
      version_vectors: %{},
      pending_writes: [],
      stats: %{
        reads: 0,
        writes: 0,
        syncs: 0,
        conflicts: 0
      },
      config: %{
        replication_factor: Keyword.get(opts, :replication_factor, @default_replication_factor),
        default_strategy: Keyword.get(opts, :strategy, :full),
        consistency: Keyword.get(opts, :consistency, :quorum)
      }
    }

    # Schedule periodic sync
    Process.send_after(self(), :periodic_sync, @sync_interval)

    Logger.info("🌌 Holography service started on #{node_id}")

    {:ok, state}
  end

  @impl true
  def handle_call({:put, key, value, opts}, _from, state) do
    strategy = Keyword.get(opts, :strategy, state.config.default_strategy)
    consistency = Keyword.get(opts, :consistency, state.config.consistency)

    # Increment version
    current_version = Map.get(state.version_vectors, key, 0)
    new_version = current_version + 1

    entry = %{
      key: key,
      value: value,
      version: new_version,
      replicas: [state.node_id],
      strategy: strategy,
      updated_at: DateTime.utc_now()
    }

    # Store locally
    new_local = Map.put(state.local_state, key, entry)
    new_versions = Map.put(state.version_vectors, key, new_version)

    # Replicate based on strategy
    case replicate(entry, strategy, consistency, state) do
      {:ok, replicas} ->
        # Update entry with replica info
        final_entry = %{entry | replicas: [state.node_id | replicas]}
        final_local = Map.put(new_local, key, final_entry)

        # Update stats
        new_stats = %{state.stats | writes: state.stats.writes + 1}

        {:reply, {:ok, new_version},
         %{state | local_state: final_local, version_vectors: new_versions, stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get, key, opts}, _from, state) do
    consistency = Keyword.get(opts, :consistency, state.config.consistency)

    case consistency do
      :one ->
        # Read from local only
        read_local(key, state)

      :quorum ->
        # Read from quorum
        read_quorum(key, state)

      :all ->
        # Read from all replicas
        read_all(key, state)
    end
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    new_local = Map.delete(state.local_state, key)
    new_versions = Map.delete(state.version_vectors, key)

    # Propagate deletion
    Gossip.gossip_state(key, :tombstone, System.monotonic_time())

    {:reply, :ok, %{state | local_state: new_local, version_vectors: new_versions}}
  end

  @impl true
  def handle_call(:keys, _from, state) do
    keys = Map.keys(state.local_state)
    {:reply, keys, state}
  end

  @impl true
  def handle_call({:replication_status, key}, _from, state) do
    case Map.get(state.local_state, key) do
      nil ->
        {:reply, {:error, :not_found}, state}

      entry ->
        status = %{
          key: key,
          version: entry.version,
          strategy: entry.strategy,
          replicas: entry.replicas,
          replication_factor: length(entry.replicas),
          target_factor: state.config.replication_factor,
          healthy: length(entry.replicas) >= state.config.replication_factor
        }

        {:reply, {:ok, status}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        keys: map_size(state.local_state),
        avg_replicas: average_replicas(state),
        under_replicated: count_under_replicated(state)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast(:sync, state) do
    do_sync(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    do_sync(state)

    # Update stats
    new_stats = %{state.stats | syncs: state.stats.syncs + 1}

    # Schedule next sync
    Process.send_after(self(), :periodic_sync, @sync_interval)

    {:noreply, %{state | stats: new_stats}}
  end

  @impl true
  def handle_info({:sync_request, from_node, their_versions}, state) do
    # Find keys where we have newer versions
    filtered =
      Enum.filter(state.local_state, fn {key, entry} ->
        their_version = Map.get(their_versions, key, 0)
        entry.version > their_version
      end)

    delta = filtered |> Map.new()

    # Send delta
    Mycelium.send_message(from_node, {:sync_response, state.node_id, delta})

    {:noreply, state}
  end

  @impl true
  def handle_info({:sync_response, _from_node, delta}, state) do
    # Merge delta with conflict resolution
    new_state = merge_delta(state, delta)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:replicate, entry}, state) do
    # Handle incoming replication request
    case Map.get(state.local_state, entry.key) do
      nil ->
        # New entry, accept
        new_local = Map.put(state.local_state, entry.key, entry)
        new_versions = Map.put(state.version_vectors, entry.key, entry.version)
        {:noreply, %{state | local_state: new_local, version_vectors: new_versions}}

      existing when existing.version < entry.version ->
        # Newer version, accept
        new_local = Map.put(state.local_state, entry.key, entry)
        new_versions = Map.put(state.version_vectors, entry.key, entry.version)
        {:noreply, %{state | local_state: new_local, version_vectors: new_versions}}

      _ ->
        # Older or same version, ignore
        {:noreply, state}
    end
  end

  # Private helpers

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  defp replicate(entry, strategy, consistency, state) do
    # Get available nodes
    nodes =
      Mycelium.nodes()
      |> Enum.filter(&(&1.status == :alive))
      |> Enum.map(& &1.id)

    case strategy do
      :full ->
        replicate_full(entry, nodes, consistency, state)

      :sharded ->
        replicate_sharded(entry, nodes, state)

      :erasure ->
        replicate_erasure(entry, nodes, state)

      :crdt ->
        replicate_crdt(entry, nodes, state)
    end
  end

  defp replicate_full(entry, nodes, consistency, state) do
    target = state.config.replication_factor - 1
    selected = Enum.take_random(nodes, target)

    # Send to selected nodes
    results =
      Enum.map(selected, fn node_id ->
        case Mycelium.send_message(node_id, {:replicate, entry}) do
          :ok -> {:ok, node_id}
          error -> error
        end
      end)

    successful = Enum.filter(results, fn r -> match?({:ok, _}, r) end)
    successful_ids = Enum.map(successful, fn {:ok, id} -> id end)

    # Check consistency requirement
    required =
      case consistency do
        :one -> 0
        :quorum -> div(state.config.replication_factor, 2)
        :all -> target
      end

    if length(successful_ids) >= required do
      {:ok, successful_ids}
    else
      {:error, :insufficient_replicas}
    end
  end

  defp replicate_sharded(entry, nodes, state) do
    # Consistent hashing to select primary + replicas
    hash = :erlang.phash2(entry.key, length(nodes) + 1)
    start_idx = rem(hash, max(length(nodes), 1))

    replicas =
      nodes
      |> Stream.cycle()
      |> Stream.drop(start_idx)
      |> Enum.take(state.config.replication_factor - 1)

    Enum.each(replicas, fn node_id ->
      Mycelium.send_message(node_id, {:replicate, entry})
    end)

    {:ok, replicas}
  end

  defp replicate_erasure(entry, nodes, state) do
    # Simplified erasure coding
    # In production would use Reed-Solomon
    replicate_full(entry, nodes, :quorum, state)
  end

  defp replicate_crdt(entry, nodes, _state) do
    # CRDT replication via gossip
    Gossip.gossip_state(entry.key, entry.value, entry.version)
    {:ok, nodes}
  end

  defp read_local(key, state) do
    case Map.get(state.local_state, key) do
      nil ->
        {:reply, {:error, :not_found}, state}

      entry ->
        new_stats = %{state.stats | reads: state.stats.reads + 1}
        {:reply, {:ok, entry.value, entry.version}, %{state | stats: new_stats}}
    end
  end

  defp read_quorum(key, state) do
    # For simplicity, read local
    # In production would query multiple nodes
    read_local(key, state)
  end

  defp read_all(key, state) do
    # For simplicity, read local
    # In production would query all replicas
    read_local(key, state)
  end

  defp do_sync(state) do
    nodes =
      Mycelium.nodes()
      |> Enum.filter(&(&1.status == :alive))

    Enum.each(nodes, fn node ->
      Mycelium.send_message(node.id, {:sync_request, state.node_id, state.version_vectors})
    end)
  end

  defp merge_delta(state, delta) do
    Enum.reduce(delta, state, fn {key, entry}, acc ->
      merge_entry(acc, key, entry)
    end)
  end

  defp merge_entry(acc, key, entry) do
    case Map.get(acc.local_state, key) do
      nil ->
        apply_new_entry(acc, key, entry)

      existing when existing.version < entry.version ->
        apply_new_entry(acc, key, entry)

      existing when existing.version == entry.version and existing.value != entry.value ->
        resolve_entry_conflict(acc, key, entry, existing)

      _ ->
        acc
    end
  end

  defp apply_new_entry(acc, key, entry) do
    new_local = Map.put(acc.local_state, key, entry)
    new_versions = Map.put(acc.version_vectors, key, entry.version)
    %{acc | local_state: new_local, version_vectors: new_versions}
  end

  defp resolve_entry_conflict(acc, key, entry, existing) do
    if DateTime.compare(entry.updated_at, existing.updated_at) == :gt do
      new_local = Map.put(acc.local_state, key, entry)
      new_stats = %{acc.stats | conflicts: acc.stats.conflicts + 1}
      %{acc | local_state: new_local, stats: new_stats}
    else
      new_stats = %{acc.stats | conflicts: acc.stats.conflicts + 1}
      %{acc | stats: new_stats}
    end
  end

  defp average_replicas(state) do
    if map_size(state.local_state) == 0 do
      0.0
    else
      total =
        state.local_state
        |> Map.values()
        |> Enum.reduce(0, fn entry, acc -> acc + length(entry.replicas) end)

      total / map_size(state.local_state)
    end
  end

  defp count_under_replicated(state) do
    state.local_state
    |> Map.values()
    |> Enum.count(fn entry -> length(entry.replicas) < state.config.replication_factor end)
  end
end
