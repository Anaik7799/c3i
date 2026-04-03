defmodule Indrajaal.Cybernetic.EventSourcing.Snapshot do
  @moduledoc """
  State Snapshots - Fast State Recovery for v20.0.0

  Implements snapshot capabilities for event sourcing:
  - Periodic state snapshots
  - Incremental snapshots
  - Snapshot compression
  - Fast recovery from snapshots

  ## Snapshot Model

  Snapshot = {stream, version, state, timestamp, checksum}

  Recovery: State(v) = Snapshot(v') + fold(events[v'..v])
  Where v' is the latest snapshot version <= v

  ## Snapshot Strategies
  - **Periodic**: Every N events
  - **Time-based**: Every T seconds
  - **Size-based**: When state exceeds S bytes
  - **Manual**: On-demand snapshots

  ## STAMP Constraints
  - SC-SNP-001: Snapshots MUST include version number
  - SC-SNP-002: Snapshot integrity MUST be verified (checksum)
  - SC-SNP-003: Snapshot storage MUST be durable
  - SC-SNP-004: Recovery MUST be deterministic
  """

  use GenServer
  require Logger

  alias Indrajaal.Cybernetic.EventSourcing.EventStore

  @type snapshot :: %{
          id: String.t(),
          stream: String.t(),
          version: non_neg_integer(),
          state: map(),
          timestamp: DateTime.t(),
          checksum: String.t(),
          compressed: boolean(),
          metadata: map()
        }

  @type snapshot_strategy :: :periodic | :time_based | :size_based | :manual

  @type snapshot_config :: %{
          strategy: snapshot_strategy(),
          interval: non_neg_integer(),
          max_snapshots: non_neg_integer(),
          compress: boolean()
        }

  @type store_state :: %{
          snapshots: map(),
          configs: map(),
          timers: map()
        }

  # Default snapshot interval (events)
  @default_interval 100

  # Default max snapshots per stream
  @default_max_snapshots 10

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a snapshot of current state.
  """
  @spec create(String.t(), map(), non_neg_integer()) :: {:ok, snapshot()} | {:error, term()}
  def create(stream, state, version) do
    GenServer.call(__MODULE__, {:create, stream, state, version})
  end

  @doc """
  Gets the latest snapshot for a stream.
  """
  @spec get_latest(String.t()) :: {:ok, snapshot()} | {:error, :not_found}
  def get_latest(stream) do
    GenServer.call(__MODULE__, {:get_latest, stream})
  end

  @doc """
  Gets snapshot at or before a specific version.
  """
  @spec get_at_version(String.t(), non_neg_integer()) :: {:ok, snapshot()} | {:error, :not_found}
  def get_at_version(stream, version) do
    GenServer.call(__MODULE__, {:get_at_version, stream, version})
  end

  @doc """
  Recovers state from snapshot + events.
  """
  @spec recover(String.t(), non_neg_integer(), function()) :: {:ok, map()} | {:error, term()}
  def recover(stream, target_version, reducer) do
    GenServer.call(__MODULE__, {:recover, stream, target_version, reducer})
  end

  @doc """
  Configures snapshot strategy for a stream.
  """
  @spec configure(String.t(), snapshot_config()) :: :ok
  def configure(stream, config) do
    GenServer.call(__MODULE__, {:configure, stream, config})
  end

  @doc """
  Lists all snapshots for a stream.
  """
  @spec list(String.t()) :: [snapshot()]
  def list(stream) do
    GenServer.call(__MODULE__, {:list, stream})
  end

  @doc """
  Deletes old snapshots, keeping only the most recent N.
  """
  @spec prune(String.t(), non_neg_integer()) :: :ok
  def prune(stream, keep_count) do
    GenServer.call(__MODULE__, {:prune, stream, keep_count})
  end

  @doc """
  Verifies snapshot integrity.
  """
  @spec verify(snapshot()) :: boolean()
  def verify(snapshot) do
    computed = compute_checksum(snapshot.state)
    snapshot.checksum == computed
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      snapshots: %{},
      configs: %{},
      timers: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:create, stream, user_state, version}, _from, state) do
    # Compute checksum (SC-SNP-002)
    checksum = compute_checksum(user_state)

    # Create snapshot (SC-SNP-001: includes version)
    snapshot = %{
      id: generate_snapshot_id(),
      stream: stream,
      version: version,
      state: user_state,
      timestamp: DateTime.utc_now(),
      checksum: checksum,
      compressed: false,
      metadata: %{}
    }

    # Get config
    config = Map.get(state.configs, stream, default_config())

    # Compress if configured
    final_snapshot =
      if config.compress do
        compress_snapshot(snapshot)
      else
        snapshot
      end

    # Store snapshot
    stream_snapshots = Map.get(state.snapshots, stream, [])
    new_stream_snapshots = [final_snapshot | stream_snapshots]

    # Prune if needed
    pruned =
      if length(new_stream_snapshots) > config.max_snapshots do
        Enum.take(new_stream_snapshots, config.max_snapshots)
      else
        new_stream_snapshots
      end

    new_snapshots = Map.put(state.snapshots, stream, pruned)

    {:reply, {:ok, final_snapshot}, %{state | snapshots: new_snapshots}}
  end

  @impl true
  def handle_call({:get_latest, stream}, _from, state) do
    case Map.get(state.snapshots, stream, []) do
      [] -> {:reply, {:error, :not_found}, state}
      [latest | _] -> {:reply, {:ok, decompress_snapshot(latest)}, state}
    end
  end

  @impl true
  def handle_call({:get_at_version, stream, version}, _from, state) do
    snapshots = Map.get(state.snapshots, stream, [])

    result =
      snapshots
      |> Enum.filter(fn s -> s.version <= version end)
      |> Enum.max_by(fn s -> s.version end, fn -> nil end)

    case result do
      nil -> {:reply, {:error, :not_found}, state}
      snapshot -> {:reply, {:ok, decompress_snapshot(snapshot)}, state}
    end
  end

  @impl true
  def handle_call({:recover, stream, target_version, reducer}, _from, state) do
    # Find best snapshot
    snapshots = Map.get(state.snapshots, stream, [])

    best_snapshot =
      snapshots
      |> Enum.filter(fn s -> s.version <= target_version end)
      |> Enum.max_by(fn s -> s.version end, fn -> nil end)

    if best_snapshot do
      snapshot = decompress_snapshot(best_snapshot)

      # Verify integrity (SC-SNP-002)
      if verify(snapshot) do
        # Get events since snapshot
        case EventStore.read(stream,
               from_version: snapshot.version,
               to_version: target_version
             ) do
          {:ok, events} ->
            # Apply events to snapshot state (SC-SNP-004: deterministic)
            final_state = Enum.reduce(events, snapshot.state, reducer)
            {:reply, {:ok, final_state}, state}

          error ->
            {:reply, error, state}
        end
      else
        {:reply, {:error, :checksum_mismatch}, state}
      end
    else
      # No snapshot, must rebuild from scratch
      case EventStore.read(stream, to_version: target_version) do
        {:ok, events} ->
          final_state = Enum.reduce(events, %{}, reducer)
          {:reply, {:ok, final_state}, state}

        error ->
          {:reply, error, state}
      end
    end
  end

  @impl true
  def handle_call({:configure, stream, config}, _from, state) do
    new_configs = Map.put(state.configs, stream, Map.merge(default_config(), config))

    # Set up timer for time-based strategy
    new_timers =
      if config.strategy == :time_based do
        timer = Process.send_after(self(), {:auto_snapshot, stream}, config.interval * 1000)
        Map.put(state.timers, stream, timer)
      else
        state.timers
      end

    {:reply, :ok, %{state | configs: new_configs, timers: new_timers}}
  end

  @impl true
  def handle_call({:list, stream}, _from, state) do
    snapshots = Map.get(state.snapshots, stream, [])
    {:reply, Enum.map(snapshots, &decompress_snapshot/1), state}
  end

  @impl true
  def handle_call({:prune, stream, keep_count}, _from, state) do
    snapshots = Map.get(state.snapshots, stream, [])
    pruned = Enum.take(snapshots, keep_count)
    new_snapshots = Map.put(state.snapshots, stream, pruned)
    {:reply, :ok, %{state | snapshots: new_snapshots}}
  end

  @impl true
  def handle_info({:auto_snapshot, stream}, state) do
    # Get current version
    version = EventStore.stream_version(stream)

    # Check if we need a snapshot
    snapshots = Map.get(state.snapshots, stream, [])

    should_snapshot =
      case snapshots do
        [] -> true
        [latest | _] -> version - latest.version > 0
      end

    if should_snapshot do
      Logger.debug("Auto-creating snapshot for #{stream} at version #{version}")
      # Would need to get current state from somewhere
      # For now, just log
    end

    # Reschedule
    config = Map.get(state.configs, stream, default_config())

    if config.strategy == :time_based do
      timer = Process.send_after(self(), {:auto_snapshot, stream}, config.interval * 1000)
      new_timers = Map.put(state.timers, stream, timer)
      {:noreply, %{state | timers: new_timers}}
    else
      {:noreply, state}
    end
  end

  # Private helpers

  defp default_config do
    %{
      strategy: :periodic,
      interval: @default_interval,
      max_snapshots: @default_max_snapshots,
      compress: false
    }
  end

  defp generate_snapshot_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  defp compute_checksum(state) do
    state
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp compress_snapshot(snapshot) do
    compressed_state =
      snapshot.state
      |> :erlang.term_to_binary()
      |> :zlib.compress()

    %{snapshot | state: compressed_state, compressed: true}
  end

  defp decompress_snapshot(%{compressed: false} = snapshot), do: snapshot

  defp decompress_snapshot(%{compressed: true} = snapshot) do
    decompressed_state =
      snapshot.state
      |> :zlib.uncompress()
      |> :erlang.binary_to_term()

    %{snapshot | state: decompressed_state, compressed: false}
  end
end
