defmodule Indrajaal.Substrate.L1.HomeostaticRegulator do
  @moduledoc """
  ## Design Intent
  L1 substrate homeostatic regulator — GenServer implementing a multi-variable
  PID controller for maintaining system variables within configurable set-point
  ranges. Unlike the L3 variant which targets a single process variable, this
  L1 regulator manages multiple named variables simultaneously, each with
  independent Kp/Ki/Kd gains.

  PID algorithm per variable (Ziegler-Nichols compatible, SC-MATH-003):
    error(t)     = setpoint - measured_value
    P            = Kp × error
    I(t)        += Ki × error × dt   (anti-windup clamped to ±10)
    D            = Kd × (error - prev_error) / dt
    output(t)    = P + I + D         (clamped to output bounds)

  Regulation cycle: 1 s (default). Each variable is regulated independently
  using its last received measurement. Corrections broadcast to PubSub topic
  "substrate:l1_homeostatic_correction".

  Default gains (Kp=0.6, Ki=0.1, Kd=0.3) satisfy Ziegler-Nichols quarter-
  decay criterion for typical substrate variables.

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-S1-001:  Cybernetic VSM S1 subsystem — ENFORCED
  - SC-S1-002:  S1 feedback loops — ENFORCED
  - SC-MATH-003: Homeostasis Ziegler-Nichols PID — ENFORCED
  - SC-HOM-001:  Homeostatic controller — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                       |
  |---------|------------|--------|------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis (L1)   |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "substrate:l1_homeostatic_correction"

  @default_kp 0.6
  @default_ki 0.1
  @default_kd 0.3
  @default_setpoint 0.5
  @default_output_min -1.0
  @default_output_max 1.0
  @integral_clamp 10.0
  @cycle_ms 1_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type variable_name :: atom() | String.t()
  @type gains :: %{kp: float(), ki: float(), kd: float()}
  @type set_point :: float()
  @type variable_state :: %{
          setpoint: set_point(),
          measured_value: float(),
          output: float(),
          error_integral: float(),
          prev_error: float(),
          kp: float(),
          ki: float(),
          kd: float(),
          output_min: float(),
          output_max: float()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Configure or update the set-point for a named variable.

  If the variable doesn't exist yet it is created with default gains.
  Options:
    - `:setpoint`    (float)
    - `:kp`          (float)
    - `:ki`          (float)
    - `:kd`          (float)
    - `:output_min`  (float)
    - `:output_max`  (float)

  Returns `:ok`.
  """
  @spec set_point(variable_name(), keyword()) :: :ok
  def set_point(var_name, opts \\ []) do
    GenServer.call(@name, {:set_point, var_name, opts})
  end

  @doc """
  Submit a new measurement for a variable. The next regulation cycle will use it.
  Returns `:ok`.
  """
  @spec measure(variable_name(), float()) :: :ok
  def measure(var_name, value) when is_float(value) do
    GenServer.cast(@name, {:measure, var_name, value})
  end

  @doc """
  Immediately compute and return the PID correction for `var_name`.
  Does NOT update stored state — read-only computation based on last measurement.
  """
  @spec correction(variable_name()) :: {:ok, float()} | {:error, :unknown_variable}
  def correction(var_name) do
    GenServer.call(@name, {:correction, var_name})
  end

  @doc """
  Returns a map of all variable states plus cycle metadata.
  """
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    initial_vars =
      Keyword.get(opts, :variables, [])
      |> Enum.into(%{}, fn {name, var_opts} ->
        {name, make_variable(var_opts)}
      end)

    state = %{
      variables: initial_vars,
      cycle_count: 0,
      dt: @cycle_ms / 1_000.0,
      started_at: DateTime.utc_now()
    }

    schedule_cycle()

    Logger.info("[L1_HOMEOSTATIC_REGULATOR] started — variables=#{map_size(initial_vars)}")
    {:ok, state}
  end

  @impl true
  def handle_call({:set_point, var_name, opts}, _from, state) do
    existing = Map.get(state.variables, var_name, make_variable([]))

    updated = %{
      existing
      | setpoint: Keyword.get(opts, :setpoint, existing.setpoint),
        kp: Keyword.get(opts, :kp, existing.kp),
        ki: Keyword.get(opts, :ki, existing.ki),
        kd: Keyword.get(opts, :kd, existing.kd),
        output_min: Keyword.get(opts, :output_min, existing.output_min),
        output_max: Keyword.get(opts, :output_max, existing.output_max),
        error_integral: 0.0,
        prev_error: 0.0
    }

    {:reply, :ok, %{state | variables: Map.put(state.variables, var_name, updated)}}
  end

  @impl true
  def handle_call({:correction, var_name}, _from, state) do
    case Map.get(state.variables, var_name) do
      nil ->
        {:reply, {:error, :unknown_variable}, state}

      var ->
        output = compute_pid_output(var, state.dt)
        {:reply, {:ok, output}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      variables: state.variables,
      cycle_count: state.cycle_count,
      dt: state.dt,
      started_at: state.started_at
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:measure, var_name, value}, state) do
    case Map.get(state.variables, var_name) do
      nil ->
        # Auto-create variable at measured value with default setpoint
        new_var = make_variable(setpoint: @default_setpoint, initial_value: value)

        {:noreply, %{state | variables: Map.put(state.variables, var_name, new_var)}}

      var ->
        updated = %{var | measured_value: value}
        {:noreply, %{state | variables: Map.put(state.variables, var_name, updated)}}
    end
  end

  @impl true
  def handle_info(:regulate, state) do
    {new_variables, corrections} =
      Enum.reduce(state.variables, {%{}, %{}}, fn {name, var}, {vars_acc, corr_acc} ->
        {updated_var, output} = step_pid(var, state.dt)
        {Map.put(vars_acc, name, updated_var), Map.put(corr_acc, name, output)}
      end)

    new_state = %{
      state
      | variables: new_variables,
        cycle_count: state.cycle_count + 1
    }

    broadcast(new_state, corrections)
    schedule_cycle()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec make_variable(keyword()) :: variable_state()
  defp make_variable(opts) do
    sp = Keyword.get(opts, :setpoint, @default_setpoint)
    init_val = Keyword.get(opts, :initial_value, sp)

    %{
      setpoint: sp,
      measured_value: init_val,
      output: 0.0,
      error_integral: 0.0,
      prev_error: 0.0,
      kp: Keyword.get(opts, :kp, @default_kp),
      ki: Keyword.get(opts, :ki, @default_ki),
      kd: Keyword.get(opts, :kd, @default_kd),
      output_min: Keyword.get(opts, :output_min, @default_output_min),
      output_max: Keyword.get(opts, :output_max, @default_output_max)
    }
  end

  @spec step_pid(variable_state(), float()) :: {variable_state(), float()}
  defp step_pid(var, dt) do
    output = compute_pid_output(var, dt)
    error = var.setpoint - var.measured_value

    new_integral =
      clamp(var.error_integral + var.ki * error * dt, -@integral_clamp, @integral_clamp)

    updated = %{var | output: output, error_integral: new_integral, prev_error: error}
    {updated, output}
  end

  @spec compute_pid_output(variable_state(), float()) :: float()
  defp compute_pid_output(var, dt) do
    error = var.setpoint - var.measured_value
    p_term = var.kp * error

    i_term =
      clamp(var.error_integral + var.ki * error * dt, -@integral_clamp, @integral_clamp)

    d_term = var.kd * (error - var.prev_error) / max(dt, 0.001)
    raw = p_term + i_term + d_term
    clamp(raw, var.output_min, var.output_max)
  end

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))

  defp schedule_cycle do
    Process.send_after(self(), :regulate, @cycle_ms)
  end

  defp broadcast(state, corrections) do
    payload = %{
      corrections: corrections,
      cycle_count: state.cycle_count,
      variable_count: map_size(state.variables),
      timestamp: DateTime.utc_now()
    }

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:l1_homeostatic_correction, payload}
      )
    rescue
      _ -> :ok
    end
  end
end
