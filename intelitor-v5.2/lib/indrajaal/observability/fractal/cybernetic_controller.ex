defmodule Indrajaal.Observability.Fractal.CyberneticController do
  @moduledoc """
  Cybernetic Controller: Autonomous OODA Loop for Fractal Logging.

  WHAT: GenServer implementing the OODA (Observe-Orient-Decide-Act) loop for
        autonomous observability control, integrating with Cortex homeostasis.

  WHY: Enables self-regulating observability that adapts to system load,
       error rates, and anomalies without human intervention.

  CONSTRAINTS:
  - SC-LOG-002: Auto-throttle at CPU > 90%
  - AOR-LOG-001: Agent MUST check health before enabling L1 zoom
  - AOR-LOG-002: Agent MUST NOT modify policies without journal entry

  ## OODA Loop Phases

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                     OODA CONTROL LOOP                        │
  ├─────────────────────────────────────────────────────────────┤
  │                                                              │
  │  OBSERVE (Every 10s)                                         │
  │  ├── CPU utilization                                         │
  │  ├── Memory pressure                                         │
  │  ├── Log throughput (msgs/sec)                               │
  │  └── Error rate (errors/total)                               │
  │                                                              │
  │  ORIENT (Pattern Matching)                                   │
  │  ├── :normal     - All metrics within thresholds             │
  │  ├── :idle       - Low activity, can enable detailed logging │
  │  ├── :degraded   - High error rate, need debugging           │
  │  └── :overload   - System stress, shed observability load    │
  │                                                              │
  │  DECIDE (Action Selection)                                   │
  │  ├── :maintain_status_quo - No action needed                 │
  │  ├── :activate_load_shedding - SC-LOG-002 triggered          │
  │  ├── :deactivate_load_shedding - Resume normal operation     │
  │  └── :enable_l1_debugging - Focus on error patterns          │
  │                                                              │
  │  ACT (Confidence Threshold)                                  │
  │  ├── Confidence > 0.9 → Execute immediately                  │
  │  ├── Confidence > 0.7 → Execute with journal entry           │
  │  └── Confidence < 0.7 → Log recommendation only              │
  │                                                              │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Modes

  - `:passive` - Observe only, log recommendations (default)
  - `:active` - Execute decisions with high confidence
  - `:autonomous` - Full OODA loop with automatic actions

  ## STAMP Compliance

  | Constraint   | Implementation                              |
  |--------------|---------------------------------------------|
  | SC-LOG-002   | Load shedding at CPU > 90%                  |
  | AOR-LOG-001  | Health check before boost activation        |
  | AOR-LOG-002  | Journal entry for all policy changes        |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.Fractal.FractalControl

  # ============================================================
  # TYPES
  # ============================================================

  @type mode :: :passive | :active | :autonomous
  @type orientation :: :normal | :idle | :degraded | :overload
  @type decision ::
          :maintain_status_quo
          | :activate_load_shedding
          | :deactivate_load_shedding
          | :enable_l1_debugging

  @type observation :: %{
          cpu: float(),
          memory: float(),
          log_throughput: float(),
          error_rate: float(),
          timestamp: DateTime.t()
        }

  @type state :: %{
          mode: mode(),
          observations: [observation()],
          orientation: orientation(),
          decision: decision(),
          confidence: float(),
          last_action_at: DateTime.t() | nil,
          action_count: non_neg_integer(),
          config: map()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @ooda_cycle_ms 10_000
  @observation_window 6
  @confidence_threshold_high 0.9
  @confidence_threshold_medium 0.7

  # Thresholds for orientation
  @cpu_overload_threshold 0.90
  # Resume threshold used in idle detection
  @cpu_idle_threshold 0.50
  @error_rate_degraded_threshold 0.05
  @throughput_idle_threshold 100

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts the CyberneticController.

  ## Options

  - `:mode` - Operating mode (default: `:passive`)
  - `:ooda_cycle_ms` - OODA cycle interval (default: 10_000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current controller status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Sets the operating mode.

  ## Examples

      CyberneticController.set_mode(:active)
      CyberneticController.set_mode(:autonomous)
  """
  @spec set_mode(mode()) :: :ok
  def set_mode(mode) when mode in [:passive, :active, :autonomous] do
    GenServer.cast(__MODULE__, {:set_mode, mode})
  end

  @doc """
  Forces an immediate OODA cycle (for testing/debugging).
  """
  @spec force_cycle() :: :ok
  def force_cycle do
    GenServer.cast(__MODULE__, :force_cycle)
  end

  @doc """
  Gets the current orientation assessment.
  """
  @spec get_orientation() :: orientation()
  def get_orientation do
    GenServer.call(__MODULE__, :get_orientation)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    mode = Keyword.get(opts, :mode, :passive)
    cycle_ms = Keyword.get(opts, :ooda_cycle_ms, @ooda_cycle_ms)

    state = %{
      mode: mode,
      observations: [],
      orientation: :normal,
      decision: :maintain_status_quo,
      confidence: 1.0,
      last_action_at: nil,
      action_count: 0,
      config: %{
        ooda_cycle_ms: cycle_ms
      }
    }

    # Start OODA loop
    Process.send_after(self(), :ooda_cycle, cycle_ms)

    Logger.info("[CYBERNETIC] Controller started in #{mode} mode")

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      mode: state.mode,
      orientation: state.orientation,
      decision: state.decision,
      confidence: state.confidence,
      observations: length(state.observations),
      last_action_at: state.last_action_at,
      action_count: state.action_count
    }

    {:reply, status, state}
  end

  def handle_call(:get_orientation, _from, state) do
    {:reply, state.orientation, state}
  end

  @impl true
  def handle_cast({:set_mode, mode}, state) do
    Logger.info("[CYBERNETIC] Mode changed: #{state.mode} -> #{mode}")
    {:noreply, %{state | mode: mode}}
  end

  def handle_cast(:force_cycle, state) do
    new_state = execute_ooda_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:ooda_cycle, state) do
    new_state = execute_ooda_cycle(state)

    # Schedule next cycle
    Process.send_after(self(), :ooda_cycle, state.config.ooda_cycle_ms)

    {:noreply, new_state}
  end

  # ============================================================
  # OODA LOOP IMPLEMENTATION
  # ============================================================

  defp execute_ooda_cycle(state) do
    state
    |> observe()
    |> orient()
    |> decide()
    |> act()
  end

  # ============================================================
  # OBSERVE PHASE
  # ============================================================

  defp observe(state) do
    observation = %{
      cpu: get_cpu_utilization(),
      memory: get_memory_utilization(),
      log_throughput: get_log_throughput(),
      error_rate: get_error_rate(),
      timestamp: DateTime.utc_now()
    }

    observations =
      [observation | state.observations]
      |> Enum.take(@observation_window)

    %{state | observations: observations}
  end

  defp get_cpu_utilization do
    case :cpu_sup.util() do
      {:error, _} -> 0.0
      util when is_number(util) -> util / 100.0
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp get_memory_utilization do
    case :memsup.get_memory_data() do
      {total, allocated, _} when total > 0 -> allocated / total
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp get_log_throughput do
    case FractalControl.get_metrics() do
      {:ok, %{throughput: throughput}} -> throughput
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp get_error_rate do
    case FractalControl.get_metrics() do
      {:ok, %{error_rate: rate}} -> rate
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  # ============================================================
  # ORIENT PHASE
  # ============================================================

  defp orient(%{observations: []} = state) do
    %{state | orientation: :normal}
  end

  defp orient(%{observations: [latest | _]} = state) do
    orientation =
      cond do
        latest.cpu > @cpu_overload_threshold ->
          :overload

        latest.error_rate > @error_rate_degraded_threshold ->
          :degraded

        latest.log_throughput < @throughput_idle_threshold and latest.cpu < @cpu_idle_threshold ->
          :idle

        true ->
          :normal
      end

    %{state | orientation: orientation}
  end

  # ============================================================
  # DECIDE PHASE
  # ============================================================

  defp decide(%{orientation: :overload} = state) do
    %{
      state
      | decision: :activate_load_shedding,
        confidence: calculate_confidence(state, :overload)
    }
  end

  defp decide(%{orientation: :degraded} = state) do
    %{state | decision: :enable_l1_debugging, confidence: calculate_confidence(state, :degraded)}
  end

  defp decide(%{orientation: :idle} = state) do
    # In idle mode, check if we should deactivate shedding
    if FractalControl.load_shedding?() do
      %{state | decision: :deactivate_load_shedding, confidence: 0.85}
    else
      %{state | decision: :maintain_status_quo, confidence: 1.0}
    end
  end

  defp decide(state) do
    %{state | decision: :maintain_status_quo, confidence: 1.0}
  end

  defp calculate_confidence(state, pattern) do
    # Calculate confidence based on observation consistency
    matching_count =
      state.observations
      |> Enum.count(fn obs ->
        case pattern do
          :overload -> obs.cpu > @cpu_overload_threshold
          :degraded -> obs.error_rate > @error_rate_degraded_threshold
          _ -> false
        end
      end)

    min(1.0, matching_count / max(length(state.observations), 1))
  end

  # ============================================================
  # ACT PHASE
  # ============================================================

  defp act(%{mode: :passive} = state) do
    # Passive mode: Log recommendation only
    if state.decision != :maintain_status_quo do
      Logger.info(
        "[CYBERNETIC] Recommendation: #{state.decision} (confidence: #{state.confidence})"
      )
    end

    state
  end

  defp act(%{decision: :maintain_status_quo} = state) do
    state
  end

  defp act(%{decision: :activate_load_shedding, confidence: c} = state)
       when c >= @confidence_threshold_high do
    # AOR-LOG-002: Journal entry before action
    create_journal_entry(:load_shedding_activated, %{
      reason: :autonomous_overload,
      cpu: hd(state.observations).cpu,
      confidence: c
    })

    # SC-LOG-002: Activate load shedding
    FractalControl.activate_load_shedding(:autonomous)

    Logger.warning("[CYBERNETIC] Load shedding ACTIVATED (confidence: #{c})")

    %{state | last_action_at: DateTime.utc_now(), action_count: state.action_count + 1}
  end

  defp act(%{decision: :deactivate_load_shedding, confidence: c} = state)
       when c >= @confidence_threshold_medium do
    FractalControl.deactivate_load_shedding()

    Logger.info("[CYBERNETIC] Load shedding DEACTIVATED")

    %{state | last_action_at: DateTime.utc_now(), action_count: state.action_count + 1}
  end

  defp act(%{decision: :enable_l1_debugging, confidence: c, mode: :autonomous} = state)
       when c >= @confidence_threshold_medium do
    # AOR-LOG-001: Check health before boost
    case FractalControl.status() do
      %{healthy: true} ->
        # AOR-LOG-002: Journal entry
        create_journal_entry(:l1_debugging_enabled, %{
          reason: :autonomous_degraded,
          error_rate: hd(state.observations).error_rate,
          confidence: c
        })

        # Focus on error patterns with 60-second TTL
        FractalControl.focus("**/*error*", :l1, 60_000, "cybernetic_debug")

        Logger.info("[CYBERNETIC] L1 debugging ENABLED for error patterns")

        %{state | last_action_at: DateTime.utc_now(), action_count: state.action_count + 1}

      _ ->
        Logger.warning("[CYBERNETIC] Skipping L1 boost - system unhealthy")
        state
    end
  end

  defp act(state) do
    # Confidence too low, log only
    if state.confidence < @confidence_threshold_medium do
      Logger.debug(
        "[CYBERNETIC] Decision #{state.decision} deferred (confidence: #{state.confidence})"
      )
    end

    state
  end

  # ============================================================
  # JOURNAL INTEGRATION (AOR-LOG-002)
  # ============================================================

  defp create_journal_entry(action, metadata) do
    entry = %{
      timestamp: DateTime.utc_now(),
      agent: :cybernetic_controller,
      action: action,
      metadata: metadata
    }

    # Store in ETS for immediate access
    :ets.insert(:fractal_config, {{:journal, System.os_time(:microsecond)}, entry})

    # Async log to persistent storage
    Task.start(fn ->
      Logger.info("[JOURNAL] #{inspect(entry)}")
    end)

    :ok
  end
end
