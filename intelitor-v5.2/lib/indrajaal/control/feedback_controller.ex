defmodule Indrajaal.Control.FeedbackController do
  @moduledoc """
  Feedback Controller — L3 Control Layer

  ## Design Intent

  GenServer implementing a discrete-time PID (Proportional-Integral-Derivative)
  feedback controller for homeostatic loops.  The controller is tuned using
  Ziegler-Nichols rules and includes three safety mechanisms:

  - **Anti-windup**: integrator is clamped to `[-integral_limit, integral_limit]`
    to prevent integrator wind-up when the actuator is saturated.
  - **Derivative kick prevention**: derivative is computed on process variable
    change (not error change) to avoid spikes on set-point steps.
  - **Output clamping**: controller output is bounded to `[output_min, output_max]`.

  Multiple independent control loops can be managed simultaneously; each loop
  is identified by a `loop_id` atom.  Loop state is stored in ETS for fast
  reads; the GenServer holds tuning parameters and bookkeeping.

  Broadcasts loop updates to PubSub topic `"feedback_controller:update"`.

  ## STAMP Constraints
  - SC-MATH-003: Homeostasis controller MUST use Ziegler-Nichols PID tuning
  - SC-HOM-001: Homeostatic loops MUST maintain set-point within ±5% tolerance

  ## Change History
  | Version | Date       | Author            | Change                    |
  |---------|------------|-------------------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :feedback_controller_loops
  @pubsub_topic "feedback_controller:update"
  @telemetry_event [:indrajaal, :control, :pid_update]
  @default_output_min -1.0
  @default_output_max 1.0
  @default_integral_limit 100.0

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type loop_id :: atom()

  @type pid_params :: %{
          kp: float(),
          ki: float(),
          kd: float(),
          output_min: float(),
          output_max: float(),
          integral_limit: float()
        }

  @type loop_state :: %{
          set_point: float(),
          last_process_value: float() | nil,
          integral: float(),
          last_output: float()
        }

  @type controller_state :: %{
          loops: %{loop_id() => pid_params()}
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the FeedbackController GenServer registered under `#{inspect(@name)}`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Sets the desired set-point for `loop_id`.  Creates the loop with default
  PID parameters if it does not yet exist.
  """
  @spec set_target(loop_id(), float()) :: :ok
  def set_target(loop_id, target)
      when is_atom(loop_id) and is_float(target) do
    GenServer.call(@name, {:set_target, loop_id, target})
  end

  @doc """
  Submits a new process-variable reading for `loop_id` and returns the
  controller output.  The PID update runs synchronously in the caller's
  context via a GenServer call so that the output is immediately available.
  """
  @spec update(loop_id(), float()) :: {:ok, float()} | {:error, :loop_not_found}
  def update(loop_id, process_value)
      when is_atom(loop_id) and is_float(process_value) do
    GenServer.call(@name, {:update, loop_id, process_value})
  end

  @doc """
  Returns the last computed controller output for `loop_id`, or `nil` if
  the loop has not yet been updated.
  """
  @spec get_output(loop_id()) :: float() | nil
  def get_output(loop_id) when is_atom(loop_id) do
    case :ets.lookup(@ets_table, loop_id) do
      [{^loop_id, state}] -> state.last_output
      _ -> nil
    end
  end

  @doc """
  Re-tunes the PID gains for `loop_id` using Ziegler-Nichols ultimate gain
  method parameters.

  - `ku` — ultimate gain (gain at which the loop oscillates)
  - `tu` — ultimate period in seconds

  The gains are derived as:
    - Kp = 0.6 · Ku
    - Ki = 2 · Kp / Tu
    - Kd = Kp · Tu / 8
  """
  @spec tune_pid(loop_id(), float(), float()) :: :ok | {:error, :loop_not_found}
  def tune_pid(loop_id, ku, tu)
      when is_atom(loop_id) and is_float(ku) and ku > 0.0 and is_float(tu) and tu > 0.0 do
    GenServer.call(@name, {:tune_pid, loop_id, ku, tu})
  end

  @doc """
  Submits a measured process-variable reading for `loop_id`.
  Alias for `update/2` using the task-spec naming convention.
  Returns `{:ok, correction}` or `{:error, :loop_not_found}`.
  """
  @spec measure(loop_id(), float()) :: {:ok, float()} | {:error, :loop_not_found}
  def measure(loop_id, process_value)
      when is_atom(loop_id) and is_float(process_value) do
    update(loop_id, process_value)
  end

  @doc """
  Returns the last computed correction (controller output) for `loop_id`.
  Alias for `get_output/1` using the task-spec naming convention.
  """
  @spec correction(loop_id()) :: float() | nil
  def correction(loop_id) when is_atom(loop_id) do
    get_output(loop_id)
  end

  @doc """
  Re-tunes the PID for `loop_id` using Ziegler-Nichols parameters
  `ku` (ultimate gain) and `tu` (ultimate period in seconds).

  Delegates to `tune_pid/3`.
  """
  @spec tune(loop_id(), float(), float()) :: :ok | {:error, :loop_not_found}
  def tune(loop_id, ku, tu)
      when is_atom(loop_id) and is_float(ku) and ku > 0.0 and is_float(tu) and tu > 0.0 do
    tune_pid(loop_id, ku, tu)
  end

  @doc """
  Returns the overall controller status map (all loops with PID params + state).
  Delegates to `control_stats/0`.
  """
  @spec status() :: %{loop_id() => map()}
  def status do
    control_stats()
  end

  @doc """
  Returns a map of per-loop statistics from ETS.
  """
  @spec control_stats() :: %{loop_id() => map()}
  def control_stats do
    GenServer.call(@name, :control_stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    Logger.info(
      "[FeedbackController] L3 started — PID with anti-windup + derivative kick prevention"
    )

    {:ok, %{loops: %{}}}
  end

  @impl true
  def handle_call({:set_target, loop_id, target}, _from, state) do
    params = Map.get(state.loops, loop_id, default_pid_params())
    new_loops = Map.put(state.loops, loop_id, params)

    loop_st = fetch_loop_state(loop_id)
    updated_st = %{loop_st | set_point: target}
    :ets.insert(@ets_table, {loop_id, updated_st})

    Logger.debug("[FeedbackController] loop=#{loop_id} set_point=#{target}")
    {:reply, :ok, %{state | loops: new_loops}}
  end

  @impl true
  def handle_call({:update, loop_id, pv}, _from, state) do
    case Map.get(state.loops, loop_id) do
      nil ->
        {:reply, {:error, :loop_not_found}, state}

      params ->
        loop_st = fetch_loop_state(loop_id)
        {output, new_loop_st} = pid_step(loop_st, pv, params)
        :ets.insert(@ets_table, {loop_id, new_loop_st})

        try do
          Phoenix.PubSub.broadcast(
            Indrajaal.PubSub,
            @pubsub_topic,
            {:pid_update, loop_id, output, pv}
          )
        rescue
          _ -> :ok
        end

        try do
          :telemetry.execute(
            @telemetry_event,
            %{output: output, pv: pv, set_point: loop_st.set_point},
            %{loop: loop_id}
          )
        rescue
          _ -> :ok
        end

        {:reply, {:ok, output}, state}
    end
  end

  @impl true
  def handle_call({:tune_pid, loop_id, ku, tu}, _from, state) do
    case Map.get(state.loops, loop_id) do
      nil ->
        {:reply, {:error, :loop_not_found}, state}

      params ->
        kp = 0.6 * ku
        ki = 2.0 * kp / tu
        kd = kp * tu / 8.0

        new_params = %{params | kp: kp, ki: ki, kd: kd}
        new_loops = Map.put(state.loops, loop_id, new_params)

        Logger.info("[FeedbackController] ZN-tuned loop=#{loop_id} kp=#{kp} ki=#{ki} kd=#{kd}")

        {:reply, :ok, %{state | loops: new_loops}}
    end
  end

  @impl true
  def handle_call(:control_stats, _from, state) do
    stats =
      Map.new(state.loops, fn {loop_id, params} ->
        loop_st = fetch_loop_state(loop_id)
        {loop_id, Map.merge(params, map_from_struct_like(loop_st))}
      end)

    {:reply, stats, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec pid_step(loop_state(), float(), pid_params()) :: {float(), loop_state()}
  defp pid_step(loop_st, pv, params) do
    error = loop_st.set_point - pv

    # Proportional term
    p_term = params.kp * error

    # Integral term with anti-windup clamping
    raw_integral = loop_st.integral + params.ki * error
    clamped_integral = clamp(raw_integral, -params.integral_limit, params.integral_limit)
    i_term = clamped_integral

    # Derivative on measurement (not on error) — prevents derivative kick
    d_term =
      case loop_st.last_process_value do
        nil ->
          0.0

        last_pv ->
          # Negative: rising PV reduces output
          params.kd * (last_pv - pv)
      end

    raw_output = p_term + i_term + d_term
    output = clamp(raw_output, params.output_min, params.output_max)

    new_state = %{
      loop_st
      | last_process_value: pv,
        integral: clamped_integral,
        last_output: output
    }

    {output, new_state}
  end

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))

  @spec fetch_loop_state(loop_id()) :: loop_state()
  defp fetch_loop_state(loop_id) do
    case :ets.lookup(@ets_table, loop_id) do
      [{^loop_id, st}] -> st
      _ -> %{set_point: 0.0, last_process_value: nil, integral: 0.0, last_output: 0.0}
    end
  end

  @spec default_pid_params() :: pid_params()
  defp default_pid_params do
    %{
      kp: 1.0,
      ki: 0.1,
      kd: 0.05,
      output_min: @default_output_min,
      output_max: @default_output_max,
      integral_limit: @default_integral_limit
    }
  end

  # Provides Map.from_struct-like behaviour for a plain map so stats are clean.
  @spec map_from_struct_like(loop_state()) :: map()
  defp map_from_struct_like(loop_st), do: loop_st
end
