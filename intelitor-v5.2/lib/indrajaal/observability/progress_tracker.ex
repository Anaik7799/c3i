defmodule Indrajaal.Observability.ProgressTracker do
  @moduledoc """
  Real-time progress tracking for multi-agent CEPAF coordination.

  WHAT: Tracks task completion, agent status, and KPI metrics in ETS.
  WHY: Enables real-time dashboard updates and progress monitoring.
  CONSTRAINTS: Non-blocking updates, <1ms write latency.

  ## Features

  - Agent status tracking (pending/running/completed/failed)
  - Task completion percentages with automatic calculation
  - KPI snapshots with timestamps for trend analysis
  - Phase progression tracking (1, 2, 3)
  - PubSub integration for real-time updates
  - Snapshot history for historical analysis

  ## STAMP Constraints

  | Constraint  | Description                                     |
  |-------------|------------------------------------------------|
  | SC-PTR-001  | ETS writes must complete in <1ms               |
  | SC-PTR-002  | Agent status updates are non-blocking          |
  | SC-PTR-003  | KPI values persist across reads                |
  | SC-PTR-004  | Completion percentage is always 0-100          |
  | SC-PTR-005  | Snapshot history maintains chronological order |

  ## Usage

      # Start the tracker
      {:ok, _pid} = Indrajaal.Observability.ProgressTracker.start_link([])

      # Update agent status
      :ok = ProgressTracker.update_agent_status("agent_1", :running)

      # Update KPIs
      :ok = ProgressTracker.update_kpi("throughput", 1500.5)

      # Get current progress
      progress = ProgressTracker.get_progress()

      # Subscribe to updates
      {:ok, ref} = ProgressTracker.subscribe()

  ## DSL: Configuration Options

  - `:name` - Process name (default: `ProgressTracker`)
  - `:update_interval_ms` - Interval for periodic snapshots (default: 30_000)
  - `:max_snapshots` - Maximum number of snapshots to retain (default: 100)
  """

  use GenServer
  require Logger

  @table :progress_tracker
  @snapshots_table :progress_tracker_snapshots
  @update_interval_ms 30_000
  @max_snapshots 100

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type agent_status :: :pending | :running | :completed | :failed
  @type kpi_value :: number()
  @type agent_id :: String.t()
  @type kpi_name :: String.t()
  @type snapshot_id :: String.t()

  @type progress :: %{
          agents: %{agent_id() => agent_data()},
          tasks: %{String.t() => task_data()},
          kpis: %{kpi_name() => kpi_value()},
          phase: 1 | 2 | 3,
          started_at: DateTime.t(),
          last_updated: DateTime.t()
        }

  @type agent_data :: %{
          status: agent_status(),
          updated_at: DateTime.t(),
          metadata: map()
        }

  @type task_data :: %{
          status: agent_status(),
          agent_id: agent_id(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }

  @type snapshot :: %{
          id: snapshot_id(),
          timestamp: DateTime.t(),
          agents: map(),
          kpis: map(),
          phase: integer(),
          completion_percentage: float()
        }

  # ============================================================
  # STATE STRUCTURE
  # ============================================================

  defstruct [
    :started_at,
    :last_updated,
    :phase,
    :subscribers,
    :snapshot_timer,
    :update_interval_ms,
    :max_snapshots
  ]

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Starts the ProgressTracker GenServer.

  ## Options

  - `:name` - Process name (default: `ProgressTracker`)
  - `:update_interval_ms` - Snapshot interval in milliseconds (default: 30_000)
  - `:max_snapshots` - Maximum snapshots to retain (default: 100)

  ## Examples

      {:ok, pid} = ProgressTracker.start_link([])
      {:ok, pid} = ProgressTracker.start_link(name: :custom_tracker)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets the current progress state.

  Returns a map containing:
  - `:agents` - Map of agent_id to agent status data
  - `:tasks` - Map of task_id to task status data
  - `:kpis` - Map of KPI names to current values
  - `:phase` - Current phase (1, 2, or 3)
  - `:started_at` - Timestamp when tracking started
  - `:last_updated` - Timestamp of last update

  ## Examples

      progress = ProgressTracker.get_progress()
      # => %{agents: %{}, tasks: %{}, kpis: %{}, phase: 1, ...}
  """
  @spec get_progress() :: progress()
  def get_progress do
    GenServer.call(__MODULE__, :get_progress)
  end

  @doc """
  Updates the status of an agent.

  ## Parameters

  - `agent_id` - Unique identifier for the agent
  - `status` - One of `:pending`, `:running`, `:completed`, `:failed`
  - `opts` - Optional metadata (keyword list)

  ## Examples

      :ok = ProgressTracker.update_agent_status("agent_1", :running)
      :ok = ProgressTracker.update_agent_status("agent_2", :completed, metadata: %{duration: 100})
  """
  @spec update_agent_status(agent_id(), agent_status(), keyword()) :: :ok
  def update_agent_status(agent_id, status, opts \\ []) do
    # Direct ETS write for <1ms latency (SC-PTR-001)
    metadata = Keyword.get(opts, :metadata, %{})
    now = DateTime.utc_now()

    agent_data = %{
      status: status,
      updated_at: now,
      metadata: metadata
    }

    :ets.insert(@table, {{:agent, agent_id}, agent_data})

    # Async notification to subscribers (SC-PTR-002)
    GenServer.cast(__MODULE__, {:notify_subscribers, :agent_status, agent_id, status})

    :ok
  end

  @doc """
  Updates a KPI metric value.

  ## Parameters

  - `kpi_name` - Name of the KPI metric
  - `value` - Numeric value for the KPI

  ## Examples

      :ok = ProgressTracker.update_kpi("throughput", 1500.5)
      :ok = ProgressTracker.update_kpi("error_rate", 0.02)
  """
  @spec update_kpi(kpi_name(), kpi_value()) :: :ok
  def update_kpi(kpi_name, value) do
    # Direct ETS write for <1ms latency (SC-PTR-001)
    now = DateTime.utc_now()

    kpi_data = %{
      value: value,
      updated_at: now
    }

    :ets.insert(@table, {{:kpi, kpi_name}, kpi_data})

    # Async notification to subscribers
    GenServer.cast(__MODULE__, {:notify_subscribers, :kpi_update, kpi_name, value})

    :ok
  end

  @doc """
  Gets all current KPI values.

  ## Examples

      kpis = ProgressTracker.get_kpis()
      # => %{"throughput" => 1500.5, "error_rate" => 0.02}
  """
  @spec get_kpis() :: %{kpi_name() => kpi_value()}
  def get_kpis do
    @table
    |> :ets.match({{:kpi, :"$1"}, %{value: :"$2", updated_at: :_}})
    |> Enum.reduce(%{}, fn [name, value], acc ->
      Map.put(acc, name, value)
    end)
  end

  @doc """
  Calculates the current completion percentage.

  Returns a float between 0.0 and 100.0 representing the percentage
  of agents/tasks that are in :completed status.

  ## Examples

      percentage = ProgressTracker.get_completion_percentage()
      # => 75.0
  """
  @spec get_completion_percentage() :: float()
  def get_completion_percentage do
    agents = get_all_agents()

    if map_size(agents) == 0 do
      0.0
    else
      completed_count =
        agents
        |> Enum.count(fn {_id, data} -> data.status == :completed end)

      completed_count / map_size(agents) * 100.0
    end
  end

  @doc """
  Subscribes to progress updates.

  Returns a reference that can be used to identify updates.
  Updates are sent as `{:progress_update, %{type: type, ...}}` messages.

  ## Examples

      {:ok, ref} = ProgressTracker.subscribe()
      receive do
        {:progress_update, update} -> IO.inspect(update)
      end
  """
  @spec subscribe() :: {:ok, reference()}
  def subscribe do
    GenServer.call(__MODULE__, :subscribe)
  end

  @doc """
  Unsubscribes from progress updates.

  ## Examples

      {:ok, ref} = ProgressTracker.subscribe()
      :ok = ProgressTracker.unsubscribe(ref)
  """
  @spec unsubscribe(reference()) :: :ok
  def unsubscribe(ref) do
    GenServer.call(__MODULE__, {:unsubscribe, ref})
  end

  @doc """
  Takes a snapshot of the current progress state.

  Snapshots are stored with timestamps and can be retrieved later
  for trend analysis.

  ## Examples

      {:ok, snapshot_id} = ProgressTracker.take_snapshot()
  """
  @spec take_snapshot() :: {:ok, snapshot_id()}
  def take_snapshot do
    GenServer.call(__MODULE__, :take_snapshot)
  end

  @doc """
  Gets all stored snapshots.

  Returns a list of snapshots ordered by timestamp (oldest first).

  ## Examples

      snapshots = ProgressTracker.get_snapshots()
      # => [%{id: "...", timestamp: ~U[...], ...}, ...]
  """
  @spec get_snapshots() :: [snapshot()]
  def get_snapshots do
    @snapshots_table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, snapshot} -> snapshot end)
    |> Enum.sort_by(& &1.timestamp, DateTime)
  end

  @doc """
  Gets a specific snapshot by ID.

  ## Examples

      {:ok, snapshot} = ProgressTracker.get_snapshot("abc123")
      {:error, :not_found} = ProgressTracker.get_snapshot("nonexistent")
  """
  @spec get_snapshot(snapshot_id()) :: {:ok, snapshot()} | {:error, :not_found}
  def get_snapshot(snapshot_id) do
    case :ets.lookup(@snapshots_table, snapshot_id) do
      [{^snapshot_id, snapshot}] -> {:ok, snapshot}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Advances to the next phase (1 -> 2 -> 3).

  Phase cannot exceed 3.

  ## Examples

      :ok = ProgressTracker.advance_phase()
  """
  @spec advance_phase() :: :ok
  def advance_phase do
    GenServer.call(__MODULE__, :advance_phase)
  end

  @doc """
  Resets all tracked data.

  Clears all agents, tasks, KPIs, and snapshots.

  ## Examples

      :ok = ProgressTracker.reset()
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    # Create ETS tables with optimal settings for concurrent access
    create_ets_tables()

    update_interval = Keyword.get(opts, :update_interval_ms, @update_interval_ms)
    max_snapshots = Keyword.get(opts, :max_snapshots, @max_snapshots)

    # Schedule periodic snapshots
    timer_ref = Process.send_after(self(), :periodic_snapshot, update_interval)

    state = %__MODULE__{
      started_at: DateTime.utc_now(),
      last_updated: DateTime.utc_now(),
      phase: 1,
      subscribers: %{},
      snapshot_timer: timer_ref,
      update_interval_ms: update_interval,
      max_snapshots: max_snapshots
    }

    Logger.info("[ProgressTracker] Started with update_interval=#{update_interval}ms")

    {:ok, state}
  end

  @impl true
  def handle_call(:get_progress, _from, state) do
    progress = %{
      agents: get_all_agents(),
      tasks: get_all_tasks(),
      kpis: get_kpis(),
      phase: state.phase,
      started_at: state.started_at,
      last_updated: state.last_updated
    }

    {:reply, progress, state}
  end

  @impl true
  def handle_call(:subscribe, {pid, _ref}, state) do
    ref = Process.monitor(pid)

    subscribers = Map.put(state.subscribers, ref, pid)

    {:reply, {:ok, ref}, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_call({:unsubscribe, ref}, _from, state) do
    Process.demonitor(ref, [:flush])
    subscribers = Map.delete(state.subscribers, ref)

    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_call(:take_snapshot, _from, state) do
    snapshot_id = generate_snapshot_id()

    snapshot = %{
      id: snapshot_id,
      timestamp: DateTime.utc_now(),
      agents: get_all_agents(),
      kpis: get_kpis(),
      phase: state.phase,
      completion_percentage: get_completion_percentage()
    }

    :ets.insert(@snapshots_table, {snapshot_id, snapshot})

    # Prune old snapshots if needed
    prune_snapshots(state.max_snapshots)

    {:reply, {:ok, snapshot_id}, state}
  end

  @impl true
  def handle_call(:advance_phase, _from, state) do
    new_phase = min(state.phase + 1, 3)

    {:reply, :ok, %{state | phase: new_phase, last_updated: DateTime.utc_now()}}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    # Clear all ETS data
    :ets.delete_all_objects(@table)
    :ets.delete_all_objects(@snapshots_table)

    new_state = %{
      state
      | phase: 1,
        started_at: DateTime.utc_now(),
        last_updated: DateTime.utc_now()
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:notify_subscribers, type, key, value}, state) do
    update = %{
      type: type,
      key: key,
      value: value,
      timestamp: DateTime.utc_now()
    }

    # Notify all subscribers asynchronously
    for {_ref, pid} <- state.subscribers do
      send(pid, {:progress_update, update})
    end

    {:noreply, %{state | last_updated: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:periodic_snapshot, state) do
    # Take automatic snapshot
    snapshot_id = generate_snapshot_id()

    snapshot = %{
      id: snapshot_id,
      timestamp: DateTime.utc_now(),
      agents: get_all_agents(),
      kpis: get_kpis(),
      phase: state.phase,
      completion_percentage: get_completion_percentage()
    }

    :ets.insert(@snapshots_table, {snapshot_id, snapshot})
    prune_snapshots(state.max_snapshots)

    # Schedule next snapshot
    timer_ref = Process.send_after(self(), :periodic_snapshot, state.update_interval_ms)

    {:noreply, %{state | snapshot_timer: timer_ref, last_updated: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    # Subscriber process died, remove from subscribers
    subscribers = Map.delete(state.subscribers, ref)

    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def terminate(_reason, state) do
    # Cancel timer
    if state.snapshot_timer do
      Process.cancel_timer(state.snapshot_timer)
    end

    :ok
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp create_ets_tables do
    # Main progress table with concurrent read/write optimization
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    # Snapshots table
    if :ets.whereis(@snapshots_table) == :undefined do
      :ets.new(@snapshots_table, [
        :set,
        :named_table,
        :public,
        read_concurrency: true
      ])
    end
  end

  defp get_all_agents do
    @table
    |> :ets.match({{:agent, :"$1"}, :"$2"})
    |> Enum.reduce(%{}, fn [id, data], acc ->
      Map.put(acc, id, data)
    end)
  end

  defp get_all_tasks do
    @table
    |> :ets.match({{:task, :"$1"}, :"$2"})
    |> Enum.reduce(%{}, fn [id, data], acc ->
      Map.put(acc, id, data)
    end)
  end

  defp generate_snapshot_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    rand_bytes |> Base.encode16(case: :lower)
  end

  defp prune_snapshots(max_snapshots) do
    snapshots = get_snapshots()

    if length(snapshots) > max_snapshots do
      # Remove oldest snapshots
      snapshots
      |> Enum.take(length(snapshots) - max_snapshots)
      |> Enum.each(fn snapshot ->
        :ets.delete(@snapshots_table, snapshot.id)
      end)
    end
  end
end
