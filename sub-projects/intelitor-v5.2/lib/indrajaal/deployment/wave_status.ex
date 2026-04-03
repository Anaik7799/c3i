defmodule Indrajaal.Deployment.WaveStatus do
  @moduledoc """
  Wave Status Tracker - Real-time wave progress tracking with ETS

  WHAT: Tracks boot wave execution progress in real-time using ETS for
        fast reads and Phoenix.PubSub for live status broadcast.
  WHY: Provides L4-layer (Container) observability for wave-based deployment
       sequencing per SC-BOOT-009 (waves boot in parallel) and SC-SIL4-012
       (5 startup phases MANDATORY).

  ## State Model
  Each wave transitions through these phases:
  `pending` → `starting` → `running` → `succeeded` | `failed` | `timeout`

  ## ETS Table
  `:wave_progress` holds `{wave_order, wave_progress_entry}` tuples for
  fast non-blocking reads from any process (SC-DBLOCAL-002: latency < 1ms).

  ## STAMP Constraints
  - SC-BOOT-009: Waves boot in parallel — status reflects parallel execution
  - SC-BOOT-010: Checkpoints at each stage
  - SC-SIL4-012: 5 startup phases MANDATORY — wave_order maps to phases
  - SC-CTRL-001: System status available in real-time
  - SC-MON-001: Metrics refresh every 30s
  """

  use GenServer
  require Logger

  alias Indrajaal.Deployment.StartupWave

  @pubsub Indrajaal.PubSub
  @topic "deployment:wave_status"
  @ets_table :wave_progress

  # ============================================================================
  # Types
  # ============================================================================

  @type wave_phase ::
          :pending | :starting | :running | :succeeded | :failed | :timeout | :skipped

  @type wave_progress :: %{
          wave_order: pos_integer(),
          phase: wave_phase(),
          containers: [String.t()],
          containers_started: [String.t()],
          containers_failed: [String.t()],
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          duration_ms: non_neg_integer() | nil,
          error: String.t() | nil,
          metadata: map()
        }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the WaveStatus GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initializes tracking for a list of startup waves before execution begins.
  """
  @spec initialize_waves([StartupWave.t()]) :: :ok
  def initialize_waves(waves) when is_list(waves) do
    GenServer.call(__MODULE__, {:initialize_waves, waves})
  end

  @doc """
  Records the start of a wave execution.
  """
  @spec wave_started(pos_integer(), [String.t()]) :: :ok
  def wave_started(wave_order, containers) do
    GenServer.cast(__MODULE__, {:wave_started, wave_order, containers})
  end

  @doc """
  Records a single container completing startup within a wave.
  """
  @spec container_started(pos_integer(), String.t()) :: :ok
  def container_started(wave_order, container_name) do
    GenServer.cast(__MODULE__, {:container_started, wave_order, container_name})
  end

  @doc """
  Records a container failing to start within a wave.
  """
  @spec container_failed(pos_integer(), String.t(), String.t()) :: :ok
  def container_failed(wave_order, container_name, reason) do
    GenServer.cast(__MODULE__, {:container_failed, wave_order, container_name, reason})
  end

  @doc """
  Marks a wave as fully complete (all containers started).
  """
  @spec wave_completed(pos_integer()) :: :ok
  def wave_completed(wave_order) do
    GenServer.cast(__MODULE__, {:wave_completed, wave_order})
  end

  @doc """
  Marks a wave as failed.
  """
  @spec wave_failed(pos_integer(), String.t()) :: :ok
  def wave_failed(wave_order, reason) do
    GenServer.cast(__MODULE__, {:wave_failed, wave_order, reason})
  end

  @doc """
  Marks a wave as timed out.
  """
  @spec wave_timeout(pos_integer()) :: :ok
  def wave_timeout(wave_order) do
    GenServer.cast(__MODULE__, {:wave_timeout, wave_order})
  end

  @doc """
  Returns progress for a specific wave.
  """
  @spec get_wave_progress(pos_integer()) :: {:ok, wave_progress()} | {:error, :not_found}
  def get_wave_progress(wave_order) do
    ensure_ets_table()

    case :ets.lookup(@ets_table, wave_order) do
      [{^wave_order, progress}] -> {:ok, progress}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns progress for all waves.
  """
  @spec all_waves_progress() :: [wave_progress()]
  def all_waves_progress do
    ensure_ets_table()

    :ets.tab2list(@ets_table)
    |> Enum.map(fn {_order, progress} -> progress end)
    |> Enum.sort_by(& &1.wave_order)
  end

  @doc """
  Returns overall boot progress as a percentage (0–100).
  """
  @spec boot_progress_percent() :: non_neg_integer()
  def boot_progress_percent do
    waves = all_waves_progress()

    case waves do
      [] ->
        0

      _ ->
        completed = Enum.count(waves, &(&1.phase in [:succeeded, :skipped]))
        round(completed / length(waves) * 100)
    end
  end

  @doc """
  Returns `true` if all waves have completed (succeeded or skipped).
  """
  @spec all_waves_complete?() :: boolean()
  def all_waves_complete? do
    waves = all_waves_progress()
    waves != [] and Enum.all?(waves, &(&1.phase in [:succeeded, :skipped, :failed]))
  end

  @doc """
  Returns WaveStatus tracker status and statistics.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    ensure_ets_table()

    state = %{
      started_at: DateTime.utc_now(),
      total_waves: 0,
      event_count: 0
    }

    Logger.info("[WaveStatus] Tracker initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:initialize_waves, waves}, _from, state) do
    Enum.each(waves, fn wave ->
      progress = initial_progress(wave)
      :ets.insert(@ets_table, {wave.order, progress})
    end)

    new_state = %{state | total_waves: length(waves)}

    broadcast_event(:waves_initialized, %{
      wave_count: length(waves),
      wave_orders: Enum.map(waves, & &1.order)
    })

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    waves = all_waves_progress()

    status = %{
      started_at: state.started_at,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      total_waves: state.total_waves,
      event_count: state.event_count,
      boot_progress_percent: boot_progress_percent(),
      all_complete: all_waves_complete?(),
      waves_by_phase: Enum.group_by(waves, & &1.phase) |> Map.new(fn {k, v} -> {k, length(v)} end)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:wave_started, wave_order, containers}, state) do
    now = DateTime.utc_now()

    update_wave(wave_order, fn progress ->
      %{progress | phase: :running, containers: containers, started_at: now}
    end)

    broadcast_event(:wave_started, %{wave_order: wave_order, containers: containers})

    Logger.info("[WaveStatus] Wave #{wave_order} started with #{length(containers)} containers")

    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  @impl true
  def handle_cast({:container_started, wave_order, container_name}, state) do
    update_wave(wave_order, fn progress ->
      already = progress.containers_started

      updated_started =
        if container_name in already, do: already, else: [container_name | already]

      # Auto-complete wave if all containers started
      all_started = length(updated_started) >= length(progress.containers)
      new_phase = if all_started, do: :succeeded, else: progress.phase
      completed_at = if all_started, do: DateTime.utc_now(), else: nil
      started_at = progress.started_at

      duration_ms =
        if all_started and started_at != nil do
          DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
        else
          nil
        end

      %{
        progress
        | containers_started: updated_started,
          phase: new_phase,
          completed_at: completed_at,
          duration_ms: duration_ms
      }
    end)

    broadcast_event(:container_started, %{
      wave_order: wave_order,
      container: container_name
    })

    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  @impl true
  def handle_cast({:container_failed, wave_order, container_name, reason}, state) do
    update_wave(wave_order, fn progress ->
      already = progress.containers_failed
      updated = if container_name in already, do: already, else: [container_name | already]
      %{progress | containers_failed: updated, error: reason}
    end)

    broadcast_event(:container_failed, %{
      wave_order: wave_order,
      container: container_name,
      reason: reason
    })

    Logger.warning(
      "[WaveStatus] Container #{container_name} failed in wave #{wave_order}: #{reason}"
    )

    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  @impl true
  def handle_cast({:wave_completed, wave_order}, state) do
    now = DateTime.utc_now()

    update_wave(wave_order, fn progress ->
      started_at = progress.started_at

      duration_ms =
        if started_at != nil,
          do: DateTime.diff(now, started_at, :millisecond),
          else: nil

      %{progress | phase: :succeeded, completed_at: now, duration_ms: duration_ms}
    end)

    broadcast_event(:wave_completed, %{wave_order: wave_order})

    Logger.info("[WaveStatus] Wave #{wave_order} completed")

    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  @impl true
  def handle_cast({:wave_failed, wave_order, reason}, state) do
    now = DateTime.utc_now()

    update_wave(wave_order, fn progress ->
      started_at = progress.started_at

      duration_ms =
        if started_at != nil,
          do: DateTime.diff(now, started_at, :millisecond),
          else: nil

      %{progress | phase: :failed, completed_at: now, duration_ms: duration_ms, error: reason}
    end)

    broadcast_event(:wave_failed, %{wave_order: wave_order, reason: reason})

    Logger.error("[WaveStatus] Wave #{wave_order} FAILED: #{reason}")

    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  @impl true
  def handle_cast({:wave_timeout, wave_order}, state) do
    now = DateTime.utc_now()

    update_wave(wave_order, fn progress ->
      started_at = progress.started_at

      duration_ms =
        if started_at != nil,
          do: DateTime.diff(now, started_at, :millisecond),
          else: nil

      %{
        progress
        | phase: :timeout,
          completed_at: now,
          duration_ms: duration_ms,
          error: "Wave timed out"
      }
    end)

    broadcast_event(:wave_timeout, %{wave_order: wave_order})

    Logger.error("[WaveStatus] Wave #{wave_order} TIMED OUT")

    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  # ============================================================================
  # Private helpers
  # ============================================================================

  defp ensure_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])

      _ref ->
        @ets_table
    end
  end

  defp initial_progress(%StartupWave{order: order, containers: containers}) do
    %{
      wave_order: order,
      phase: :pending,
      containers: containers,
      containers_started: [],
      containers_failed: [],
      started_at: nil,
      completed_at: nil,
      duration_ms: nil,
      error: nil,
      metadata: %{}
    }
  end

  defp update_wave(wave_order, update_fn) do
    case :ets.lookup(@ets_table, wave_order) do
      [{^wave_order, progress}] ->
        updated = update_fn.(progress)
        :ets.insert(@ets_table, {wave_order, updated})

      [] ->
        Logger.warning("[WaveStatus] Unknown wave order: #{wave_order}")
    end
  end

  defp broadcast_event(event_type, payload) do
    message = {:wave_event, event_type, payload}
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  end
end
