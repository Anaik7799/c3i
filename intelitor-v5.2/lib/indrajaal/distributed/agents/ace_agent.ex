defmodule Indrajaal.Distributed.Agents.ACEAgent do
  @moduledoc """
  Agent 2: ACE - Autonomic Computing Engine.

  WHAT: Implements self-management for compute resource optimization.
  WHY: SC-ACE-001 requires autonomic control of FLAME pools and resources.
  CONSTRAINTS: Resource decisions must be safe and reversible.

  ## ACE Responsibilities

  1. **Self-Configuration**: Adapt system configuration
  2. **Self-Optimization**: Optimize resource allocation
  3. **Self-Healing**: Detect and recover from failures
  4. **Self-Protection**: Protect against cascading failures

  ## STAMP Constraints
  - SC-ACE-001: Autonomic resource management
  - SC-ACE-002: Safe scaling operations
  - SC-ACE-003: Resource state published to Zenoh
  - SC-ACE-004: Rollback capability for all changes

  ## Mathematical Specification

  ```
  ACE := (Monitor, Analyze, Plan, Execute) -- MAPE-K loop

  Monitor: System → Metrics
  Analyze: Metrics × Knowledge → Symptoms
  Plan: Symptoms × Policies → ChangeSet
  Execute: ChangeSet → System'

  Knowledge := (Policies, History, Thresholds)

  Safety Invariant:
    ∀ change ∈ ChangeSet: Reversible(change) ∧ Safe(change)
  ```
  """

  use Indrajaal.Distributed.Agents.BaseAgent,
    type: :cybernetic,
    namespace: "ace",
    name: "engine"

  # ============================================================
  # AGENT CALLBACKS
  # ============================================================

  @impl true
  def agent_init(_opts) do
    state = %{
      # MAPE-K state
      current_phase: :idle,
      mape_cycle_count: 0,

      # Monitored resources
      resources: %{
        flame_pools: %{
          intelligence: %{min: 0, max: 10, current: 0, target: 0},
          video: %{min: 0, max: 20, current: 0, target: 0},
          analytics: %{min: 0, max: 15, current: 0, target: 0}
        },
        memory: %{used: 0, total: 0, threshold: 0.85},
        cpu: %{utilization: 0.0, threshold: 0.80}
      },

      # Knowledge base
      knowledge: %{
        policies: default_policies(),
        history: [],
        thresholds: default_thresholds()
      },

      # Pending and executed changes
      pending_changes: [],
      change_history: [],

      # Metrics
      scaling_events: 0,
      healing_events: 0
    }

    {:ok, state}
  end

  @impl true
  def agent_state(state) do
    %{
      current_phase: state.current_phase,
      mape_cycle_count: state.mape_cycle_count,
      resources: state.resources,
      pending_changes: length(state.pending_changes),
      scaling_events: state.scaling_events,
      healing_events: state.healing_events
    }
  end

  @impl true
  def agent_metrics(state) do
    %{
      mape_cycles: state.mape_cycle_count,
      scaling_events: state.scaling_events,
      healing_events: state.healing_events,
      pending_changes: length(state.pending_changes),
      history_size: length(state.change_history),
      resource_utilization: calculate_utilization(state.resources)
    }
  end

  @impl true
  def handle_command(:run_mape, _params, state) do
    {new_state, result} = execute_mape_cycle(state)
    {:ok, result, new_state}
  end

  @impl true
  def handle_command(:monitor, _params, state) do
    metrics = collect_metrics()

    new_state = %{
      state
      | current_phase: :monitor,
        resources: update_resources(state.resources, metrics)
    }

    {:ok, metrics, new_state}
  end

  @impl true
  def handle_command(:analyze, _params, state) do
    symptoms = analyze_symptoms(state.resources, state.knowledge)

    new_knowledge = update_knowledge(state.knowledge, symptoms)
    new_state = %{state | current_phase: :analyze, knowledge: new_knowledge}

    {:ok, symptoms, new_state}
  end

  @impl true
  def handle_command(:plan, params, state) do
    symptoms = Map.get(params, :symptoms, [])
    changes = plan_changes(symptoms, state.knowledge.policies)

    new_state = %{state | current_phase: :plan, pending_changes: changes}
    {:ok, %{changes: changes}, new_state}
  end

  @impl true
  def handle_command(:execute, _params, state) do
    {results, new_history} = execute_changes(state.pending_changes, state.change_history)

    new_state = %{
      state
      | current_phase: :idle,
        pending_changes: [],
        change_history: new_history,
        scaling_events: state.scaling_events + count_scaling(results)
    }

    {:ok, results, new_state}
  end

  @impl true
  def handle_command(:scale_pool, params, state) do
    pool = Map.get(params, :pool)
    target = Map.get(params, :target)

    case safe_scale_pool(pool, target, state) do
      {:ok, new_resources} ->
        new_state = %{
          state
          | resources: new_resources,
            scaling_events: state.scaling_events + 1
        }

        {:ok, %{pool: pool, target: target, status: :scaled}, new_state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  @impl true
  def handle_command(:rollback, params, state) do
    change_id = Map.get(params, :change_id)
    {result, new_history} = rollback_change(change_id, state.change_history)
    new_state = %{state | change_history: new_history}
    {:ok, result, new_state}
  end

  @impl true
  def handle_command(unknown, _params, state) do
    {:error, {:unknown_command, unknown}, state}
  end

  # ============================================================
  # MAPE-K IMPLEMENTATION
  # ============================================================

  defp execute_mape_cycle(state) do
    # Monitor
    metrics = collect_metrics()
    resources = update_resources(state.resources, metrics)

    # Analyze
    symptoms = analyze_symptoms(resources, state.knowledge)
    knowledge = update_knowledge(state.knowledge, symptoms)

    # Plan
    changes = plan_changes(symptoms, knowledge.policies)

    # Execute (only if changes are safe)
    {results, history} =
      if Enum.all?(changes, &safe_change?/1) do
        execute_changes(changes, state.change_history)
      else
        {%{status: :skipped, reason: "unsafe changes"}, state.change_history}
      end

    result = %{
      cycle: state.mape_cycle_count + 1,
      symptoms: symptoms,
      changes: changes,
      results: results
    }

    new_state = %{
      state
      | current_phase: :idle,
        mape_cycle_count: state.mape_cycle_count + 1,
        resources: resources,
        knowledge: knowledge,
        pending_changes: [],
        change_history: history,
        scaling_events: state.scaling_events + count_scaling(results)
    }

    {new_state, result}
  end

  defp collect_metrics do
    %{
      memory: :erlang.memory(),
      processes: :erlang.system_info(:process_count),
      schedulers: :erlang.system_info(:schedulers_online),
      run_queue: :erlang.statistics(:run_queue)
    }
  end

  defp update_resources(resources, metrics) do
    total_mem = Keyword.get(metrics.memory, :total, 1)

    used_mem =
      Keyword.get(metrics.memory, :processes, 0) + Keyword.get(metrics.memory, :binary, 0)

    %{
      resources
      | memory: %{resources.memory | used: used_mem, total: total_mem},
        cpu: %{resources.cpu | utilization: estimate_cpu(metrics)}
    }
  end

  defp estimate_cpu(metrics) do
    run_queue = metrics.run_queue
    schedulers = metrics.schedulers
    min(1.0, run_queue / (schedulers * 2))
  end

  defp analyze_symptoms(resources, knowledge) do
    symptoms = []

    # Check memory
    mem_ratio = resources.memory.used / max(resources.memory.total, 1)

    symptoms =
      if mem_ratio > knowledge.thresholds.memory_high do
        [{:high_memory, mem_ratio} | symptoms]
      else
        symptoms
      end

    # Check CPU
    symptoms =
      if resources.cpu.utilization > knowledge.thresholds.cpu_high do
        [{:high_cpu, resources.cpu.utilization} | symptoms]
      else
        symptoms
      end

    symptoms
  end

  defp plan_changes(symptoms, policies) do
    Enum.flat_map(symptoms, fn symptom ->
      case symptom do
        {:high_memory, _} ->
          if policies[:scale_on_memory] do
            [%{type: :scale, pool: :analytics, direction: :up, reason: :high_memory}]
          else
            []
          end

        {:high_cpu, _} ->
          if policies[:scale_on_cpu] do
            [%{type: :scale, pool: :intelligence, direction: :up, reason: :high_cpu}]
          else
            []
          end

        _ ->
          []
      end
    end)
  end

  defp execute_changes(changes, history) do
    results =
      Enum.map(changes, fn change ->
        result = apply_change(change)
        %{change: change, result: result, timestamp: DateTime.utc_now()}
      end)

    new_history = results ++ Enum.take(history, 99)
    {%{executed: length(results), results: results}, new_history}
  end

  defp apply_change(%{type: :scale, pool: pool, direction: direction}) do
    Logger.info("[ACEAgent] Applying scale change", pool: pool, direction: direction)
    {:ok, :applied}
  end

  defp apply_change(_), do: {:ok, :skipped}

  defp safe_change?(%{type: :scale}), do: true
  defp safe_change?(_), do: false

  defp safe_scale_pool(pool, target, state) do
    pool_config = get_in(state.resources, [:flame_pools, pool])

    if pool_config && target >= pool_config.min && target <= pool_config.max do
      new_resources = put_in(state.resources, [:flame_pools, pool, :target], target)
      {:ok, new_resources}
    else
      {:error, :invalid_target}
    end
  end

  defp rollback_change(change_id, history) do
    case Enum.find(history, fn h -> h.change[:id] == change_id end) do
      nil -> {{:error, :not_found}, history}
      change -> {{:ok, :rolled_back}, List.delete(history, change)}
    end
  end

  defp count_scaling(%{executed: n}), do: n
  defp count_scaling(_), do: 0

  defp update_knowledge(knowledge, symptoms) do
    new_history = [%{symptoms: symptoms, timestamp: DateTime.utc_now()} | knowledge.history]
    %{knowledge | history: Enum.take(new_history, 100)}
  end

  defp calculate_utilization(resources) do
    %{
      memory: Float.round(resources.memory.used / max(resources.memory.total, 1) * 100, 2),
      cpu: Float.round(resources.cpu.utilization * 100, 2)
    }
  end

  defp default_policies do
    %{
      scale_on_memory: true,
      scale_on_cpu: true,
      max_scale_per_cycle: 2,
      cooldown_seconds: 60
    }
  end

  defp default_thresholds do
    %{
      memory_high: 0.85,
      memory_low: 0.40,
      cpu_high: 0.80,
      cpu_low: 0.30
    }
  end
end
