defmodule Indrajaal.Cybernetic.OODA.Loop do
  @moduledoc """
  The Cybernetic OODA Loop State Machine.
  Cycles through Observe -> Orient -> Decide -> Act.
  Enforces quality gates and latency constraints.
  """
  use GenServer
  require Logger
  alias Indrajaal.Logging.Control
  alias Indrajaal.Observability.ZenohPublisher

  # State Definition
  defstruct [
    # :observe | :orient | :decide | :act
    :phase,
    # Data accumulated during the loop
    :context,
    # Timestamp of loop start
    :start_time,
    # Total cycles completed
    :cycle_count
  ]

  # @latency_target_ms 1000 # Standard Loop
  @min_data_quality 80
  @min_decision_confidence 70
  @cycle_delay_ms 10_000

  # Observation timeout reduced from 5000ms to 500ms (SC-OODA-007)
  # Analysis showed 5000ms is too long - allows complete system state change without detection
  @observation_timeout_ms 500

  # Sensor health tracking for silent failure detection (SC-OODA-008)
  # Note: @sensor_retry_limit reserved for future exponential backoff implementation

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def emergency_loop do
    GenServer.cast(__MODULE__, :emergency_loop)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    Logger.info("🧠 OODA Loop: Initializing Cortex...")

    state = %__MODULE__{
      phase: :waiting_for_sensors,
      context: %{},
      start_time: System.monotonic_time(:millisecond),
      cycle_count: 0
    }

    emit_telemetry(:init, state)

    # Fast OODA: Immediate sensor discovery attempt
    send(self(), :check_homeostasis)

    {:ok, state}
  end

  @impl true
  def handle_info(:check_homeostasis, state) do
    # Homeostasis Check Phase (SC-OODA-001)
    if GenServer.whereis(Indrajaal.System.ResourceMonitor) do
      Logger.info("🧠 OODA Loop: Homeostasis Sensors DETECTED. Starting loop.")

      Indrajaal.Observability.FractalLogger.segment("OODA", "Cortex Waking Up", %{
        status: :healthy
      })

      schedule_next_phase(:observe)
      {:noreply, %{state | phase: :observe}}
    else
      Logger.warning("🧠 OODA Loop: Homeostasis Sensors NOT detected. Retrying in 1s...")
      Process.send_after(self(), :check_homeostasis, 1000)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:observe, state) do
    # Directed Telescope: Log L5 internal sentience transition
    Logger.debug("🔭 Telescope: OODA Entering OBSERVE phase (Cycle ##{state.cycle_count})")

    # Fetch metrics from ResourceMonitor with proper error handling (SC-OODA-007, SC-OODA-008)
    # Using reduced timeout (500ms instead of 5000ms) per robustness analysis
    {metrics, sensor_health} = fetch_metrics_with_health()

    # Enhanced quality metric: considers both data validity and sensor health
    # (Fix for silent failure that bypassed quality gates)
    data_quality = calculate_observation_quality(metrics, sensor_health)

    new_context =
      state.context
      |> Map.put(:metrics, metrics)
      |> Map.put(:sensor_health, sensor_health)
      |> Map.put(:observation_quality, data_quality)

    # Quality Gate: Data Sufficiency (Quint: observeQualityInvariant)
    if data_quality >= @min_data_quality do
      if Control.should_log?(:cortex_ooda, :debug) do
        Logger.debug(
          "OODA: Observation Complete (CPU: #{metrics.cpu}%, Mem: #{metrics.memory}%, Quality: #{data_quality}%)"
        )
      end

      emit_telemetry(:observe_complete, state, %{
        data_quality: data_quality,
        cpu: metrics.cpu,
        sensor_health: sensor_health
      })

      schedule_next_phase(:orient)
      {:noreply, %{state | phase: :orient, context: new_context}}
    else
      # FIXED: Properly log and emit telemetry for sensor failures (no longer silent)
      if sensor_health == :failed do
        Logger.error("OODA: Sensor FAILURE detected - ResourceMonitor unavailable or timeout")
        emit_telemetry(:observe_sensor_failure, state, %{sensor_health: :failed})
      else
        Logger.warning(
          "OODA: Insufficient Data (Quality: #{data_quality}%), retrying Observation"
        )
      end

      emit_telemetry(:observe_retry, state, %{
        data_quality: data_quality,
        sensor_health: sensor_health
      })

      schedule_next_phase(:observe)
      {:noreply, %{state | context: new_context}}
    end
  end

  def handle_info(:orient, state) do
    Logger.debug(
      "🔭 Telescope: OODA Entering ORIENT phase (Analyzing #{map_size(state.context.metrics)} metrics)"
    )

    # Analyze metrics against configured thresholds (Homeostasis Analysis)
    thresholds =
      Application.get_env(:indrajaal, Indrajaal.System.ResourceMonitor)[:thresholds] || [cpu: 80]

    cpu_limit = thresholds[:cpu]
    # Implicit lower bound for scale down
    min_cpu_limit = 20

    strategy =
      cond do
        state.context.metrics.cpu > cpu_limit -> :scale_up
        state.context.metrics.cpu < min_cpu_limit -> :scale_down
        true -> :maintain
      end

    emit_telemetry(:orient_complete, state)
    schedule_next_phase(:decide)
    {:noreply, %{state | phase: :decide, context: Map.put(state.context, :strategy, strategy)}}
  end

  def handle_info(:decide, state) do
    strategy = state.context.strategy
    Logger.debug("🔭 Telescope: OODA Entering DECIDE phase (Strategy: #{strategy})")

    # Decision Logic
    decision =
      case strategy do
        :scale_up -> %{action: :scale_up, confidence: 90}
        :scale_down -> %{action: :scale_down, confidence: 80}
        :maintain -> %{action: :none, confidence: 100}
      end

    confidence = decision.confidence

    # Quality Gate: Confidence (Quint: decisionConfidenceInvariant)
    if confidence >= @min_decision_confidence do
      emit_telemetry(:decide_complete, state, %{confidence: confidence})
      schedule_next_phase(:act)
      {:noreply, %{state | phase: :act, context: Map.put(state.context, :decision, decision)}}
    else
      if Control.should_log?(:cortex_ooda, :info) do
        Logger.info(
          "OODA: Low confidence (#{confidence} < #{@min_decision_confidence}), skipping Action"
        )
      end

      emit_telemetry(:decide_skip, state, %{confidence: confidence})
      schedule_next_phase(:observe)
      {:noreply, %{state | phase: :observe}}
    end
  end

  def handle_info(:act, state) do
    action = state.context.decision.action

    # Execute action and capture result
    action_result =
      case action do
        :scale_up ->
          if Control.should_log?(:cortex_ooda, :info),
            do: Logger.info("🧠 OODA: Triggering Scale UP (FLAME)")

          # FLAME.Pool.scale_up(Indrajaal.FLAME.IntelligencePool) # Placeholder call
          {:ok, %{action: :scale_up}}

        :scale_down ->
          if Control.should_log?(:cortex_ooda, :info),
            do: Logger.info("🧠 OODA: Triggering Scale DOWN (FLAME)")

          # FLAME.Pool.scale_down(Indrajaal.FLAME.IntelligencePool) # Placeholder call
          {:ok, %{action: :scale_down}}

        :none ->
          {:ok, %{action: :none}}
      end

    # Loop Complete
    latency = System.monotonic_time(:millisecond) - state.start_time

    if Control.should_log?(:cortex_ooda, :info) do
      Logger.info("🔄 OODA Cycle ##{state.cycle_count + 1} Complete. Latency: #{latency}ms")
    end

    emit_telemetry(:act_complete, state, %{latency: latency})

    publish_to_zenoh("indrajaal/cybernetic/ooda", %{
      checkpoint: "CP-OODA-01",
      cycle: state.cycle_count + 1,
      latency_ms: latency,
      action: state.context.decision.action,
      phase: :act_complete
    })

    # Record learning episode to TrainingGym (SC-TRAIN-001)
    record_learning_episode(state, action_result)

    # Reset for next loop
    new_state = %{
      state
      | phase: :observe,
        context: %{},
        start_time: System.monotonic_time(:millisecond),
        cycle_count: state.cycle_count + 1
    }

    # SC-OODA-001: Implement hysteresis/delay between cycles to pr_event spinning
    Process.send_after(self(), :observe, @cycle_delay_ms)
    {:noreply, new_state}
  end

  # Fetch metrics with proper health tracking (SC-OODA-008)
  defp fetch_metrics_with_health do
    try do
      metrics =
        GenServer.call(Indrajaal.System.ResourceMonitor, :get_metrics, @observation_timeout_ms)

      {metrics, :healthy}
    rescue
      e in ArgumentError ->
        # Process not found
        Logger.warning("OODA: ResourceMonitor not available: #{inspect(e)}")
        {%{cpu: 0, memory: 0, error: :not_found}, :failed}
    catch
      :exit, {:timeout, _} ->
        # Timeout - sensor too slow (SC-OODA-007)
        Logger.warning("OODA: ResourceMonitor timeout after #{@observation_timeout_ms}ms")
        {%{cpu: 0, memory: 0, error: :timeout}, :degraded}

      :exit, reason ->
        # Other exit reasons
        Logger.error("OODA: ResourceMonitor exit: #{inspect(reason)}")
        {%{cpu: 0, memory: 0, error: reason}, :failed}
    end
  end

  # Calculate observation quality with sensor health consideration (SC-OODA-008)
  defp calculate_observation_quality(metrics, sensor_health) do
    base_quality =
      cond do
        Map.get(metrics, :error) -> 0
        metrics.cpu > 0 or metrics.memory > 0 -> 100
        true -> 0
      end

    # Apply health penalty
    case sensor_health do
      :healthy -> base_quality
      # Cap at 60% for degraded sensors
      :degraded -> min(base_quality, 60)
      # Failed sensors = 0 quality
      :failed -> 0
    end
  end

  @impl true
  def handle_cast(:emergency_loop, state) do
    Logger.warning("🚨 OODA: Emergency Loop Triggered (Fast-Track)")
    emit_telemetry(:emergency_loop, state)

    # Quint: emergencyLoop action resets to Observe immediately
    new_state = %{
      state
      | phase: :observe,
        start_time: System.monotonic_time(:millisecond)
    }

    # We might need to cancel pending timers if we used real scheduling,
    # but with simple messaging, we just process the next message as observe.
    # Ideally, we'd flush the mailbox of old phase messages, but for now:
    schedule_next_phase(:observe)
    {:noreply, new_state}
  end

  defp schedule_next_phase(phase) do
    # Internal phase transitions are immediate
    send(self(), phase)
  end

  defp emit_telemetry(event, state, measurements \\ %{}) do
    :telemetry.execute(
      [:indrajaal, :ooda, :loop],
      measurements,
      %{phase: state.phase, event: event, cycle: state.cycle_count}
    )
  end

  # Record learning episode to TrainingGym for RL training
  # SC-TRAIN-001: Wires OODA Act phase to TrainingGym for feedback learning
  defp record_learning_episode(state, action_result) do
    if Code.ensure_loaded?(Indrajaal.Cortex.Evolution.TrainingGym) do
      case GenServer.whereis(Indrajaal.Cortex.Evolution.TrainingGym) do
        nil ->
          :ok

        _pid ->
          decision = state.context.decision
          metrics = Map.get(state.context, :metrics, %{})

          # Build state context for learning episode
          state_before = %{
            cycle: state.cycle_count,
            metrics: metrics,
            strategy: Map.get(state.context, :strategy, :unknown)
          }

          action_data = %{
            action: decision.action,
            confidence: Map.get(decision, :confidence, 70)
          }

          case action_result do
            {:ok, result} ->
              reward = calculate_ooda_reward(decision.action, :ok)

              Indrajaal.Cortex.Evolution.TrainingGym.record_success(
                state_before,
                action_data,
                Map.merge(result, %{reward: reward})
              )

            {:error, reason} ->
              reward = calculate_ooda_reward(decision.action, :error)

              Indrajaal.Cortex.Evolution.TrainingGym.record_near_miss(
                state_before,
                action_data,
                %{error: reason, reward: reward}
              )
          end
      end
    end

    :ok
  rescue
    _ -> :ok
  end

  # Calculate reward based on action and result
  defp calculate_ooda_reward(action, result) do
    case {action, result} do
      {:scale_up, :ok} -> 1.0
      {:scale_down, :ok} -> 0.8
      {:none, :ok} -> 0.5
      {_, :error} -> -1.0
      _ -> 0.0
    end
  end

  # SC-ZTEST-008: Dual-write — log fallback first, then best-effort Zenoh publish.
  defp publish_to_zenoh(topic, payload) do
    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=#{payload[:checkpoint]} topic=#{topic} " <>
        "timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    )

    try do
      ZenohPublisher.publish_async(topic, payload)
    rescue
      _ -> :ok
    end
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}
end
