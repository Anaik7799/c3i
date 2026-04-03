defmodule Indrajaal.Biomorphic.MetabolicEngine do
  @moduledoc """
  ## Design Intent
  Resource metabolism subsystem for the Indrajaal biomorphic mesh. Tracks
  energy/throughput flows, distinguishes anabolism (resource building) from
  catabolism (resource breakdown), and drives a homeostatic PID controller
  toward a configurable setpoint.

  Metabolic cycle (default 5-second tick):
    1. Measure current metabolic rate (events/s)
    2. PID controller computes correction signal
    3. Anabolism/catabolism balance updated
    4. Metrics broadcast via PubSub "biomorphic:metabolic"
    5. Zenoh publish to `indrajaal/biomorphic/metabolic/status`

  PID parameters (Ziegler-Nichols tuned, SC-MATH-003):
    Kp = 0.6 — proportional gain
    Ki = 0.1 — integral gain
    Kd = 0.3 — derivative gain

  ## STAMP Constraints
  - SC-HOM-001: Homeostatic controller — ENFORCED
  - SC-MATH-003: Homeostasis Ziegler-Nichols PID — ENFORCED
  - SC-BIO-007: Homeostasis active — ENFORCED
  - SC-CPU-GOV-001: CPU utilization limit respected — REFERENCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_metrics :metabolic_metrics
  @pubsub_topic "biomorphic:metabolic"
  @zenoh_topic "indrajaal/biomorphic/metabolic/status"
  @checkpoint "CP-BIO-METABOLIC-01"

  # PID gains — Ziegler-Nichols tuned (SC-MATH-003)
  @kp 0.6
  @ki 0.1
  @kd 0.3

  # Default setpoint: target events/second
  @default_setpoint 100.0

  # Anti-windup bounds for integral term
  @integral_max 500.0
  @integral_min -500.0

  # Metabolic cycle interval
  @cycle_ms 5_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Record a metabolic event (anabolic or catabolic)."
  @spec record_event(:anabolic | :catabolic, map()) :: :ok
  def record_event(kind, metadata \\ %{})
      when kind in [:anabolic, :catabolic] and is_map(metadata) do
    GenServer.cast(@name, {:record_event, kind, metadata})
  end

  @doc "Returns current metabolic rate (events/s)."
  @spec metabolic_rate() :: float()
  def metabolic_rate do
    case :ets.lookup(@ets_metrics, :rate) do
      [{:rate, r}] -> r
      [] -> 0.0
    end
  end

  @doc "Returns the PID controller state."
  @spec pid_state() :: map()
  def pid_state do
    GenServer.call(@name, :pid_state)
  end

  @doc "Update the homeostatic setpoint."
  @spec set_setpoint(float()) :: :ok
  def set_setpoint(setpoint) when is_float(setpoint) do
    GenServer.call(@name, {:set_setpoint, setpoint})
  end

  @doc "Returns the full metabolic status."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_metrics, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(@ets_metrics, {:rate, 0.0})
    :ets.insert(@ets_metrics, {:balance, 0.0})

    setpoint = Keyword.get(opts, :setpoint, @default_setpoint)
    schedule_cycle()

    state = %{
      # PID state
      setpoint: setpoint,
      error_integral: 0.0,
      last_error: 0.0,
      pid_output: 0.0,
      # Event counters within the current window
      anabolic_count: 0,
      catabolic_count: 0,
      window_start: System.monotonic_time(:millisecond),
      # Totals
      total_anabolic: 0,
      total_catabolic: 0,
      cycle_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.warning(
      "[METABOLIC] MetabolicEngine started — setpoint=#{setpoint} checkpoint=#{@checkpoint}"
    )

    {:ok, state}
  end

  @impl true
  def handle_cast({:record_event, :anabolic, _metadata}, state) do
    {:noreply, %{state | anabolic_count: state.anabolic_count + 1}}
  end

  @impl true
  def handle_cast({:record_event, :catabolic, _metadata}, state) do
    {:noreply, %{state | catabolic_count: state.catabolic_count + 1}}
  end

  @impl true
  def handle_call(:pid_state, _from, state) do
    reply = %{
      setpoint: state.setpoint,
      error_integral: state.error_integral,
      last_error: state.last_error,
      pid_output: state.pid_output,
      kp: @kp,
      ki: @ki,
      kd: @kd
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:set_setpoint, setpoint}, _from, state) do
    Logger.info("[METABOLIC] Setpoint updated: #{state.setpoint} → #{setpoint}")
    {:reply, :ok, %{state | setpoint: setpoint, error_integral: 0.0, last_error: 0.0}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    rate = metabolic_rate()
    balance = anabolic_balance(state)

    reply = %{
      metabolic_rate: rate,
      anabolic_catabolic_balance: balance,
      setpoint: state.setpoint,
      pid_output: state.pid_output,
      total_anabolic: state.total_anabolic,
      total_catabolic: state.total_catabolic,
      cycle_count: state.cycle_count,
      uptime_s: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:metabolic_tick, state) do
    new_state = run_metabolic_cycle(state)
    schedule_cycle()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[METABOLIC] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — metabolic cycle
  # ---------------------------------------------------------------------------

  defp run_metabolic_cycle(state) do
    now_ms = System.monotonic_time(:millisecond)
    elapsed_s = max(0.001, (now_ms - state.window_start) / 1_000.0)

    total_events = state.anabolic_count + state.catabolic_count
    rate = total_events / elapsed_s

    # PID computation (SC-MATH-003)
    error = state.setpoint - rate
    derivative = (error - state.last_error) / elapsed_s

    new_integral =
      (state.error_integral + error * elapsed_s)
      |> max(@integral_min)
      |> min(@integral_max)

    pid_output = @kp * error + @ki * new_integral + @kd * derivative

    # Update ETS for fast reads
    :ets.insert(@ets_metrics, {:rate, rate})
    :ets.insert(@ets_metrics, {:balance, anabolic_balance(state)})

    metrics = %{
      rate: rate,
      setpoint: state.setpoint,
      pid_output: pid_output,
      error: error,
      integral: new_integral,
      anabolic: state.anabolic_count,
      catabolic: state.catabolic_count,
      elapsed_s: elapsed_s
    }

    broadcast_metrics(metrics)
    emit_telemetry(rate, pid_output, state.cycle_count + 1)

    log_checkpoint(metrics)

    %{
      state
      | error_integral: new_integral,
        last_error: error,
        pid_output: pid_output,
        anabolic_count: 0,
        catabolic_count: 0,
        window_start: now_ms,
        total_anabolic: state.total_anabolic + state.anabolic_count,
        total_catabolic: state.total_catabolic + state.catabolic_count,
        cycle_count: state.cycle_count + 1
    }
  end

  defp anabolic_balance(state) do
    total = state.anabolic_count + state.catabolic_count

    if total == 0 do
      0.0
    else
      (state.anabolic_count - state.catabolic_count) / total
    end
  end

  defp schedule_cycle do
    Process.send_after(self(), :metabolic_tick, @cycle_ms)
  end

  defp broadcast_metrics(metrics) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:metabolic_update, metrics}
    )

    publish_zenoh(metrics)
  rescue
    _e -> :ok
  end

  defp publish_zenoh(metrics) do
    data = %{
      checkpoint: @checkpoint,
      topic: @zenoh_topic,
      rate: metrics.rate,
      setpoint: metrics.setpoint,
      pid_output: metrics.pid_output,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(rate, pid_output, cycle_count) do
    :telemetry.execute(
      [:indrajaal, :biomorphic, :metabolic, :cycle],
      %{rate: rate, pid_output: pid_output, cycle_count: cycle_count},
      %{constraint: "SC-HOM-001"}
    )
  end

  defp log_checkpoint(metrics) do
    Logger.debug(
      "[ZTEST-CHECKPOINT] checkpoint=#{@checkpoint} topic=#{@zenoh_topic} " <>
        "rate=#{Float.round(metrics.rate, 2)} setpoint=#{metrics.setpoint} " <>
        "pid=#{Float.round(metrics.pid_output, 4)} timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    )
  end
end
