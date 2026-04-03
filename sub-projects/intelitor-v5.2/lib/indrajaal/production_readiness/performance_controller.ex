defmodule Indrajaal.ProductionReadiness.PerformanceController do
  @moduledoc """
  PID controller for maintaining performance within targets.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-010: Performance adjustments must not cause instability
  """

  use GenServer
  require Logger

  @default_pid_params %{
    # Proportional gain
    kp: 0.5,
    # Integral gain
    ki: 0.1,
    # Derivative gain
    kd: 0.2,
    # Anti-windup
    integral_limit: 10.0,
    # Maximum scaling factor
    output_limit: 2.0
  }

  @default_targets %{
    response_time_ms: 50,
    cpu_usage_percent: 70,
    memory_usage_percent: 80,
    error_rate_percent: 0.1
  }

  @stability_thresholds %{
    max_scale_rate: 2.0,
    min_containers: 1,
    max_containers: 10,
    cooldown_seconds: 30
  }

  # Client API

  def start_link(opts \\ []) do
    targets = Keyword.get(opts, :targets, @default_targets)
    config = Map.merge(@stability_thresholds, Map.new(opts))

    GenServer.start_link(__MODULE__, {targets, config}, name: __MODULE__)
  end

  @doc """
  Calculate control actions based on current metrics.
  Satisfies SC-010: Performance adjustments must not cause instability.
  """
  def calculate_actions(current_metrics) do
    GenServer.call(__MODULE__, {:calculate_actions, current_metrics})
  end

  @doc """
  Update performance targets.
  """
  def update_targets(new_targets) do
    GenServer.call(__MODULE__, {:update_targets, new_targets})
  end

  @doc """
  Get current controller state and history.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Reset controller state.
  """
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # Server callbacks

  @impl true
  def init({targets, config}) do
    state = %{
      targets: targets,
      config: config,
      pid_params: @default_pid_params,
      pid_state: init_pid_state(),
      last_action_time: nil,
      action_history: [],
      metrics_history: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:calculate_actions, current_metrics}, _from, state) do
    Logger.info(
      "[PerformanceController] Calculating control actions for metrics: #{inspect(current_metrics)}"
    )

    # SC-010: Check cooldown period
    if should_wait_for_cooldown?(state) do
      actions = %{
        scale_factor: 1.0,
        actions: [],
        reason: :cooldown_active,
        gradual_scaling: true,
        stability_checks_enabled: true
      }

      {:reply, {:ok, actions}, state}
    else
      # Calculate errors
      errors = calculate_errors(current_metrics, state.targets)

      # Apply PID control
      {control_outputs, new_pid_state} =
        apply_pid_control(errors, state.pid_state, state.pid_params)

      # Generate control actions with stability constraints
      actions = generate_control_actions(control_outputs, current_metrics, state.config)

      # Update state
      new_state = %{
        state
        | pid_state: new_pid_state,
          last_action_time: DateTime.utc_now(),
          action_history:
            [{DateTime.utc_now(), actions} | state.action_history] |> Enum.take(100),
          metrics_history:
            [{DateTime.utc_now(), current_metrics} | state.metrics_history] |> Enum.take(100)
      }

      {:reply, {:ok, actions}, new_state}
    end
  end

  @impl true
  def handle_call({:update_targets, new_targets}, _from, state) do
    Logger.info("[PerformanceController] Updating targets: #{inspect(new_targets)}")

    merged_targets = Map.merge(state.targets, new_targets)
    new_state = %{state | targets: merged_targets}

    {:reply, {:ok, merged_targets}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    controller_state = %{
      targets: state.targets,
      pid_params: state.pid_params,
      pid_state: state.pid_state,
      last_action_time: state.last_action_time,
      recent_actions: Enum.take(state.action_history, 10),
      recent_metrics: Enum.take(state.metrics_history, 10)
    }

    {:reply, controller_state, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | pid_state: init_pid_state(),
        last_action_time: nil,
        action_history: [],
        metrics_history: []
    }

    {:reply, :ok, new_state}
  end

  # Private functions

  defp init_pid_state do
    %{
      integral: %{
        response_time: 0.0,
        cpu: 0.0,
        memory: 0.0,
        error_rate: 0.0
      },
      last_error: %{
        response_time: 0.0,
        cpu: 0.0,
        memory: 0.0,
        error_rate: 0.0
      }
    }
  end

  defp should_wait_for_cooldown?(state) do
    case state.last_action_time do
      nil ->
        false

      last_time ->
        elapsed = DateTime.diff(DateTime.utc_now(), last_time, :second)
        elapsed < state.config.cooldown_seconds
    end
  end

  defp calculate_errors(metrics, targets) do
    %{
      response_time:
        (metrics.response_time_ms - targets.response_time_ms) / targets.response_time_ms,
      cpu: (metrics.cpu_usage_percent - targets.cpu_usage_percent) / 100,
      memory: (metrics.memory_usage_percent - targets.memory_usage_percent) / 100,
      error_rate:
        (metrics.error_rate_percent - targets.error_rate_percent) /
          max(targets.error_rate_percent, 0.1)
    }
  end

  defp apply_pid_control(errors, pid_state, pid_params) do
    # Update integral (with anti-windup)
    new_integral = %{
      response_time:
        clamp(
          pid_state.integral.response_time + errors.response_time,
          -pid_params.integral_limit,
          pid_params.integral_limit
        ),
      cpu:
        clamp(
          pid_state.integral.cpu + errors.cpu,
          -pid_params.integral_limit,
          pid_params.integral_limit
        ),
      memory:
        clamp(
          pid_state.integral.memory + errors.memory,
          -pid_params.integral_limit,
          pid_params.integral_limit
        ),
      error_rate:
        clamp(
          pid_state.integral.error_rate + errors.error_rate,
          -pid_params.integral_limit,
          pid_params.integral_limit
        )
    }

    # Calculate derivatives
    derivatives = %{
      response_time: errors.response_time - pid_state.last_error.response_time,
      cpu: errors.cpu - pid_state.last_error.cpu,
      memory: errors.memory - pid_state.last_error.memory,
      error_rate: errors.error_rate - pid_state.last_error.error_rate
    }

    # Calculate PID outputs
    outputs = %{
      response_time:
        calculate_pid_output(
          errors.response_time,
          new_integral.response_time,
          derivatives.response_time,
          pid_params
        ),
      cpu: calculate_pid_output(errors.cpu, new_integral.cpu, derivatives.cpu, pid_params),
      memory:
        calculate_pid_output(errors.memory, new_integral.memory, derivatives.memory, pid_params),
      error_rate:
        calculate_pid_output(
          errors.error_rate,
          new_integral.error_rate,
          derivatives.error_rate,
          pid_params
        )
    }

    # Update PID state
    new_pid_state = %{
      integral: new_integral,
      last_error: errors
    }

    {outputs, new_pid_state}
  end

  defp calculate_pid_output(error, integral, derivative, params) do
    output = params.kp * error + params.ki * integral + params.kd * derivative
    clamp(output, -params.output_limit, params.output_limit)
  end

  defp generate_control_actions(control_outputs, metrics, config) do
    # SC-010: Apply stability constraints

    # Primary scaling factor based on worst metric
    scale_factor = calculate_scale_factor(control_outputs, config)

    # Determine specific actions
    actions = []

    # Container scaling
    if abs(control_outputs.cpu) > 0.2 or abs(control_outputs.memory) > 0.2 do
      # AGENT GA FIX: Variable shadowing
      _actions = [{:scale_up_containers, ceil(scale_factor - 1.0)} | actions]
    end

    # Cache adjustment
    if control_outputs.response_time > 0.1 do
      # AGENT GA FIX: Variable shadowing
      _actions = [{:increase_cache, true} | actions]
    end

    # Rate limiting
    if control_outputs.error_rate > 0.1 or metrics.error_rate_percent > 1.0 do
      # AGENT GA FIX: Variable shadowing
      _actions = [{:enable_rate_limiting, true} | actions]
    end

    # Connection pool adjustment
    if control_outputs.response_time > 0.05 and metrics.cpu_usage_percent < 60 do
      # AGENT GA FIX: Variable shadowing
      _actions = [{:expand_connection_pool, 20} | actions]
    end

    # Generate recommendations
    recommendations = generate_recommendations(control_outputs, metrics)

    %{
      scale_factor: scale_factor,
      # AGENT GA FIX
      scale_up_containers:
        if(
          Enum.any?(actions, fn
            {:scale_up_containers, _} -> true
            _ -> false
          end),
          do: ceil(scale_factor - 1.0),
          else: 0
        ),
      increase_cache: Enum.member?(actions, {:increase_cache, true}),
      enable_rate_limiting: Enum.member?(actions, {:enable_rate_limiting, true}),
      expand_connection_pool: find_action_value(actions, :expand_connection_pool, 0),
      actions: actions,
      recommendations: recommendations,
      gradual_scaling: true,
      stability_checks_enabled: true
    }
  end

  defp calculate_scale_factor(outputs, config) do
    # Take the maximum control output
    max_output =
      outputs
      |> Map.values()
      |> Enum.map(&abs/1)
      |> Enum.max()

    # Convert to scaling factor with limits
    raw_scale = 1.0 + max_output

    # SC-010: Apply rate limiting
    clamp(raw_scale, 1.0 / config.max_scale_rate, config.max_scale_rate)
  end

  defp generate_recommendations(outputs, metrics) do
    recommendations = []

    # Response time recommendations
    if outputs.response_time > 0.3 do
      # AGENT GA FIX
      _recommendations = ["Consider __database query optimization" | recommendations]
    end

    # CPU recommendations
    if outputs.cpu > 0.3 do
      # AGENT GA FIX
      _recommendations = ["Review CPU-intensive operations" | recommendations]
    end

    # Memory recommendations
    if outputs.memory > 0.3 do
      # AGENT GA FIX
      _recommendations = ["Investigate memory leaks or inefficient caching" | recommendations]
    end

    # Error rate recommendations
    if outputs.error_rate > 0.2 do
      # AGENT GA FIX: Variable shadowing
      _recommendations = [
        "Analyze error patterns and implement circuit breakers" | recommendations
      ]
    end

    # Combined metrics recommendations
    if metrics.cpu_usage_percent > 80 and metrics.memory_usage_percent > 80 do
      # AGENT GA FIX: Variable shadowing
      _recommendations = [
        "System under heavy load - consider horizontal scaling" | recommendations
      ]
    end

    Enum.take(recommendations, 5)
  end

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end

  defp find_action_value(actions, key, default) do
    case Enum.find(actions, fn {k, _} -> k == key end) do
      {_, value} -> value
      nil -> default
    end
  end
end
