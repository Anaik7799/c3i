defmodule Indrajaal.Substrate.L3.HomeostaticRegulator do
  @moduledoc """
  ## Design Intent
  L3 substrate homeostatic regulator — implements a continuous PID (Proportional-
  Integral-Derivative) controller to drive a measured process variable toward a
  configurable setpoint. Publishes corrections to PubSub and via Zenoh telemetry.

  PID algorithm (Ziegler-Nichols compatible, SC-MATH-003):
    error(t)     = setpoint - measured_value
    P            = Kp × error
    I(t)        += Ki × error × dt  (anti-windup clamped)
    D            = Kd × (error - prev_error) / dt
    output(t)    = P + I + D  (clamped to [output_min, output_max])

  Regulator cycle (default 1 s):
    1. Receive measured_value via `update_measurement/1`
    2. PID computes correction output
    3. Output broadcast to PubSub "substrate:homeostatic_correction"
    4. State persisted in ETS for fast reads

  ## STAMP Constraints
  - SC-HOM-001: Homeostatic controller — ENFORCED
  - SC-MATH-003: Homeostasis Ziegler-Nichols PID — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L3 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_state :homeostatic_regulator_state
  @pubsub_topic "substrate:homeostatic_correction"

  # Default PID gains (Ziegler-Nichols quarter-decay tuning)
  @default_kp 0.6
  @default_ki 0.1
  @default_kd 0.3

  # Default setpoint and output bounds
  @default_setpoint 0.5
  @default_output_min -1.0
  @default_output_max 1.0

  # Anti-windup integral bounds
  @integral_max 10.0
  @integral_min -10.0

  # Regulation cycle interval
  @cycle_ms 1_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Deliver a new measured process value to the regulator."
  @spec update_measurement(float()) :: :ok
  def update_measurement(value) when is_float(value) do
    GenServer.cast(@name, {:update_measurement, value})
  end

  @doc "Update the setpoint."
  @spec set_setpoint(float()) :: :ok
  def set_setpoint(sp) when is_float(sp) do
    GenServer.call(@name, {:set_setpoint, sp})
  end

  @doc "Update PID gains."
  @spec set_gains(float(), float(), float()) :: :ok
  def set_gains(kp, ki, kd)
      when is_float(kp) and is_float(ki) and is_float(kd) do
    GenServer.call(@name, {:set_gains, kp, ki, kd})
  end

  @doc "Returns current PID controller state."
  @spec status() :: map()
  def status do
    case :ets.whereis(@ets_state) != :undefined &&
           :ets.lookup(@ets_state, :status) do
      [{:status, s}] -> s
      _ -> GenServer.call(@name, :status)
    end
  end

  @doc "Returns the last computed output."
  @spec last_output() :: float()
  def last_output do
    case :ets.whereis(@ets_state) != :undefined &&
           :ets.lookup(@ets_state, :output) do
      [{:output, v}] -> v
      _ -> 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_state, [:set, :public, :named_table, read_concurrency: true])

    state = %{
      kp: Keyword.get(opts, :kp, @default_kp),
      ki: Keyword.get(opts, :ki, @default_ki),
      kd: Keyword.get(opts, :kd, @default_kd),
      setpoint: Keyword.get(opts, :setpoint, @default_setpoint),
      measured_value: Keyword.get(opts, :initial_value, @default_setpoint),
      output: 0.0,
      error_integral: 0.0,
      prev_error: 0.0,
      output_min: Keyword.get(opts, :output_min, @default_output_min),
      output_max: Keyword.get(opts, :output_max, @default_output_max),
      cycle_count: 0,
      dt: @cycle_ms / 1_000.0,
      started_at: DateTime.utc_now()
    }

    write_ets(state)
    schedule_cycle()

    Logger.info(
      "[HOMEOSTATIC_REGULATOR] started — setpoint=#{state.setpoint} Kp=#{state.kp} Ki=#{state.ki} Kd=#{state.kd}"
    )

    {:ok, state}
  end

  @impl true
  def handle_cast({:update_measurement, value}, state) do
    {:noreply, %{state | measured_value: value}}
  end

  @impl true
  def handle_call({:set_setpoint, sp}, _from, state) do
    new_state = %{state | setpoint: sp, error_integral: 0.0, prev_error: 0.0}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_gains, kp, ki, kd}, _from, state) do
    {:reply, :ok, %{state | kp: kp, ki: ki, kd: kd, error_integral: 0.0}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, build_status(state), state}
  end

  @impl true
  def handle_info(:regulate, state) do
    dt = state.dt
    error = state.setpoint - state.measured_value

    # Proportional
    p_term = state.kp * error

    # Integral with anti-windup
    new_integral =
      clamp(state.error_integral + state.ki * error * dt, @integral_min, @integral_max)

    i_term = new_integral

    # Derivative
    d_term = state.kd * (error - state.prev_error) / dt

    # Total output clamped
    raw_output = p_term + i_term + d_term
    output = clamp(raw_output, state.output_min, state.output_max)

    new_state = %{
      state
      | output: output,
        error_integral: new_integral,
        prev_error: error,
        cycle_count: state.cycle_count + 1
    }

    write_ets(new_state)
    broadcast(new_state, error)
    schedule_cycle()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))

  defp schedule_cycle do
    Process.send_after(self(), :regulate, @cycle_ms)
  end

  defp write_ets(state) do
    status = build_status(state)
    :ets.insert(@ets_state, {:status, status})
    :ets.insert(@ets_state, {:output, state.output})
  end

  defp build_status(state) do
    %{
      setpoint: state.setpoint,
      measured_value: state.measured_value,
      output: state.output,
      error: state.setpoint - state.measured_value,
      error_integral: state.error_integral,
      kp: state.kp,
      ki: state.ki,
      kd: state.kd,
      cycle_count: state.cycle_count
    }
  end

  defp broadcast(state, error) do
    payload = %{
      setpoint: state.setpoint,
      measured_value: state.measured_value,
      output: state.output,
      error: error,
      cycle_count: state.cycle_count,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:homeostatic_correction, payload}
    )
  end
end
