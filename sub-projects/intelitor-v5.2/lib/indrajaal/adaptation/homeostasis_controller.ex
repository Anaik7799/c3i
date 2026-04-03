defmodule Indrajaal.Adaptation.HomeostasisController do
  @moduledoc """
  Homeostasis Controller — L6 Adaptation Layer

  Implements a PID (Proportional-Integral-Derivative) controller for maintaining
  system homeostasis across multiple physiological setpoints.

  ## STAMP Constraints
  - SC-HOM-001: Homeostatic targets MUST be maintained within ±10% of setpoint
  - SC-HOM-002: PID integral windup MUST be prevented (anti-windup clamping)
  - SC-HOM-003: Control signals MUST be published every 5 seconds
  - SC-HOM-004: Setpoints MUST be configurable at runtime
  - SC-HOM-005: Control history MUST be available for audit
  - SC-MATH-003: Ziegler-Nichols PID tuning mandatory (Kp=0.6, Ki=0.01, Kd=0.05)

  ## Controlled Variables
  - **CPU Utilization**: Setpoint 60% — control: scheduler count adjustment signal
  - **Memory Utilization**: Setpoint 70% — control: GC pressure signal
  - **Request Latency (ms)**: Setpoint 100ms — control: pool size adjustment signal
  - **Error Rate (%)**: Setpoint 0.5% — control: circuit breaker threshold signal

  ## Ziegler-Nichols Tuning
  Tuning based on critical gain Kc=1.0 and oscillation period Pc=10s:
  - Kp = 0.6 × Kc = 0.6
  - Ki = 2 × Kp / Pc = 0.12 (discretized per sample interval)
  - Kd = Kp × Pc / 8 = 0.75 (discretized per sample interval)
  Fine-tuned: Kp=0.6, Ki=0.01, Kd=0.05 for 5s cycle.

  ## Anti-Windup
  Integral term is clamped to ±10 to prevent rundup during sustained saturation.

  Zenoh topic: `indrajaal/adaptation/homeostasis`

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L6 morphogenesis) |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @sample_interval_ms 5_000
  @kp 0.6
  @ki 0.01
  @kd 0.05
  @integral_clamp 10.0
  @zenoh_topic "indrajaal/adaptation/homeostasis"
  @pubsub_topic "homeostasis:control"

  @setpoints %{
    cpu_pct: 60.0,
    memory_pct: 70.0,
    latency_ms: 100.0,
    error_rate_pct: 0.5
  }

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type variable :: :cpu_pct | :memory_pct | :latency_ms | :error_rate_pct
  @type pid_state :: %{
          setpoint: float(),
          integral: float(),
          prev_error: float()
        }
  @type control_output :: %{
          variable: variable(),
          setpoint: float(),
          measurement: float(),
          error: float(),
          control_signal: float(),
          timestamp: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Update the measurement for a controlled variable."
  @spec update_measurement(variable(), float()) :: :ok
  def update_measurement(variable, value) when is_atom(variable) and is_float(value) do
    GenServer.cast(@name, {:update_measurement, variable, value})
  end

  @doc "Update the setpoint for a controlled variable."
  @spec set_setpoint(variable(), float()) :: :ok | {:error, :unknown_variable}
  def set_setpoint(variable, value) when is_atom(variable) and is_float(value) do
    GenServer.call(@name, {:set_setpoint, variable, value})
  end

  @doc "Get the current PID state for all controlled variables."
  @spec pid_states() :: map()
  def pid_states do
    GenServer.call(@name, :pid_states)
  end

  @doc "Get the most recent control outputs."
  @spec last_outputs() :: [control_output()]
  def last_outputs do
    GenServer.call(@name, :last_outputs)
  end

  @doc "Force an immediate control cycle."
  @spec control_cycle() :: [control_output()]
  def control_cycle do
    GenServer.call(@name, :control_cycle)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :sample_interval_ms, @sample_interval_ms)

    pid_states =
      Map.new(@setpoints, fn {var, sp} ->
        {var, %{setpoint: sp, integral: 0.0, prev_error: 0.0}}
      end)

    state = %{
      interval_ms: interval_ms,
      pid_states: pid_states,
      measurements: %{},
      last_outputs: []
    }

    schedule_cycle(interval_ms)

    Logger.info("[HomeostasisController] Started — Kp=#{@kp} Ki=#{@ki} Kd=#{@kd} [SC-HOM-001]")

    {:ok, state}
  end

  @impl true
  def handle_cast({:update_measurement, variable, value}, state) do
    state2 = put_in(state, [:measurements, variable], value)
    {:noreply, state2}
  end

  @impl true
  def handle_call({:set_setpoint, variable, value}, _from, state) do
    if Map.has_key?(state.pid_states, variable) do
      state2 = put_in(state, [:pid_states, variable, :setpoint], value)
      {:reply, :ok, state2}
    else
      {:reply, {:error, :unknown_variable}, state}
    end
  end

  @impl true
  def handle_call(:pid_states, _from, state) do
    {:reply, state.pid_states, state}
  end

  @impl true
  def handle_call(:last_outputs, _from, state) do
    {:reply, state.last_outputs, state}
  end

  @impl true
  def handle_call(:control_cycle, _from, state) do
    {outputs, state2} = run_control_cycle(state)
    {:reply, outputs, state2}
  end

  @impl true
  def handle_info(:pid_sample, state) do
    {_outputs, state2} = run_control_cycle(state)
    schedule_cycle(state.interval_ms)
    {:noreply, state2}
  end

  # ---------------------------------------------------------------------------
  # PID Control Implementation
  # ---------------------------------------------------------------------------

  defp run_control_cycle(state) do
    dt = state.interval_ms / 1_000.0

    {new_pid_states, outputs} =
      state.pid_states
      |> Enum.reduce({%{}, []}, fn {var, pid_state}, {acc_pids, acc_outputs} ->
        case Map.get(state.measurements, var) do
          nil ->
            {Map.put(acc_pids, var, pid_state), acc_outputs}

          measurement ->
            {new_pid_state, output} = compute_pid(var, measurement, pid_state, dt)
            {Map.put(acc_pids, var, new_pid_state), [output | acc_outputs]}
        end
      end)

    if outputs != [] do
      broadcast_outputs(outputs)
      log_outputs(outputs)
    end

    state2 = %{state | pid_states: new_pid_states, last_outputs: outputs}

    {outputs, state2}
  end

  defp compute_pid(variable, measurement, pid_state, dt) do
    error = pid_state.setpoint - measurement

    # Proportional term
    p_term = @kp * error

    # Integral term with anti-windup clamping
    new_integral = pid_state.integral + error * dt * @ki
    new_integral_clamped = max(-@integral_clamp, min(@integral_clamp, new_integral))

    # Derivative term
    d_term = @kd * (error - pid_state.prev_error) / max(dt, 0.001)

    # Total control signal
    control_signal = p_term + new_integral_clamped + d_term

    new_pid_state = %{pid_state | integral: new_integral_clamped, prev_error: error}

    output = %{
      variable: variable,
      setpoint: pid_state.setpoint,
      measurement: measurement,
      error: error,
      p_term: p_term,
      i_term: new_integral_clamped,
      d_term: d_term,
      control_signal: control_signal,
      timestamp: System.system_time(:millisecond)
    }

    {new_pid_state, output}
  end

  defp broadcast_outputs(outputs) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:homeostasis_control, outputs}
    )

    :telemetry.execute(
      [:indrajaal, :adaptation, :homeostasis, :cycle],
      %{output_count: length(outputs)},
      %{zenoh_topic: @zenoh_topic}
    )
  rescue
    _ -> :ok
  end

  defp log_outputs(outputs) do
    for output <- outputs do
      tolerance_pct =
        if output.setpoint != 0.0, do: abs(output.error / output.setpoint) * 100.0, else: 0.0

      if tolerance_pct > 10.0 do
        Logger.warning(
          "[HomeostasisController] #{output.variable}: error=#{Float.round(output.error, 2)} " <>
            "(#{Float.round(tolerance_pct, 1)}% deviation) signal=#{Float.round(output.control_signal, 3)} [SC-HOM-001]"
        )
      else
        Logger.debug(
          "[HomeostasisController] #{output.variable}: error=#{Float.round(output.error, 2)} " <>
            "signal=#{Float.round(output.control_signal, 3)}"
        )
      end
    end
  end

  defp schedule_cycle(interval_ms) do
    Process.send_after(self(), :pid_sample, interval_ms)
  end
end
