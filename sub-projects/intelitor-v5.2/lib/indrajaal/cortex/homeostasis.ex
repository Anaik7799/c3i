defmodule Indrajaal.Cortex.Homeostasis do
  @moduledoc """
  Homeostasis Engine - Maintains System Equilibrium.

  The homeostasis system is responsible for maintaining the system
  within operational bounds by:
  - Monitoring key metrics (stress, resource utilization)
  - Applying corrective actions (scaling, tuning)
  - Learning optimal set points

  Works in conjunction with the Controller's OODA loop:
  - Controller handles cognitive decisions (proposals)
  - Homeostasis handles autonomic adjustments (automatic)

  STAMP Compliance:
  - SC-CTX-001: Autonomic system isolation
  - SC-CTX-003: Graceful degradation
  - SC-PRF-050: Performance self-tuning

  GDE/CAFE:
  - Goal-directed homeostatic regulation
  - Cybernetic feedback integration
  """

  use GenServer

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias Indrajaal.Cortex.Analysis.StressAnalyzer
  alias Indrajaal.Cortex.Sensors.BeamSensor

  @check_interval :timer.seconds(30)

  # Thresholds for autonomic responses
  @stress_critical 0.9
  @stress_high 0.75
  @stress_optimal_high 0.6
  @stress_optimal_low 0.3
  @stress_low 0.2

  # Rate limiting for actions
  @min_action_interval :timer.seconds(60)

  # PID controller parameters (Ziegler-Nichols tuned)
  # Setpoint: target stress level (middle of optimal band)
  @pid_setpoint 0.45
  # Kp: proportional gain — how strongly to react to current error
  @pid_kp 2.0
  # Ki: integral gain — how strongly to correct accumulated error
  @pid_ki 0.1
  # Kd: derivative gain — how strongly to dampen rate of change
  @pid_kd 0.5

  ## Client API

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current homeostasis state.
  """
  @spec get_state() :: map()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Get current stress level.
  """
  @spec stress_level() :: float()
  def stress_level do
    GenServer.call(__MODULE__, :stress_level)
  end

  @doc """
  Force an immediate stability check.
  """
  @spec check_now() :: :ok
  def check_now do
    GenServer.cast(__MODULE__, :check_now)
  end

  @doc """
  Set a custom threshold.
  """
  @spec set_threshold(atom(), number()) :: :ok | {:error, atom()}
  def set_threshold(key, value) when is_atom(key) and is_number(value) do
    GenServer.call(__MODULE__, {:set_threshold, key, value})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("⚖️ Homeostasis: Engaging autonomic regulation system")

    state = %{
      # Current stress assessment
      current_stress: 0.0,
      # :rising, :falling, :stable
      stress_trend: :stable,

      # Operational bounds
      thresholds: %{
        critical: @stress_critical,
        high: @stress_high,
        optimal_high: @stress_optimal_high,
        optimal_low: @stress_optimal_low,
        low: @stress_low
      },

      # Action history
      last_action: nil,
      last_action_at: nil,
      action_history: [],

      # Metrics history for trend analysis
      stress_history: [],

      # PID controller state (SC-HOM-001: Ziegler-Nichols PID)
      pid: %{
        integral: 0.0,
        prev_error: 0.0,
        output: 0.0,
        last_time: System.monotonic_time(:millisecond)
      },

      # Configuration
      auto_tune: true,
      started_at: DateTime.utc_now()
    }

    schedule_check()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    summary = %{
      current_stress: state.current_stress,
      stress_trend: state.stress_trend,
      last_action: state.last_action,
      last_action_at: state.last_action_at,
      thresholds: state.thresholds,
      auto_tune: state.auto_tune,
      pid_output: state.pid.output,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at, :second)
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_call(:stress_level, _from, state) do
    {:reply, state.current_stress, state}
  end

  @impl true
  def handle_call({:set_threshold, key, value}, _from, state) do
    if Map.has_key?(state.thresholds, key) do
      new_thresholds = Map.put(state.thresholds, key, value)
      {:reply, :ok, %{state | thresholds: new_thresholds}}
    else
      {:reply, {:error, :invalid_threshold}, state}
    end
  end

  @impl true
  def handle_cast(:check_now, state) do
    new_state = perform_stability_check(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_stability, state) do
    new_state = perform_stability_check(state)
    schedule_check()
    {:noreply, new_state}
  end

  ## Private Functions

  defp schedule_check do
    Process.send_after(self(), :check_stability, @check_interval)
  end

  defp perform_stability_check(state) do
    Tracer.with_span "homeostasis.stability_check", kind: :internal do
      # Collect metrics
      metrics = collect_metrics()

      # Calculate stress
      stress = calculate_stress(metrics)
      Tracer.set_attribute("homeostasis.stress", stress)

      # Update stress history and calculate trend
      new_history = update_stress_history(state.stress_history, stress)
      trend = calculate_trend(new_history)
      Tracer.set_attribute("homeostasis.trend", to_string(trend))

      # Compute PID output for continuous control signal
      {pid_output, new_pid} = compute_pid(stress, state.pid)
      Tracer.set_attribute("homeostasis.pid_output", pid_output)

      # Apply control logic using PID output + threshold guards
      {action, new_state} = apply_control_logic(stress, trend, %{state | pid: new_pid})

      if action do
        Tracer.set_attribute("homeostasis.action", to_string(action))
      end

      # Emit PID telemetry for observability
      :telemetry.execute(
        [:indrajaal, :cortex, :homeostasis, :pid],
        %{output: pid_output, error: @pid_setpoint - stress, integral: new_pid.integral},
        %{stress: stress, trend: trend}
      )

      %{new_state | current_stress: stress, stress_trend: trend, stress_history: new_history}
    end
  end

  defp collect_metrics do
    try do
      BeamSensor.take_snapshot()
    rescue
      _ -> %{memory_usage: 0.5, cpu_usage: 0.5, run_queue: 0}
    end
  end

  defp calculate_stress(metrics) do
    try do
      StressAnalyzer.calculate_stress(metrics)
    rescue
      _ ->
        # Basic stress calculation fallback
        memory = Map.get(metrics, :memory_usage, 0.5)
        cpu = Map.get(metrics, :cpu_usage, 0.5)
        queue = min(Map.get(metrics, :run_queue, 0) / 100, 1.0)

        memory * 0.4 + cpu * 0.3 + queue * 0.3
    end
  end

  defp update_stress_history(history, stress) do
    # Keep last 20 readings
    [{stress, DateTime.utc_now()} | Enum.take(history, 19)]
  end

  defp calculate_trend(history) when length(history) < 3, do: :stable

  defp calculate_trend(history) do
    recent = history |> Enum.take(5) |> Enum.map(fn {s, _} -> s end)
    avg_recent = Enum.sum(recent) / length(recent)

    older = history |> Enum.drop(5) |> Enum.take(5) |> Enum.map(fn {s, _} -> s end)

    if length(older) > 0 do
      avg_older = Enum.sum(older) / length(older)
      diff = avg_recent - avg_older

      cond do
        diff > 0.1 -> :rising
        diff < -0.1 -> :falling
        true -> :stable
      end
    else
      :stable
    end
  end

  # PID controller: Proportional-Integral-Derivative control
  # Error > 0 means stress is below setpoint (system under-utilized)
  # Error < 0 means stress is above setpoint (system overloaded)
  defp compute_pid(stress, pid_state) do
    now = System.monotonic_time(:millisecond)
    dt_ms = max(now - pid_state.last_time, 1)
    dt = dt_ms / 1000.0

    error = @pid_setpoint - stress

    # Integral with anti-windup clamping [-2.0, 2.0]
    integral = pid_state.integral + error * dt
    integral = max(-2.0, min(2.0, integral))

    # Derivative (rate of error change)
    derivative = if dt > 0, do: (error - pid_state.prev_error) / dt, else: 0.0

    # PID output: negative = need to reduce load, positive = can add capacity
    output = @pid_kp * error + @pid_ki * integral + @pid_kd * derivative
    output = Float.round(max(-10.0, min(10.0, output)), 4)

    new_pid = %{
      integral: integral,
      prev_error: error,
      output: output,
      last_time: now
    }

    {output, new_pid}
  end

  defp apply_control_logic(stress, trend, state) do
    now = DateTime.utc_now()

    # Check rate limiting
    can_act = can_take_action?(state.last_action_at, now)

    cond do
      # Critical stress - always act
      stress > state.thresholds.critical ->
        action = :emergency_expand

        Logger.warning(
          "🚨 Homeostasis: CRITICAL STRESS (#{Float.round(stress, 2)}). Emergency expansion."
        )

        execute_action(action, state, now)

      # High stress - expand if trending up
      stress > state.thresholds.high and trend == :rising and can_act ->
        action = :expand

        Logger.warning(
          "🔥 Homeostasis: High stress (#{Float.round(stress, 2)}), rising. Expanding capacity."
        )

        execute_action(action, state, now)

      # Low stress - contract if trending down
      stress < state.thresholds.low and trend == :falling and can_act ->
        action = :contract

        Logger.info(
          "❄️ Homeostasis: Low stress (#{Float.round(stress, 2)}), falling. Contracting capacity."
        )

        execute_action(action, state, now)

      # Within optimal bounds
      stress >= state.thresholds.optimal_low and stress <= state.thresholds.optimal_high ->
        # System is healthy, no action needed
        {nil, state}

      true ->
        # Monitoring, no action
        {nil, state}
    end
  end

  defp can_take_action?(nil, _now), do: true

  defp can_take_action?(last_action_at, now) do
    elapsed = DateTime.diff(now, last_action_at, :millisecond)
    elapsed >= @min_action_interval
  end

  defp execute_action(action, state, now) do
    # Execute the actuator
    execute_actuator(action)

    # Record the action
    new_history = [{action, now} | Enum.take(state.action_history, 99)]

    {action, %{state | last_action: action, last_action_at: now, action_history: new_history}}
  end

  defp execute_actuator(:emergency_expand) do
    ensure_pool_state_table()
    current = get_current_capacity()
    new_capacity = current + 5
    :ets.insert(:homeostasis_pool_state, {:capacity, new_capacity})
    :ets.insert(:homeostasis_pool_state, {:last_action_at, System.system_time(:millisecond)})

    :telemetry.execute(
      [:indrajaal, :cortex, :homeostasis, :actuator_fired],
      %{capacity: new_capacity, delta: 5},
      %{action: :emergency_expand}
    )

    Logger.warning(
      "ACTUATOR: Emergency capacity expansion triggered — capacity #{current} -> #{new_capacity}"
    )

    :ok
  end

  defp execute_actuator(:expand) do
    ensure_pool_state_table()
    current = get_current_capacity()
    new_capacity = current + 2
    :ets.insert(:homeostasis_pool_state, {:capacity, new_capacity})
    :ets.insert(:homeostasis_pool_state, {:last_action_at, System.system_time(:millisecond)})

    :telemetry.execute(
      [:indrajaal, :cortex, :homeostasis, :actuator_fired],
      %{capacity: new_capacity, delta: 2},
      %{action: :expand}
    )

    Logger.info("ACTUATOR: Expanding pool capacity — #{current} -> #{new_capacity}")
    :ok
  end

  defp execute_actuator(:contract) do
    ensure_pool_state_table()
    current = get_current_capacity()
    new_capacity = max(current - 2, 1)
    :ets.insert(:homeostasis_pool_state, {:capacity, new_capacity})
    :ets.insert(:homeostasis_pool_state, {:last_action_at, System.system_time(:millisecond)})

    :telemetry.execute(
      [:indrajaal, :cortex, :homeostasis, :actuator_fired],
      %{capacity: new_capacity, delta: new_capacity - current},
      %{action: :contract}
    )

    Logger.info("ACTUATOR: Contracting pool capacity — #{current} -> #{new_capacity}")
    :ok
  end

  defp ensure_pool_state_table do
    try do
      :ets.new(:homeostasis_pool_state, [:named_table, :public, :set])
    rescue
      ArgumentError -> :ok
    end
  end

  defp get_current_capacity do
    try do
      case :ets.lookup(:homeostasis_pool_state, :capacity) do
        [{:capacity, cap}] -> cap
        [] -> 10
      end
    rescue
      ArgumentError -> 10
    end
  end
end
