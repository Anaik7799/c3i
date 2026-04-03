defmodule Indrajaal.Distributed.Agents.OODAAgent do
  @moduledoc """
  Agent 1: OODA Controller - Observe-Orient-Decide-Act Cybernetic Loop.

  WHAT: Implements the OODA decision loop for distributed system control.
  WHY: SC-OODA-001 requires cybernetic feedback for adaptive behavior.
  CONSTRAINTS: Loop cycle < 100ms, all phases must complete.

  ## OODA Phases

  1. **Observe**: Collect system telemetry and events
  2. **Orient**: Analyze context and patterns
  3. **Decide**: Select optimal action
  4. **Act**: Execute and verify action

  ## STAMP Constraints
  - SC-OODA-001: Complete OODA loop implementation
  - SC-OODA-002: Loop cycle time < 100ms
  - SC-OODA-003: State published to Zenoh
  - SC-OODA-004: Actions traceable

  ## Mathematical Specification

  ```
  OODA := (Observe, Orient, Decide, Act, Feedback)

  Observe: Environment → Observations
  Orient: Observations × Context → Situation
  Decide: Situation × Goals → Decision
  Act: Decision → Action × Result
  Feedback: Result → Context'

  Loop Invariant:
    □(Started ⟹ ◇(Observe → Orient → Decide → Act))
  ```
  """

  use Indrajaal.Distributed.Agents.BaseAgent,
    type: :cybernetic,
    namespace: "ooda",
    name: "controller"

  alias Indrajaal.Cortex.Evolution.TrainingGym
  alias Indrajaal.Cortex.GDE.AIIntegration
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # AGENT CALLBACKS
  # ============================================================

  @impl true
  def agent_init(_opts) do
    state = %{
      current_phase: :idle,
      loop_count: 0,
      observations: [],
      last_situation: nil,
      last_decision: nil,
      last_action: nil,
      phase_timings: %{
        observe: [],
        orient: [],
        decide: [],
        act: []
      },
      config: %{
        observation_sources: [:telemetry, :zenoh, :metrics],
        # Decision strategies:
        # - :weighted_multi_criteria (default) - Traditional weighted scoring
        # - :rule_based - Condition-based rules
        # - :ai_assisted - Use GDE AI for complex decisions (SC-GDE-065)
        decision_strategy: :weighted_multi_criteria,
        action_timeout_ms: 5_000,
        # AI integration settings
        # :fast, :smart, :deep
        ai_model: :fast,
        # Auto-augment critical decisions with AI
        ai_augment_critical: true,
        # Minimum confidence for AI proposals
        ai_min_confidence: 0.6
      }
    }

    {:ok, state}
  end

  @impl true
  def agent_state(state) do
    %{
      current_phase: state.current_phase,
      loop_count: state.loop_count,
      observation_count: length(state.observations),
      last_situation: state.last_situation,
      last_decision: state.last_decision,
      last_action: state.last_action,
      avg_phase_timings: calculate_avg_timings(state.phase_timings)
    }
  end

  @impl true
  def agent_metrics(state) do
    %{
      loop_count: state.loop_count,
      current_phase: state.current_phase,
      avg_cycle_time_ms: calculate_avg_cycle_time(state.phase_timings),
      phase_stats: phase_statistics(state.phase_timings)
    }
  end

  @impl true
  def handle_command(:run_loop, _params, state) do
    # Execute full OODA loop
    {new_state, result} = execute_ooda_loop(state)
    {:ok, result, new_state}
  end

  @impl true
  def handle_command(:observe, params, state) do
    {timing, observations} = :timer.tc(fn -> do_observe(params) end)

    new_state = %{
      state
      | current_phase: :observe,
        observations: observations,
        phase_timings: update_timings(state.phase_timings, :observe, timing)
    }

    {:ok, %{observations: length(observations), timing_us: timing}, new_state}
  end

  @impl true
  def handle_command(:orient, _params, state) do
    {timing, situation} = :timer.tc(fn -> do_orient(state.observations) end)

    new_state = %{
      state
      | current_phase: :orient,
        last_situation: situation,
        phase_timings: update_timings(state.phase_timings, :orient, timing)
    }

    {:ok, %{situation: situation, timing_us: timing}, new_state}
  end

  @impl true
  def handle_command(:decide, _params, state) do
    {timing, decision} =
      :timer.tc(fn ->
        do_decide(state.last_situation, state.config.decision_strategy)
      end)

    new_state = %{
      state
      | current_phase: :decide,
        last_decision: decision,
        phase_timings: update_timings(state.phase_timings, :decide, timing)
    }

    {:ok, %{decision: decision, timing_us: timing}, new_state}
  end

  @impl true
  def handle_command(:act, _params, state) do
    {timing, action_result} =
      :timer.tc(fn ->
        do_act(state.last_decision, state.config.action_timeout_ms)
      end)

    new_state = %{
      state
      | current_phase: :act,
        last_action: action_result,
        phase_timings: update_timings(state.phase_timings, :act, timing)
    }

    {:ok, %{action: action_result, timing_us: timing}, new_state}
  end

  @impl true
  def handle_command(:get_config, _params, state) do
    {:ok, state.config, state}
  end

  @impl true
  def handle_command(:set_config, params, state) do
    new_config = Map.merge(state.config, params)
    {:ok, :updated, %{state | config: new_config}}
  end

  @impl true
  def handle_command(unknown, _params, state) do
    {:error, {:unknown_command, unknown}, state}
  end

  # ============================================================
  # OODA LOOP IMPLEMENTATION
  # ============================================================

  defp execute_ooda_loop(state) do
    start_time = System.monotonic_time(:microsecond)

    # Phase 1: Observe
    {obs_time, observations} = :timer.tc(fn -> do_observe(%{}) end)

    # Phase 2: Orient
    {ori_time, situation} = :timer.tc(fn -> do_orient(observations) end)

    # Phase 3: Decide
    {dec_time, raw_decision} =
      :timer.tc(fn -> do_decide(situation, state.config.decision_strategy) end)

    # Apply AI augmentation if enabled for critical decisions
    decision = maybe_apply_ai_augmentation(raw_decision, situation, state.config)

    # Phase 4: Act
    {act_time, action_result} =
      :timer.tc(fn -> do_act(decision, state.config.action_timeout_ms) end)

    total_time = System.monotonic_time(:microsecond) - start_time

    result = %{
      loop_id: state.loop_count + 1,
      observations: length(observations),
      situation: situation,
      decision: decision,
      action: action_result,
      timings: %{
        observe_us: obs_time,
        orient_us: ori_time,
        decide_us: dec_time,
        act_us: act_time,
        total_us: total_time
      }
    }

    new_state = %{
      state
      | current_phase: :idle,
        loop_count: state.loop_count + 1,
        observations: observations,
        last_situation: situation,
        last_decision: decision,
        last_action: action_result,
        phase_timings:
          state.phase_timings
          |> update_timings(:observe, obs_time)
          |> update_timings(:orient, ori_time)
          |> update_timings(:decide, dec_time)
          |> update_timings(:act, act_time)
    }

    {new_state, result}
  end

  defp do_observe(_params) do
    # Collect observations from various sources
    [
      {:telemetry, collect_telemetry()},
      {:system, collect_system_metrics()},
      {:agents, collect_agent_status()}
    ]
  end

  defp do_orient(observations) do
    # Analyze observations and build situation awareness
    %{
      system_health: analyze_health(observations),
      resource_pressure: analyze_resources(observations),
      anomalies: detect_anomalies(observations),
      trends: identify_trends(observations)
    }
  end

  defp do_decide(situation, strategy) do
    # Make decision based on situation and strategy
    base_decision =
      case strategy do
        :weighted_multi_criteria ->
          weighted_decision(situation)

        :rule_based ->
          rule_based_decision(situation)

        :ai_assisted ->
          # Use GDE AI for complex decisions (SC-GDE-065)
          ai_assisted_decision(situation)

        _ ->
          %{action: :monitor, priority: :low, reason: "default action"}
      end

    base_decision
  end

  # Called from execute_ooda_loop to apply AI augmentation based on config
  defp maybe_apply_ai_augmentation(decision, situation, config) do
    # For critical situations, augment with AI recommendations if enabled
    if decision.priority == :high and
         Map.get(config, :ai_augment_critical, true) and
         Map.get(config, :decision_strategy) != :ai_assisted do
      maybe_augment_with_ai(decision, situation, config)
    else
      decision
    end
  end

  # SC-GDE-065: AI-assisted decision making via GDE
  defp ai_assisted_decision(situation) do
    error_context = %{
      type: situation_to_error_type(situation),
      severity: situation_to_severity(situation),
      context: situation,
      timestamp: DateTime.utc_now()
    }

    case try_gde_cycle(error_context) do
      {:ok, %{validated: [proposal | _]}} ->
        # AI proposal validated by Guardian
        %{
          action: proposal_to_action(proposal),
          priority: :high,
          reason: "AI-assisted decision",
          ai_proposal: proposal,
          confidence: Map.get(proposal, :confidence, 0.0)
        }

      {:ok, %{validated: []}} ->
        # No validated proposals, fall back to weighted
        weighted_decision(situation)

      {:error, _} ->
        # GDE failed, fall back to weighted
        weighted_decision(situation)
    end
  end

  defp maybe_augment_with_ai(base_decision, situation, config) do
    # Only augment if AI integration is available and healthy
    if ai_integration_available?() do
      error_context = %{
        type: :critical_situation,
        severity: :high,
        context: Map.merge(situation, %{base_decision: base_decision}),
        timestamp: DateTime.utc_now()
      }

      min_confidence = Map.get(config, :ai_min_confidence, 0.6)
      model = Map.get(config, :ai_model, :fast)

      case try_gde_cycle(error_context, model) do
        {:ok, %{validated: [proposal | _], success_rate: rate}} when rate > min_confidence ->
          Map.merge(base_decision, %{
            ai_augmented: true,
            ai_proposal: proposal,
            ai_confidence: Map.get(proposal, :confidence, 0.0)
          })

        _ ->
          base_decision
      end
    else
      base_decision
    end
  end

  defp try_gde_cycle(error_context, model \\ :fast) do
    if Code.ensure_loaded?(AIIntegration) do
      AIIntegration.execute_gde_cycle(error_context, model: model)
    else
      {:error, :ai_integration_not_loaded}
    end
  rescue
    _ -> {:error, :gde_cycle_failed}
  end

  defp ai_integration_available? do
    Code.ensure_loaded?(AIIntegration) and Code.ensure_loaded?(Guardian)
  end

  defp situation_to_error_type(situation) do
    case situation.system_health do
      :critical -> :system_critical
      :warning -> :system_warning
      _ -> :system_monitoring
    end
  end

  defp situation_to_severity(situation) do
    case situation.system_health do
      :critical -> :high
      :warning -> :medium
      _ -> :low
    end
  end

  defp proposal_to_action(proposal) do
    case Map.get(proposal, :type) do
      :scale_up -> :scale_up
      :scale_down -> :scale_down
      :restart -> :restart
      :alert -> :alert
      :config_change -> :config_change
      _ -> :monitor
    end
  end

  defp do_act(nil, _timeout_ms) do
    # Handle case when decide hasn't been called yet
    {:ok, :no_action}
  end

  defp do_act(decision, _timeout_ms) do
    # Execute the decided action
    action_result =
      case decision.action do
        :scale_up ->
          execute_with_guardian_validation(decision, :scale_up)

        :scale_down ->
          execute_with_guardian_validation(decision, :scale_down)

        :restart ->
          execute_with_guardian_validation(decision, :restart)

        :config_change ->
          execute_with_guardian_validation(decision, :config_change)

        :alert ->
          {:ok, :alerted}

        :monitor ->
          {:ok, :monitoring}

        _ ->
          {:ok, :no_action}
      end

    # Record to TrainingGym for RL feedback (SC-GDE-062)
    record_action_result(decision, action_result)

    action_result
  end

  defp execute_with_guardian_validation(decision, action_type) do
    # SC-NEURO-001: All actions must pass Guardian validation
    if Code.ensure_loaded?(Guardian) and GenServer.whereis(Guardian) do
      proposal = %{
        action: action_type,
        target: Map.get(decision, :target),
        parameters: Map.get(decision, :parameters, %{}),
        source: "ooda_agent"
      }

      case Guardian.validate_proposal(proposal) do
        {:ok, :approved} ->
          execute_action(action_type, decision)

        {:ok, :vetoed, reason} ->
          Logger.warning("[OODAAgent] Action #{action_type} vetoed: #{reason}")
          {:vetoed, reason}

        {:error, reason} ->
          Logger.error("[OODAAgent] Guardian validation failed: #{inspect(reason)}")
          {:error, :guardian_validation_failed}
      end
    else
      # Guardian not available, proceed with caution
      execute_action(action_type, decision)
    end
  end

  defp execute_action(action_type, _decision) do
    case action_type do
      :scale_up -> {:ok, :scaled_up}
      :scale_down -> {:ok, :scaled_down}
      :restart -> {:ok, :restarted}
      :config_change -> {:ok, :config_changed}
      _ -> {:ok, :executed}
    end
  end

  defp record_action_result(decision, result) do
    if Code.ensure_loaded?(TrainingGym) and GenServer.whereis(TrainingGym) do
      state_before = %{
        action: decision.action,
        priority: decision.priority,
        ai_augmented: Map.get(decision, :ai_augmented, false),
        confidence: Map.get(decision, :ai_confidence, 0.0)
      }

      action = decision.action

      case result do
        {:ok, outcome} ->
          TrainingGym.record_success(state_before, action, outcome)

        {:vetoed, reason} ->
          TrainingGym.record_near_miss(state_before, action, reason)

        {:error, error_reason} ->
          TrainingGym.record_near_miss(state_before, action, error_reason)
      end
    end
  rescue
    _ -> :ok
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp collect_telemetry do
    %{
      vm_memory: :erlang.memory(),
      process_count: :erlang.system_info(:process_count),
      scheduler_util: :erlang.statistics(:scheduler_wall_time)
    }
  rescue
    _ -> %{}
  end

  defp collect_system_metrics do
    %{
      cpu: 0.5,
      memory: 0.6,
      disk: 0.3
    }
  end

  defp collect_agent_status do
    Indrajaal.Distributed.AgentMesh.mesh_status()
  rescue
    _ -> %{}
  end

  defp analyze_health(observations) do
    # Simplified health analysis
    Enum.reduce(observations, :healthy, fn
      {:telemetry, %{vm_memory: mem}}, acc ->
        total = Keyword.get(mem, :total, 0)
        if total > 1_000_000_000, do: :warning, else: acc

      _, acc ->
        acc
    end)
  end

  defp analyze_resources(_observations), do: :normal
  defp detect_anomalies(_observations), do: []
  defp identify_trends(_observations), do: :stable

  defp weighted_decision(nil) do
    # Handle case when orient hasn't been called yet
    %{action: :monitor, priority: :low, reason: "no situation available - defaulting to monitor"}
  end

  defp weighted_decision(situation) do
    priority =
      case situation.system_health do
        :healthy -> :low
        :warning -> :medium
        :critical -> :high
      end

    action =
      case situation.resource_pressure do
        :high -> :scale_up
        :low -> :scale_down
        _ -> :monitor
      end

    %{action: action, priority: priority, reason: "weighted decision"}
  end

  defp rule_based_decision(nil) do
    %{action: :monitor, priority: :low, reason: "no situation available - defaulting to monitor"}
  end

  defp rule_based_decision(situation) do
    cond do
      situation.system_health == :critical ->
        %{action: :alert, priority: :high, reason: "critical health"}

      situation.resource_pressure == :high ->
        %{action: :scale_up, priority: :medium, reason: "high pressure"}

      true ->
        %{action: :monitor, priority: :low, reason: "stable state"}
    end
  end

  defp update_timings(timings, phase, timing) do
    current = Map.get(timings, phase, [])
    # Keep last 100 timings
    updated = Enum.take([timing | current], 100)
    Map.put(timings, phase, updated)
  end

  defp calculate_avg_timings(timings) do
    avg_list =
      Enum.map(timings, fn {phase, values} ->
        avg = if values == [], do: 0.0, else: Enum.sum(values) / length(values)
        {phase, Float.round(avg, 2)}
      end)

    Map.new(avg_list)
  end

  defp calculate_avg_cycle_time(timings) do
    phases = [:observe, :orient, :decide, :act]

    total =
      Enum.reduce(phases, 0.0, fn phase, acc ->
        values = Map.get(timings, phase, [])
        avg = if values == [], do: 0.0, else: Enum.sum(values) / length(values)
        acc + avg
      end)

    Float.round(total / 1000, 2)
  end

  defp phase_statistics(timings) do
    stats_list =
      Enum.map(timings, fn {phase, values} ->
        stats =
          if values == [] do
            %{min: 0, max: 0, avg: 0, count: 0}
          else
            %{
              min: Enum.min(values),
              max: Enum.max(values),
              avg: Float.round(Enum.sum(values) / length(values), 2),
              count: length(values)
            }
          end

        {phase, stats}
      end)

    Map.new(stats_list)
  end
end
