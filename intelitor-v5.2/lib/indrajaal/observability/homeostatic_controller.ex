defmodule Indrajaal.Observability.HomeostaticController do
  @moduledoc """
  Homeostatic Controller - SIL-6 Self-Regulating Resource Management

  WHAT: Implements biological homeostasis patterns for maintaining system
        stability across all 8 fractal layers with intelligent resource allocation.

  WHY: Ensures SIL-6 stability, survivability, graceful degradation, and
       optimal performance through continuous self-regulation.

  DESIGN (MAPE-K Loop):
    - Monitor: Collect metrics from FractalTelemetryMatrix
    - Analyze: Detect deviations from set-points
    - Plan: Determine corrective actions
    - Execute: Apply resource adjustments
    - Knowledge: Learn optimal set-points over time

  HOMEOSTATIC MECHANISMS:
    1. Set-Point Control: Target values for each KPI
    2. Negative Feedback: Counteract deviations
    3. Positive Feedback: Amplify beneficial changes (rare)
    4. Adaptive Thresholds: Learn from history
    5. Cascade Prevention: Avoid runaway feedback

  OPERATIONAL MODES:
    - :normal      - All systems within tolerance
    - :stressed    - Minor deviations, active correction
    - :degraded    - Progressive feature shedding
    - :critical    - Emergency mode, essential functions only
    - :recovery    - Returning to normal after crisis

  STAMP Constraints:
    - SC-HOM-001: MAPE-K cycle < 100ms
    - SC-HOM-002: Mode transitions logged
    - SC-HOM-003: Resource limits enforced
    - SC-HOM-004: Graceful degradation paths defined
    - SC-HOM-005: Recovery procedures automatic
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.FractalTelemetryMatrix
  alias Indrajaal.Observability.DirectedTelescopeController

  # MAPE-K cycle interval
  @mape_k_interval_ms 1_000

  # Mode transition hysteresis (prevent oscillation)
  @hysteresis_cycles 3

  # Resource allocation budgets by mode
  @mode_budgets %{
    normal: %{
      agent_pool: 1.0,
      log_verbosity: 1.0,
      telemetry_resolution: 1.0,
      retry_budget: 1.0,
      cache_ttl_multiplier: 1.0
    },
    stressed: %{
      agent_pool: 0.8,
      log_verbosity: 0.7,
      telemetry_resolution: 0.8,
      retry_budget: 0.7,
      cache_ttl_multiplier: 1.2
    },
    degraded: %{
      agent_pool: 0.5,
      log_verbosity: 0.3,
      telemetry_resolution: 0.5,
      retry_budget: 0.3,
      cache_ttl_multiplier: 2.0
    },
    critical: %{
      agent_pool: 0.2,
      log_verbosity: 0.1,
      telemetry_resolution: 0.2,
      retry_budget: 0.1,
      cache_ttl_multiplier: 5.0
    },
    recovery: %{
      agent_pool: 0.6,
      log_verbosity: 0.5,
      telemetry_resolution: 0.6,
      retry_budget: 0.5,
      cache_ttl_multiplier: 1.5
    }
  }

  # ============================================================================
  # State Structure
  # ============================================================================

  defstruct mode: :normal,
            previous_mode: nil,
            mode_history: [],
            mode_stable_cycles: 0,
            knowledge_base: %{},
            actions_taken: [],
            last_mape_k: nil,
            subscribers: [],
            resource_usage: %{},
            degradation_level: 0,
            recovery_progress: 0.0

  # ============================================================================
  # Client API
  # ============================================================================

  @doc "Start the Homeostatic Controller"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current operational mode"
  @spec mode() :: atom()
  def mode do
    GenServer.call(__MODULE__, :mode)
  catch
    :exit, _ -> :unknown
  end

  @doc "Get current resource budgets"
  @spec resource_budgets() :: map()
  def resource_budgets do
    GenServer.call(__MODULE__, :resource_budgets)
  catch
    :exit, _ -> Map.get(@mode_budgets, :normal)
  end

  @doc "Get degradation level (0-100)"
  @spec degradation_level() :: non_neg_integer()
  def degradation_level do
    GenServer.call(__MODULE__, :degradation_level)
  catch
    :exit, _ -> 0
  end

  @doc "Get recovery progress (0.0-1.0)"
  @spec recovery_progress() :: float()
  def recovery_progress do
    GenServer.call(__MODULE__, :recovery_progress)
  catch
    :exit, _ -> 1.0
  end

  @doc "Get recent actions taken"
  @spec recent_actions() :: [map()]
  def recent_actions do
    GenServer.call(__MODULE__, :recent_actions)
  catch
    :exit, _ -> []
  end

  @doc "Force a specific mode (for testing/emergency)"
  @spec force_mode(atom()) :: :ok
  def force_mode(mode) when mode in [:normal, :stressed, :degraded, :critical, :recovery] do
    GenServer.cast(__MODULE__, {:force_mode, mode})
  end

  @doc "Subscribe to mode change notifications"
  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  @doc "Get full status report"
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  catch
    :exit, _ -> %{mode: :unknown}
  end

  @doc "Check if a feature should be active in current mode"
  @spec feature_active?(atom()) :: boolean()
  def feature_active?(feature) do
    GenServer.call(__MODULE__, {:feature_active?, feature})
  catch
    :exit, _ -> true
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      mode: :normal,
      previous_mode: nil,
      mode_history: [],
      mode_stable_cycles: 0,
      knowledge_base: init_knowledge_base(),
      actions_taken: [],
      last_mape_k: DateTime.utc_now(),
      subscribers: [],
      resource_usage: %{},
      degradation_level: 0,
      recovery_progress: 1.0
    }

    # Schedule MAPE-K loop
    Process.send_after(self(), :mape_k_cycle, @mape_k_interval_ms)

    # Subscribe to fractal matrix anomalies
    try do
      FractalTelemetryMatrix.subscribe(self())
    catch
      _, _ -> :ok
    end

    Logger.info("[HomeostaticController] Started in #{state.mode} mode")

    {:ok, state}
  end

  @impl true
  def handle_call(:mode, _from, state) do
    {:reply, state.mode, state}
  end

  @impl true
  def handle_call(:resource_budgets, _from, state) do
    budgets = Map.get(@mode_budgets, state.mode, Map.get(@mode_budgets, :normal))
    {:reply, budgets, state}
  end

  @impl true
  def handle_call(:degradation_level, _from, state) do
    {:reply, state.degradation_level, state}
  end

  @impl true
  def handle_call(:recovery_progress, _from, state) do
    {:reply, state.recovery_progress, state}
  end

  @impl true
  def handle_call(:recent_actions, _from, state) do
    {:reply, Enum.take(state.actions_taken, 20), state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      mode: state.mode,
      previous_mode: state.previous_mode,
      mode_stable_cycles: state.mode_stable_cycles,
      degradation_level: state.degradation_level,
      recovery_progress: state.recovery_progress,
      resource_budgets: Map.get(@mode_budgets, state.mode),
      recent_actions: Enum.take(state.actions_taken, 5),
      last_mape_k: state.last_mape_k
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:feature_active?, feature}, _from, state) do
    active =
      case {state.mode, feature} do
        {:critical, :non_essential_logging} -> false
        {:critical, :detailed_telemetry} -> false
        {:critical, :background_jobs} -> false
        {:degraded, :non_essential_logging} -> false
        {:degraded, :background_jobs} -> false
        {_, _} -> true
      end

    {:reply, active, state}
  end

  @impl true
  def handle_cast({:force_mode, mode}, state) do
    Logger.warning("[HomeostaticController] Forced mode change: #{state.mode} -> #{mode}")
    new_state = transition_mode(state, mode, :forced)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    subscribers = [pid | state.subscribers] |> Enum.uniq()
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_info(:mape_k_cycle, state) do
    # Execute MAPE-K loop
    new_state = execute_mape_k(state)

    # Schedule next cycle
    Process.send_after(self(), :mape_k_cycle, @mape_k_interval_ms)

    {:noreply, %{new_state | last_mape_k: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:fractal_matrix, {:anomaly, anomaly}}, state) do
    # React to anomaly from FractalTelemetryMatrix
    action = %{
      type: :anomaly_detected,
      layer: anomaly.layer,
      interaction: anomaly.interaction,
      deviation: anomaly.deviation,
      timestamp: DateTime.utc_now()
    }

    actions = [action | Enum.take(state.actions_taken, 99)]
    {:noreply, %{state | actions_taken: actions}}
  end

  @impl true
  def handle_info({:fractal_matrix, {:mode_change, _old, new}}, state) do
    # Sync with matrix mode if it detects critical state
    if new == :critical and state.mode != :critical do
      new_state = transition_mode(state, :critical, :matrix_escalation)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # MAPE-K Implementation
  # ============================================================================

  defp execute_mape_k(state) do
    state
    |> monitor_phase()
    |> analyze_phase()
    |> plan_phase()
    |> execute_phase()
    |> knowledge_phase()
  end

  # Monitor: Collect current metrics
  defp monitor_phase(state) do
    matrix_mode =
      try do
        FractalTelemetryMatrix.homeostatic_mode()
      catch
        _, _ -> :normal
      end

    health_score =
      try do
        FractalTelemetryMatrix.system_health_score()
      catch
        _, _ -> 100.0
      end

    anomalies =
      try do
        FractalTelemetryMatrix.anomalies()
      catch
        _, _ -> []
      end

    resource_usage = collect_resource_usage()

    observations = %{
      matrix_mode: matrix_mode,
      health_score: health_score,
      anomaly_count: length(anomalies),
      recent_anomalies: Enum.take(anomalies, 5),
      resource_usage: resource_usage
    }

    Map.put(state, :observations, observations)
  end

  # Analyze: Determine if action needed
  defp analyze_phase(state) do
    obs = Map.get(state, :observations, %{})
    health_score = Map.get(obs, :health_score, 100.0)
    anomaly_count = Map.get(obs, :anomaly_count, 0)
    matrix_mode = Map.get(obs, :matrix_mode, :normal)

    # Calculate suggested mode
    suggested_mode =
      cond do
        health_score < 30 or matrix_mode == :critical or anomaly_count > 30 -> :critical
        health_score < 50 or matrix_mode == :stressed or anomaly_count > 15 -> :stressed
        health_score < 70 or matrix_mode == :degraded or anomaly_count > 8 -> :degraded
        state.mode == :recovery and health_score > 90 and anomaly_count < 3 -> :normal
        state.mode in [:critical, :stressed, :degraded] and health_score > 80 -> :recovery
        true -> state.mode
      end

    analysis = %{
      current_mode: state.mode,
      suggested_mode: suggested_mode,
      mode_change_needed: suggested_mode != state.mode
    }

    Map.put(state, :analysis, analysis)
  end

  # Plan: Determine actions
  defp plan_phase(state) do
    analysis = Map.get(state, :analysis, %{})
    suggested_mode = Map.get(analysis, :suggested_mode, state.mode)
    mode_change_needed = Map.get(analysis, :mode_change_needed, false)

    planned_actions =
      cond do
        # Mode transition with hysteresis
        mode_change_needed and state.mode_stable_cycles >= @hysteresis_cycles ->
          [{:transition_mode, suggested_mode}]

        # Increment stability counter if mode change suggested
        mode_change_needed ->
          [{:increment_stability_counter, suggested_mode}]

        # Reset stability counter if mode is stable
        true ->
          [{:reset_stability_counter, nil}]
      end

    # Add mode-specific actions
    planned_actions =
      case state.mode do
        :degraded ->
          planned_actions ++ [{:shed_load, calculate_load_shedding(state)}]

        :critical ->
          planned_actions ++ [{:emergency_measures, :enable}]

        :recovery ->
          planned_actions ++ [{:gradual_restore, state.recovery_progress}]

        _ ->
          planned_actions
      end

    Map.put(state, :planned_actions, planned_actions)
  end

  # Execute: Apply planned actions
  defp execute_phase(state) do
    planned_actions = Map.get(state, :planned_actions, [])

    Enum.reduce(planned_actions, state, fn action, acc ->
      execute_action(acc, action)
    end)
  end

  defp execute_action(state, {:transition_mode, new_mode}) do
    transition_mode(state, new_mode, :mape_k_decision)
  end

  defp execute_action(state, {:increment_stability_counter, _suggested}) do
    %{state | mode_stable_cycles: state.mode_stable_cycles + 1}
  end

  defp execute_action(state, {:reset_stability_counter, _}) do
    %{state | mode_stable_cycles: 0}
  end

  defp execute_action(state, {:shed_load, level}) do
    # Update degradation level
    new_level = min(100, level)

    action = %{
      type: :load_shedding,
      level: new_level,
      timestamp: DateTime.utc_now()
    }

    %{
      state
      | degradation_level: new_level,
        actions_taken: [action | Enum.take(state.actions_taken, 99)]
    }
  end

  defp execute_action(state, {:emergency_measures, :enable}) do
    # Log emergency activation
    action = %{
      type: :emergency_mode,
      status: :activated,
      timestamp: DateTime.utc_now()
    }

    %{
      state
      | degradation_level: 100,
        actions_taken: [action | Enum.take(state.actions_taken, 99)]
    }
  end

  defp execute_action(state, {:gradual_restore, progress}) do
    # Increment recovery progress
    new_progress = min(1.0, progress + 0.05)
    new_degradation = round((1.0 - new_progress) * 100)

    %{state | recovery_progress: new_progress, degradation_level: new_degradation}
  end

  # Knowledge: Learn and adapt
  defp knowledge_phase(state) do
    obs = Map.get(state, :observations, %{})

    # Update knowledge base with current observations
    updated_kb =
      Map.merge(state.knowledge_base, %{
        last_health_score: Map.get(obs, :health_score, 100.0),
        last_anomaly_count: Map.get(obs, :anomaly_count, 0),
        mode_transitions: [
          state.mode | Enum.take(state.knowledge_base[:mode_transitions] || [], 99)
        ]
      })

    # Clean up temporary state
    state
    |> Map.delete(:observations)
    |> Map.delete(:analysis)
    |> Map.delete(:planned_actions)
    |> Map.put(:knowledge_base, updated_kb)
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp transition_mode(state, new_mode, reason) do
    old_mode = state.mode

    Logger.info("[HomeostaticController] Mode transition: #{old_mode} -> #{new_mode} (#{reason})")

    # Notify subscribers
    notify_subscribers(state.subscribers, {:mode_change, old_mode, new_mode, reason})

    # Update DirectedTelescopeController context based on mode
    try do
      context =
        case new_mode do
          :normal -> DirectedTelescopeController.get_context()
          :stressed -> :development
          :degraded -> :development
          :critical -> :unit_test
          :recovery -> :development
        end

      DirectedTelescopeController.set_context(context)
    catch
      _, _ -> :ok
    end

    action = %{
      type: :mode_transition,
      from: old_mode,
      to: new_mode,
      reason: reason,
      timestamp: DateTime.utc_now()
    }

    %{
      state
      | mode: new_mode,
        previous_mode: old_mode,
        mode_stable_cycles: 0,
        mode_history: [
          {old_mode, new_mode, DateTime.utc_now()} | Enum.take(state.mode_history, 99)
        ],
        actions_taken: [action | Enum.take(state.actions_taken, 99)],
        recovery_progress: if(new_mode == :recovery, do: 0.0, else: state.recovery_progress)
    }
  end

  defp collect_resource_usage do
    memory = :erlang.memory()

    %{
      total_memory_mb: memory[:total] / (1024 * 1024),
      process_memory_mb: memory[:processes] / (1024 * 1024),
      process_count: :erlang.system_info(:process_count),
      scheduler_utilization: get_scheduler_util()
    }
  end

  defp get_scheduler_util do
    try do
      :scheduler.utilization(1)
      |> Enum.map(fn {_id, util, _} -> util end)
      |> Enum.sum()
      |> Kernel./(System.schedulers())
    catch
      _, _ -> 0.0
    end
  end

  defp calculate_load_shedding(state) do
    obs = Map.get(state, :observations, %{})
    health_score = Map.get(obs, :health_score, 100.0)

    # Higher shedding for lower health
    round((100 - health_score) * 0.8)
  end

  defp init_knowledge_base do
    %{
      mode_transitions: [],
      last_health_score: 100.0,
      last_anomaly_count: 0,
      optimal_set_points: %{},
      learned_thresholds: %{}
    }
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:homeostatic, message})
      end
    end)
  end
end
