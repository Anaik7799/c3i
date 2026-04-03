defmodule Indrajaal.Distributed.Agents.CortexAgent do
  @moduledoc """
  Agent 3: Cortex - Cognitive Controller for System Homeostasis.

  WHAT: Implements cognitive control for stress analysis and reflexes.
  WHY: SC-CTX-001 requires homeostatic regulation of system state.
  CONSTRAINTS: Reflex actions < 50ms, stress scores normalized.

  ## Cortex Responsibilities

  1. **Stress Analysis**: Calculate system stress scores
  2. **Homeostasis**: Maintain system equilibrium
  3. **Reflexes**: Automatic responses to stimuli
  4. **Adaptation**: Long-term behavioral changes

  ## STAMP Constraints
  - SC-CTX-001: Cognitive control implementation
  - SC-CTX-002: Stress scores normalized [0, 1]
  - SC-CTX-003: Reflex latency < 50ms
  - SC-CTX-004: Homeostatic setpoints configurable

  ## Mathematical Specification

  ```
  Cortex := (Sensors, Stress, Homeostasis, Reflexes)

  Sensors: Environment → SensorReadings
  Stress: SensorReadings → [0, 1]    -- normalized stress score
  Homeostasis: State × Setpoints → Adjustments
  Reflexes: Stimuli → Responses      -- immediate reactions

  Homeostasis Invariant:
    ∀ metric ∈ Metrics: |metric - setpoint(metric)| < tolerance(metric)
  ```
  """

  use Indrajaal.Distributed.Agents.BaseAgent,
    type: :cybernetic,
    namespace: "cortex",
    name: "controller"

  # ============================================================
  # AGENT CALLBACKS
  # ============================================================

  @impl true
  def agent_init(_opts) do
    state = %{
      # Sensor readings
      sensors: %{
        cpu: 0.0,
        memory: 0.0,
        latency: 0.0,
        error_rate: 0.0,
        queue_depth: 0
      },

      # Stress state
      stress: %{
        current: 0.0,
        trend: :stable,
        history: [],
        threshold: 0.7
      },

      # Homeostatic setpoints
      setpoints: %{
        cpu: 0.50,
        memory: 0.60,
        latency: 50.0,
        error_rate: 0.01,
        queue_depth: 100
      },

      # Tolerance bands
      tolerances: %{
        cpu: 0.15,
        memory: 0.15,
        latency: 20.0,
        error_rate: 0.02,
        queue_depth: 50
      },

      # Reflex configuration
      reflexes: %{
        circuit_breaker: %{enabled: true, triggered: 0},
        load_shedding: %{enabled: true, triggered: 0},
        emergency_gc: %{enabled: true, triggered: 0}
      },

      # Metrics
      homeostasis_cycles: 0,
      reflex_triggers: 0,
      adaptations: 0
    }

    {:ok, state}
  end

  @impl true
  def agent_state(state) do
    %{
      sensors: state.sensors,
      stress: %{
        current: state.stress.current,
        trend: state.stress.trend,
        threshold: state.stress.threshold
      },
      setpoints: state.setpoints,
      reflexes: reflex_summary(state.reflexes),
      homeostasis_cycles: state.homeostasis_cycles
    }
  end

  @impl true
  def agent_metrics(state) do
    %{
      stress_score: state.stress.current,
      stress_trend: state.stress.trend,
      homeostasis_cycles: state.homeostasis_cycles,
      reflex_triggers: state.reflex_triggers,
      adaptations: state.adaptations,
      deviations: calculate_deviations(state)
    }
  end

  @impl true
  def handle_command(:sense, _params, state) do
    readings = collect_sensor_readings()
    new_state = %{state | sensors: readings}
    {:ok, readings, new_state}
  end

  @impl true
  def handle_command(:analyze_stress, _params, state) do
    stress_score = calculate_stress(state.sensors, state.setpoints, state.tolerances)
    trend = determine_trend(stress_score, state.stress.history)

    new_stress = %{
      state.stress
      | current: stress_score,
        trend: trend,
        history: update_history(state.stress.history, stress_score)
    }

    new_state = %{state | stress: new_stress}
    {:ok, %{score: stress_score, trend: trend}, new_state}
  end

  @impl true
  def handle_command(:homeostasis, _params, state) do
    adjustments = compute_adjustments(state.sensors, state.setpoints, state.tolerances)

    new_state = %{state | homeostasis_cycles: state.homeostasis_cycles + 1}
    {:ok, adjustments, new_state}
  end

  @impl true
  def handle_command(:reflex, params, state) do
    stimulus = Map.get(params, :stimulus)
    {response, new_reflexes} = trigger_reflex(stimulus, state.reflexes)

    new_state = %{
      state
      | reflexes: new_reflexes,
        reflex_triggers: state.reflex_triggers + 1
    }

    {:ok, response, new_state}
  end

  @impl true
  def handle_command(:set_setpoint, params, state) do
    metric = Map.get(params, :metric)
    value = Map.get(params, :value)

    if Map.has_key?(state.setpoints, metric) do
      new_setpoints = Map.put(state.setpoints, metric, value)
      new_state = %{state | setpoints: new_setpoints}
      {:ok, :updated, new_state}
    else
      {:error, :invalid_metric, state}
    end
  end

  @impl true
  def handle_command(:get_health, _params, state) do
    health = compute_health_status(state)
    {:ok, health, state}
  end

  @impl true
  def handle_command(unknown, _params, state) do
    {:error, {:unknown_command, unknown}, state}
  end

  # ============================================================
  # CORTEX IMPLEMENTATION
  # ============================================================

  defp collect_sensor_readings do
    memory = :erlang.memory()
    total_mem = Keyword.get(memory, :total, 1)
    used_mem = Keyword.get(memory, :processes, 0) + Keyword.get(memory, :binary, 0)

    %{
      cpu: estimate_cpu_load(),
      memory: used_mem / total_mem,
      latency: measure_latency(),
      error_rate: get_error_rate(),
      queue_depth: get_queue_depth()
    }
  end

  defp estimate_cpu_load do
    case :erlang.statistics(:run_queue) do
      0 -> 0.1
      q when q < 4 -> 0.3
      q when q < 8 -> 0.6
      _ -> 0.9
    end
  end

  defp measure_latency do
    start = System.monotonic_time(:microsecond)
    _ = :erlang.memory()
    System.monotonic_time(:microsecond) - start
  end

  defp get_error_rate, do: 0.001
  defp get_queue_depth, do: :erlang.statistics(:run_queue)

  defp calculate_stress(sensors, setpoints, tolerances) do
    # Calculate weighted stress from all sensor deviations
    weights = %{cpu: 0.3, memory: 0.3, latency: 0.15, error_rate: 0.15, queue_depth: 0.1}

    total_stress =
      Enum.reduce(weights, 0.0, fn {metric, weight}, acc ->
        value = Map.get(sensors, metric, 0)
        setpoint = Map.get(setpoints, metric, 0)
        tolerance = Map.get(tolerances, metric, 1)

        deviation = abs(value - setpoint) / max(tolerance, 0.001)
        stress_contribution = min(1.0, deviation) * weight
        acc + stress_contribution
      end)

    Float.round(min(1.0, total_stress), 3)
  end

  defp determine_trend(_current, history) when length(history) < 3, do: :stable

  defp determine_trend(current, history) do
    recent = Enum.take(history, 5)
    avg = Enum.sum(recent) / length(recent)

    cond do
      current > avg + 0.1 -> :increasing
      current < avg - 0.1 -> :decreasing
      true -> :stable
    end
  end

  defp update_history(history, value) do
    [value | Enum.take(history, 99)]
  end

  defp compute_adjustments(sensors, setpoints, tolerances) do
    Enum.reduce(setpoints, [], fn {metric, setpoint}, acc ->
      value = Map.get(sensors, metric, setpoint)
      tolerance = Map.get(tolerances, metric, 0)

      deviation = value - setpoint

      if abs(deviation) > tolerance do
        direction = if deviation > 0, do: :decrease, else: :increase
        [{metric, direction, abs(deviation)} | acc]
      else
        acc
      end
    end)
  end

  defp trigger_reflex(stimulus, reflexes) do
    case stimulus do
      :overload when reflexes.load_shedding.enabled ->
        new_reflexes = update_in(reflexes.load_shedding.triggered, &(&1 + 1))
        {:load_shedding_activated, new_reflexes}

      :error_spike when reflexes.circuit_breaker.enabled ->
        new_reflexes = update_in(reflexes.circuit_breaker.triggered, &(&1 + 1))
        {:circuit_breaker_tripped, new_reflexes}

      :memory_pressure when reflexes.emergency_gc.enabled ->
        :erlang.garbage_collect()
        new_reflexes = update_in(reflexes.emergency_gc.triggered, &(&1 + 1))
        {:gc_triggered, new_reflexes}

      _ ->
        {:no_reflex, reflexes}
    end
  end

  defp compute_health_status(state) do
    %{
      status: health_from_stress(state.stress.current),
      stress: state.stress.current,
      trend: state.stress.trend,
      deviations: calculate_deviations(state),
      reflexes_triggered: state.reflex_triggers
    }
  end

  defp health_from_stress(stress) when stress < 0.3, do: :healthy
  defp health_from_stress(stress) when stress < 0.7, do: :warning
  defp health_from_stress(_), do: :critical

  defp calculate_deviations(state) do
    Enum.reduce(state.setpoints, %{}, fn {metric, setpoint}, acc ->
      value = Map.get(state.sensors, metric, setpoint)
      tolerance = Map.get(state.tolerances, metric, 1)
      deviation = (value - setpoint) / max(tolerance, 0.001)
      Map.put(acc, metric, Float.round(deviation, 3))
    end)
  end

  defp reflex_summary(reflexes) do
    mapped =
      Enum.map(reflexes, fn {name, config} ->
        {name, %{enabled: config.enabled, triggered: config.triggered}}
      end)

    mapped |> Map.new()
  end
end
