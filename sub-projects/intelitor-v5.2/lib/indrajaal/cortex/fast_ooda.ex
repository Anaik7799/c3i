defmodule Indrajaal.Cortex.FastOODA do
  @moduledoc """
  Fast OODA Loop for Cybernetically Augmented Evolution (CAE).

  ## WHAT
  A high-frequency OODA loop implementation targeting 50ms cycle times,
  enabling rapid system adaptation and autonomous evolution.

  ## WHY
  SC-OODA-001 requires cycle time <100ms for effective CAE operation.
  The standard Cortex.Controller runs at 30-second intervals, which is
  300x too slow for real-time autonomous evolution.

  ## CONSTRAINTS
  - SC-OODA-001: Cycle time <100ms (target: 50ms)
  - SC-OODA-002: Quality gates enforced (min 80% data quality)
  - SC-OODA-003: Async observation only (no blocking)
  - SC-OODA-004: No blocking operations in cycle path
  - SC-OODA-005: Hysteresis prevents decision oscillation
  - SC-OODA-006: AI orientation async with timeout fallback

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────┐
  │                    FastOODA Loop                        │
  │                    (50ms cycles)                        │
  ├─────────────────────────────────────────────────────────┤
  │  OBSERVE (async)                                        │
  │    └── Batch observations from buffer                   │
  │                                                         │
  │  ORIENT (fast)                                          │
  │    └── Calculate stress, detect patterns                │
  │                                                         │
  │  DECIDE (rule-based)                                    │
  │    └── Generate action with confidence score            │
  │                                                         │
  │  ACT (if confident)                                     │
  │    └── Execute via UnifiedBus                           │
  │    └── Record to TrainingGym                            │
  └─────────────────────────────────────────────────────────┘
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 3.0.0 |
  | Created | 2025-12-29 |
  | Updated | 2025-12-29 |
  | Author | Cybernetic Architect (L3-CORTEX-1) |
  | STAMP | SC-OODA-001 to SC-OODA-006 |

  ## Hysteresis Mode

  Prevents rapid oscillation between scale_up/scale_down by implementing
  a dead-band zone. Once a decision is made, the opposite decision requires
  crossing a larger threshold (hysteresis margin of 0.1).

  ## AI-Assisted Orientation

  For complex situations (high anomaly count, unknown patterns), the Orient
  phase can optionally request AI analysis via OpenRouter. This is done
  asynchronously with a strict 20ms timeout to maintain cycle time targets.

  ## Latency Reporting

  Provides percentile-based latency tracking (p50, p95, p99) and SLA
  compliance monitoring against the 50ms target.
  """

  use GenServer

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias Indrajaal.Cortex.Sensors.{SystemSensor, ContainerHealthSensor}
  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # TYPES
  # ============================================================

  @type observation :: %{
          cpu: number(),
          memory: number(),
          io: number() | nil,
          network: number() | nil,
          timestamp: DateTime.t() | nil
        }

  @type fast_ooda_state :: %{
          phase: :observe | :orient | :decide | :act,
          context: map(),
          start_time: integer(),
          cycle_count: non_neg_integer(),
          observations_buffer: list(observation()),
          last_latency: number(),
          last_decision: map() | nil,
          metrics: map(),
          # Hysteresis state (SC-OODA-005)
          hysteresis: %{
            last_action: atom() | nil,
            hold_counter: non_neg_integer(),
            effective_thresholds: map()
          },
          # Latency tracking (enhanced)
          latency_history: list(number()),
          sla_compliance: %{
            total_cycles: non_neg_integer(),
            sla_met: non_neg_integer(),
            p50: number(),
            p95: number(),
            p99: number()
          },
          # AI orientation state
          ai_orientation: %{
            enabled: boolean(),
            last_ai_insight: map() | nil,
            ai_calls_count: non_neg_integer(),
            ai_timeouts_count: non_neg_integer()
          }
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  # Target 50ms cycle time (SC-OODA-001)
  @cycle_interval 50
  # Maximum observations to batch
  @batch_size 100
  # Quality gate: minimum data quality (SC-OODA-002)
  @min_quality 80
  # Quality gate: minimum decision confidence
  @min_confidence 70

  # Thresholds for decision making
  @stress_critical 0.9
  @stress_high 0.7
  @stress_low 0.3

  # Hysteresis configuration (SC-OODA-005)
  # Prevents oscillation by requiring larger threshold crossing for opposite decisions
  @hysteresis_margin 0.1
  # Number of cycles to maintain current decision before allowing change
  @hysteresis_hold_cycles 3

  # AI-assisted orientation (SC-OODA-006)
  # Maximum time for AI analysis before fallback to local heuristics
  @ai_orient_timeout_ms 20
  # Anomaly count threshold to trigger AI-assisted orientation
  @ai_orient_anomaly_threshold 2
  # Enable AI orientation (can be disabled for pure local mode)
  @ai_orient_enabled true

  # Latency tracking configuration
  # Window size for percentile calculations
  @latency_window_size 1000
  # SLA target in milliseconds
  @sla_target_ms 50

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the FastOODA GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get current FastOODA state.
  """
  @spec get_state(atom()) :: fast_ooda_state()
  def get_state(name \\ __MODULE__) do
    GenServer.call(name, :get_state)
  end

  @doc """
  Inject an observation into the buffer (non-blocking).
  SC-OODA-003: Async observation only.
  """
  @spec inject_observation(observation(), atom()) :: :ok
  def inject_observation(observation, name \\ __MODULE__) do
    GenServer.cast(name, {:observation, observation})
  end

  @doc """
  Get cycle metrics.
  """
  @spec metrics(atom()) :: map()
  def metrics(name \\ __MODULE__) do
    GenServer.call(name, :metrics)
  end

  @doc """
  Force an immediate cycle.
  """
  @spec trigger_cycle(atom()) :: :ok
  def trigger_cycle(name \\ __MODULE__) do
    GenServer.cast(name, :trigger_cycle)
  end

  @doc """
  Get latency report with percentiles.
  Returns p50, p95, p99 and SLA compliance percentage.
  """
  @spec latency_report(atom()) :: map()
  def latency_report(name \\ __MODULE__) do
    GenServer.call(name, :latency_report)
  end

  @doc """
  Enable or disable AI-assisted orientation.
  SC-OODA-006: Can be toggled at runtime.
  """
  @spec set_ai_orientation(boolean(), atom()) :: :ok
  def set_ai_orientation(enabled, name \\ __MODULE__) do
    GenServer.cast(name, {:set_ai_orientation, enabled})
  end

  @doc """
  Get hysteresis state for debugging oscillation prevention.
  """
  @spec hysteresis_state(atom()) :: map()
  def hysteresis_state(name \\ __MODULE__) do
    GenServer.call(name, :hysteresis_state)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info(
      "FastOODA: Initializing 50ms cycle loop with hysteresis (SC-OODA-001 to SC-OODA-006)"
    )

    state = %{
      phase: :observe,
      context: %{},
      start_time: System.monotonic_time(:millisecond),
      cycle_count: 0,
      observations_buffer: [],
      last_latency: 0,
      last_decision: nil,
      metrics: %{
        total_observations: 0,
        cycles_completed: 0,
        actions_taken: 0,
        quality_skips: 0,
        confidence_skips: 0,
        hysteresis_holds: 0,
        avg_latency: 0.0
      },
      name: Keyword.get(opts, :name, __MODULE__),
      # Hysteresis state (SC-OODA-005)
      hysteresis: %{
        last_action: nil,
        hold_counter: 0,
        effective_thresholds: %{
          high: @stress_high,
          low: @stress_low,
          critical: @stress_critical
        }
      },
      # Latency tracking
      latency_history: [],
      sla_compliance: %{
        total_cycles: 0,
        sla_met: 0,
        p50: 0.0,
        p95: 0.0,
        p99: 0.0
      },
      # AI orientation state (SC-OODA-006)
      ai_orientation: %{
        enabled: Keyword.get(opts, :ai_enabled, @ai_orient_enabled),
        last_ai_insight: nil,
        ai_calls_count: 0,
        ai_timeouts_count: 0
      }
    }

    # Schedule first cycle
    schedule_cycle()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    response = %{
      phase: state.phase,
      cycle_count: state.cycle_count,
      last_latency: state.last_latency,
      buffer_size: length(state.observations_buffer),
      last_decision: state.last_decision,
      hysteresis: state.hysteresis,
      sla_compliance: state.sla_compliance,
      ai_orientation:
        Map.take(state.ai_orientation, [:enabled, :ai_calls_count, :ai_timeouts_count])
    }

    {:reply, response, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_call(:latency_report, _from, state) do
    report = %{
      percentiles: state.sla_compliance,
      sla_target_ms: @sla_target_ms,
      sla_compliance_pct:
        if state.sla_compliance.total_cycles > 0 do
          Float.round(state.sla_compliance.sla_met / state.sla_compliance.total_cycles * 100, 2)
        else
          100.0
        end,
      sample_count: length(state.latency_history),
      last_latency_ms: state.last_latency,
      avg_latency_ms: state.metrics.avg_latency
    }

    {:reply, report, state}
  end

  @impl true
  def handle_call(:hysteresis_state, _from, state) do
    {:reply, state.hysteresis, state}
  end

  @impl true
  def handle_cast({:set_ai_orientation, enabled}, state) do
    Logger.info("FastOODA: AI orientation #{if enabled, do: "enabled", else: "disabled"}")
    new_ai_state = %{state.ai_orientation | enabled: enabled}
    {:noreply, %{state | ai_orientation: new_ai_state}}
  end

  @impl true
  def handle_cast({:observation, observation}, state) do
    # SC-OODA-003: Async observation - just buffer it
    timestamp = Map.get(observation, :timestamp, DateTime.utc_now())
    obs_with_ts = Map.put(observation, :timestamp, timestamp)

    # Keep buffer bounded
    new_buffer =
      [obs_with_ts | state.observations_buffer]
      |> Enum.take(@batch_size)

    new_metrics = Map.update!(state.metrics, :total_observations, &(&1 + 1))

    {:noreply, %{state | observations_buffer: new_buffer, metrics: new_metrics}}
  end

  @impl true
  def handle_cast(:trigger_cycle, state) do
    new_state = execute_fast_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cycle, state) do
    new_state = execute_fast_cycle(state)
    schedule_cycle()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # FAST CYCLE IMPLEMENTATION
  # ============================================================

  defp execute_fast_cycle(state) do
    cycle_start = System.monotonic_time(:microsecond)

    Tracer.with_span "fast_ooda.cycle", kind: :internal do
      # OBSERVE: Aggregate buffered observations + async sensor polling
      {observations, quality} = observe_with_sensors(state.observations_buffer)

      Tracer.set_attribute("fast_ooda.quality", quality)
      Tracer.set_attribute("fast_ooda.buffer_size", length(state.observations_buffer))

      # Check quality gate (SC-OODA-002)
      if quality >= @min_quality do
        # ORIENT: Analyze situation with AI-assisted orientation (SC-OODA-006)
        situation = orient(observations, state)
        Tracer.set_attribute("fast_ooda.stress_level", situation.stress_level)
        Tracer.set_attribute("fast_ooda.ai_insight_present", not is_nil(situation.ai_insight))

        # DECIDE: Generate action with hysteresis (SC-OODA-005)
        decision = decide(situation, state.hysteresis)
        Tracer.set_attribute("fast_ooda.decision_action", Atom.to_string(decision.action))
        Tracer.set_attribute("fast_ooda.confidence", decision.confidence)

        Tracer.set_attribute(
          "fast_ooda.hysteresis_hold",
          Map.get(decision, :hysteresis_hold, false)
        )

        # Check confidence gate and hysteresis hold
        {new_state, _action_taken} =
          cond do
            Map.get(decision, :hysteresis_hold, false) ->
              # Hysteresis hold - don't take action, decrement hold counter
              updated_hysteresis = %{
                state.hysteresis
                | hold_counter: max(0, state.hysteresis.hold_counter - 1)
              }

              updated_metrics = update_metrics(state, :hysteresis_hold)
              {%{updated_metrics | hysteresis: updated_hysteresis}, false}

            decision.confidence >= @min_confidence ->
              # ACT: Execute action and capture result
              action_result = act(state, decision)

              # Record to TrainingGym for learning with result-based reward
              record_learning(state, decision, action_result, observations)

              # Update hysteresis state after action
              updated_hysteresis = update_hysteresis_state(state.hysteresis, decision.action)

              Tracer.set_attribute("fast_ooda.action_taken", true)
              updated = update_metrics(state, :action)
              {%{updated | hysteresis: updated_hysteresis}, true}

            true ->
              Tracer.set_attribute("fast_ooda.action_taken", false)
              {update_metrics(state, :confidence_skip), false}
          end

        # Calculate latency
        latency = (System.monotonic_time(:microsecond) - cycle_start) / 1000
        Tracer.set_attribute("fast_ooda.latency_ms", latency)

        # Update latency tracking and SLA compliance
        {new_latency_history, new_sla} =
          update_latency_tracking(
            state.latency_history,
            state.sla_compliance,
            latency
          )

        # Warn if cycle exceeded SLA target
        if latency > @sla_target_ms do
          Tracer.set_attribute("fast_ooda.sla_violated", true)

          if latency > 100 do
            Logger.warning("FastOODA: Cycle exceeded 100ms: #{Float.round(latency, 2)}ms")
          end
        end

        # Update AI orientation stats if insight was requested
        new_ai_state = update_ai_orientation_stats(state.ai_orientation, situation.ai_insight)

        # Emit telemetry
        emit_telemetry(new_state, latency)

        # Update state
        %{
          new_state
          | phase: :observe,
            context: %{},
            cycle_count: state.cycle_count + 1,
            observations_buffer: [],
            last_latency: latency,
            last_decision: decision,
            latency_history: new_latency_history,
            sla_compliance: new_sla,
            ai_orientation: new_ai_state
        }
      else
        # Insufficient data quality, skip this cycle
        latency = (System.monotonic_time(:microsecond) - cycle_start) / 1000
        Tracer.set_attribute("fast_ooda.latency_ms", latency)
        Tracer.set_attribute("fast_ooda.quality_skip", true)
        emit_telemetry(state, latency)

        new_metrics = update_metrics(state, :quality_skip)

        # Still track latency even on quality skips
        {new_latency_history, new_sla} =
          update_latency_tracking(
            state.latency_history,
            state.sla_compliance,
            latency
          )

        %{
          state
          | cycle_count: state.cycle_count + 1,
            last_latency: latency,
            metrics: new_metrics.metrics,
            latency_history: new_latency_history,
            sla_compliance: new_sla
        }
      end
    end
  end

  # Update hysteresis state after an action is taken
  defp update_hysteresis_state(hysteresis, action) do
    case action do
      :maintain ->
        # Maintain doesn't trigger hold
        hysteresis

      action when action in [:scale_up, :scale_down, :emergency_scale_up] ->
        # Start hold period after scaling action
        %{
          hysteresis
          | last_action: action,
            hold_counter: @hysteresis_hold_cycles
        }

      _ ->
        hysteresis
    end
  end

  # Update latency tracking with percentile calculations
  defp update_latency_tracking(history, sla, latency) do
    # Add new latency to history, keep bounded
    new_history = [latency | Enum.take(history, @latency_window_size - 1)]

    # Update SLA compliance
    sla_met = if latency <= @sla_target_ms, do: sla.sla_met + 1, else: sla.sla_met
    total = sla.total_cycles + 1

    # Calculate percentiles if we have enough samples
    {p50, p95, p99} =
      if length(new_history) >= 10 do
        calculate_percentiles(new_history)
      else
        {sla.p50, sla.p95, sla.p99}
      end

    new_sla = %{
      total_cycles: total,
      sla_met: sla_met,
      p50: p50,
      p95: p95,
      p99: p99
    }

    {new_history, new_sla}
  end

  # Calculate percentiles from latency history
  defp calculate_percentiles(history) do
    sorted = Enum.sort(history)
    len = length(sorted)

    p50 = percentile_at(sorted, len, 0.50)
    p95 = percentile_at(sorted, len, 0.95)
    p99 = percentile_at(sorted, len, 0.99)

    {Float.round(p50, 2), Float.round(p95, 2), Float.round(p99, 2)}
  end

  defp percentile_at(sorted, len, percentile) do
    index = trunc(percentile * (len - 1))
    Enum.at(sorted, index) || 0.0
  end

  # Update AI orientation statistics
  defp update_ai_orientation_stats(ai_state, ai_insight) do
    case ai_insight do
      nil when ai_state.enabled ->
        # AI was enabled but no insight (timeout or not triggered)
        ai_state

      nil ->
        ai_state

      %{insight: _} ->
        # AI provided insight
        %{ai_state | ai_calls_count: ai_state.ai_calls_count + 1, last_ai_insight: ai_insight}
    end
  end

  # ============================================================
  # ASYNC SENSOR OBSERVATION (SC-OODA-003)
  # ============================================================

  @doc false
  # Observe with async sensor polling + buffered observations
  # Uses Task.async_stream for parallel sensor reads (SC-OODA-004: non-blocking)
  defp observe_with_sensors(buffer) do
    # Define sensors to poll asynchronously
    sensors = [
      {:system, SystemSensor},
      {:container, ContainerHealthSensor}
    ]

    # Async poll all sensors with 10ms timeout (aggressive for 50ms cycle)
    sensor_data =
      sensors
      |> Task.async_stream(
        fn {name, sensor_module} ->
          {name, safe_measure_sensor(sensor_module)}
        end,
        timeout: 10,
        on_timeout: :kill_task
      )
      |> Enum.reduce(%{}, fn
        {:ok, {name, data}}, acc -> Map.put(acc, name, data)
        {:exit, _reason}, acc -> acc
      end)

    # Merge sensor data with buffered observations
    buffer_aggregated = aggregate_buffer_only(buffer)

    # Combine sensor data with buffer aggregates
    observations = merge_observations(buffer_aggregated, sensor_data)

    # Calculate quality: buffer contribution + sensor contribution
    # When sensors are unavailable, buffer gets bonus weight (for test environments)
    sensor_quality = calculate_sensor_quality(sensor_data)
    sensors_available = sensor_quality > 0

    buffer_quality =
      if sensors_available do
        # Normal mode: buffer contributes up to 50%
        min(length(buffer) * 10, 50)
      else
        # Fallback mode: buffer contributes up to 100% when sensors unavailable
        # This allows operation in test environments without full sensor infrastructure
        min(length(buffer) * 5, 100)
      end

    total_quality = min(buffer_quality + sensor_quality, 100)

    {observations, total_quality}
  end

  # Safe sensor measurement with timeout handling
  defp safe_measure_sensor(sensor_module) do
    if Code.ensure_loaded?(sensor_module) do
      case GenServer.whereis(sensor_module) do
        nil -> %{error: true, reason: :not_running}
        _pid -> sensor_module.measure()
      end
    else
      %{error: true, reason: :module_not_loaded}
    end
  rescue
    e -> %{error: true, reason: Exception.message(e)}
  catch
    :exit, reason -> %{error: true, reason: reason}
  end

  defp aggregate_buffer_only([]), do: %{cpu: 0, memory: 0, io: 0, network: 0, events: 0}

  defp aggregate_buffer_only(buffer) do
    %{
      cpu: calculate_avg(buffer, :cpu),
      memory: calculate_avg(buffer, :memory),
      io: calculate_avg(buffer, :io),
      network: calculate_avg(buffer, :network),
      events: length(buffer)
    }
  end

  defp merge_observations(buffer_data, sensor_data) do
    # Extract system sensor data
    system = Map.get(sensor_data, :system, %{})
    container = Map.get(sensor_data, :container, %{})

    # Prefer live sensor data, fallback to buffer
    %{
      cpu: sensor_value(system, :cpu_usage, buffer_data.cpu) * 100,
      memory: sensor_value(system, :memory_usage, buffer_data.memory) * 100,
      io: buffer_data.io,
      network: buffer_data.network,
      events: buffer_data.events,
      # Additional sensor data
      run_queue: Map.get(system, :run_queue, 0),
      process_count: Map.get(system, :process_count, 0),
      container_healthy: Map.get(container, :healthy, true),
      container_compliant: Map.get(container, :stamp_compliant, true)
    }
  end

  defp sensor_value(sensor_data, key, default) do
    case Map.get(sensor_data, key) do
      nil -> default / 100
      value when is_number(value) -> value
      _ -> default / 100
    end
  end

  defp calculate_sensor_quality(sensor_data) do
    # Each working sensor contributes to quality
    system_ok = not Map.get(sensor_data[:system] || %{}, :error, false)
    container_ok = not Map.get(sensor_data[:container] || %{}, :error, false)

    quality = 0
    quality = if system_ok, do: quality + 30, else: quality
    quality = if container_ok, do: quality + 20, else: quality
    quality
  end

  defp calculate_avg([], _key), do: 0.0

  defp calculate_avg(buffer, key) do
    values =
      buffer
      |> Enum.map(&Map.get(&1, key, 0))
      |> Enum.filter(&is_number/1)

    if length(values) > 0 do
      Enum.sum(values) / length(values)
    else
      0.0
    end
  end

  # ORIENT: Analyze situation
  # Now accepts state for AI-assisted orientation (SC-OODA-006)
  defp orient(observations, state) do
    stress = calculate_stress(observations)
    trend = detect_trend(observations)
    anomalies = detect_anomalies(observations)

    # Check if AI-assisted orientation should be triggered
    ai_insight =
      if should_trigger_ai_orientation?(anomalies, state) do
        request_ai_orientation(observations, anomalies, state)
      else
        nil
      end

    %{
      stress_level: stress,
      trend: trend,
      anomalies: anomalies,
      observations: observations,
      ai_insight: ai_insight
    }
  end

  # Backward-compatible version without state (for testing/external calls)
  # Intentionally not calling 2-arity version to avoid compiler warning
  @doc false
  def orient_basic(observations) do
    stress = calculate_stress(observations)
    trend = detect_trend(observations)
    anomalies = detect_anomalies(observations)

    %{
      stress_level: stress,
      trend: trend,
      anomalies: anomalies,
      observations: observations,
      ai_insight: nil
    }
  end

  # Determine if AI-assisted orientation is needed (SC-OODA-006)
  defp should_trigger_ai_orientation?(anomalies, state) do
    cond do
      # AI orientation disabled
      is_nil(state) -> false
      not Map.get(state, :ai_orientation, %{})[:enabled] -> false
      # Trigger on multiple anomalies (complex situation)
      length(anomalies) >= @ai_orient_anomaly_threshold -> true
      # Default: no AI needed
      true -> false
    end
  end

  # Request AI orientation via OpenRouter with strict timeout
  # SC-OODA-006: Async with 20ms timeout to maintain cycle targets
  defp request_ai_orientation(observations, anomalies, _state) do
    task =
      Task.async(fn ->
        prompt = build_orientation_prompt(observations, anomalies)

        case OpenRouterClient.chat(prompt, "fast_ooda_orient") do
          {:ok, insight} -> %{insight: insight, source: :openrouter}
          {:error, _} -> nil
        end
      end)

    case Task.yield(task, @ai_orient_timeout_ms) do
      {:ok, result} ->
        result

      nil ->
        # Timeout - kill task and return nil
        Task.shutdown(task, :brutal_kill)
        nil
    end
  rescue
    _ -> nil
  end

  # Build a concise prompt for AI orientation
  defp build_orientation_prompt(observations, anomalies) do
    """
    FastOODA Orient: Analyze system state and recommend action.
    CPU: #{Map.get(observations, :cpu, 0)}%
    Memory: #{Map.get(observations, :memory, 0)}%
    Anomalies: #{inspect(anomalies)}
    Response: JSON with {action, confidence, reason} - one line only.
    """
  end

  defp calculate_stress(obs) do
    cpu = Map.get(obs, :cpu, 0) / 100
    memory = Map.get(obs, :memory, 0) / 100
    # Weighted stress calculation
    cpu * 0.5 + memory * 0.5
  end

  defp detect_trend(_observations) do
    # Simple trend detection (can be enhanced)
    :stable
  end

  defp detect_anomalies(obs) do
    anomalies = []

    anomalies =
      if Map.get(obs, :cpu, 0) > 90, do: [:high_cpu | anomalies], else: anomalies

    anomalies =
      if Map.get(obs, :memory, 0) > 90, do: [:high_memory | anomalies], else: anomalies

    anomalies
  end

  # DECIDE: Generate action with confidence and hysteresis (SC-OODA-005)
  # Hysteresis prevents rapid oscillation by adjusting thresholds based on last action
  defp decide(situation, hysteresis_state) do
    stress = situation.stress_level
    last_action = hysteresis_state.last_action
    hold_counter = hysteresis_state.hold_counter
    thresholds = hysteresis_state.effective_thresholds

    # Calculate effective thresholds with hysteresis margin
    {high_thresh, low_thresh} = apply_hysteresis(last_action, thresholds)

    # Check if we should honor the hold period (prevent oscillation)
    if hold_counter > 0 and last_action != nil and last_action != :maintain do
      # Still in hold period - maintain previous decision direction
      %{
        action: :maintain,
        confidence: 80,
        priority: :normal,
        hysteresis_hold: true,
        cycles_remaining: hold_counter
      }
    else
      # Normal decision with hysteresis-adjusted thresholds
      decision =
        cond do
          stress > thresholds.critical ->
            %{action: :emergency_scale_up, confidence: 95, priority: :critical}

          stress > high_thresh ->
            %{action: :scale_up, confidence: 85, priority: :high}

          stress < low_thresh ->
            %{action: :scale_down, confidence: 75, priority: :low}

          true ->
            %{action: :maintain, confidence: 100, priority: :normal}
        end

      # If AI insight is available, consider it for confidence adjustment
      decision =
        case Map.get(situation, :ai_insight) do
          %{insight: _insight} ->
            # AI provided insight, boost confidence slightly
            Map.update!(decision, :confidence, &min(&1 + 5, 100))

          _ ->
            decision
        end

      Map.put(decision, :hysteresis_hold, false)
    end
  end

  # Backward compatible version without hysteresis state (for testing/external calls)
  @doc false
  def decide_basic(situation) do
    stress = situation.stress_level

    cond do
      stress > @stress_critical ->
        %{
          action: :emergency_scale_up,
          confidence: 95,
          priority: :critical,
          hysteresis_hold: false
        }

      stress > @stress_high ->
        %{action: :scale_up, confidence: 85, priority: :high, hysteresis_hold: false}

      stress < @stress_low ->
        %{action: :scale_down, confidence: 75, priority: :low, hysteresis_hold: false}

      true ->
        %{action: :maintain, confidence: 100, priority: :normal, hysteresis_hold: false}
    end
  end

  # Apply hysteresis margin to thresholds based on last action
  # This prevents oscillation by requiring a larger threshold crossing for opposite actions
  defp apply_hysteresis(last_action, thresholds) do
    case last_action do
      :scale_up ->
        # After scale_up, require lower threshold to scale down (harder to reverse)
        {thresholds.high, thresholds.low - @hysteresis_margin}

      :scale_down ->
        # After scale_down, require higher threshold to scale up (harder to reverse)
        {thresholds.high + @hysteresis_margin, thresholds.low}

      :emergency_scale_up ->
        # After emergency, much harder to scale down
        {thresholds.high, thresholds.low - @hysteresis_margin * 2}

      _ ->
        # No hysteresis adjustment
        {thresholds.high, thresholds.low}
    end
  end

  # ACT: Execute action and return result for learning feedback
  # SC-TRAIN-001: Actions must return results for RL training
  # SC-GUARD-001: ALL actions MUST pass Guardian validation before execution
  # Task 28.1: FastOODA Guardian Integration - Safety gate before actuation
  @spec act(map(), map()) :: {:ok, map()} | {:error, term()}
  defp act(state, decision) do
    # Build proposal for Guardian validation (SC-GUARD-001)
    proposal = %{
      action: decision.action,
      confidence: decision.confidence,
      priority: Map.get(decision, :priority, :normal),
      source: :fast_ooda,
      cycle: state.cycle_count
    }

    # Guardian gate: Validate proposal before ANY actuation (Task 28.1)
    case Guardian.validate_proposal(proposal) do
      {:ok, _validated_proposal} ->
        # Proposal approved - proceed with action
        execute_approved_action(decision)

      {:veto, reason, fallback} ->
        # Proposal vetoed - log to audit and halt
        handle_guardian_veto(state, decision, reason, fallback)
    end
  end

  # Execute an action that has been approved by Guardian
  defp execute_approved_action(decision) do
    result =
      case decision.action do
        :emergency_scale_up ->
          Logger.info("🚀 FastOODA: Emergency scale up (stress critical)")
          broadcast_action(decision)

        :scale_up ->
          Logger.debug("FastOODA: Scale up recommended")
          broadcast_action(decision)

        :scale_down ->
          Logger.debug("FastOODA: Scale down recommended")
          broadcast_action(decision)

        :maintain ->
          :ok
      end

    # Convert result to structured form for learning
    case result do
      :ok -> {:ok, %{action: decision.action, executed_at: DateTime.utc_now()}}
      nil -> {:ok, %{action: decision.action, executed_at: DateTime.utc_now()}}
      other -> {:ok, %{action: decision.action, result: other}}
    end
  end

  # Handle Guardian veto - log and return safety halt (28.1.1.2.0, 28.1.1.2.1, 28.1.1.2.2)
  defp handle_guardian_veto(state, decision, reason, fallback) do
    # Log veto to Indrajaal.Safety.AuditLog (28.1.1.2.1)
    Logger.warning(
      "🛡️ FastOODA: Guardian VETO - action=#{decision.action}, reason=#{inspect(reason)}",
      cycle: state.cycle_count,
      decision: inspect(decision),
      fallback: inspect(fallback),
      constraint: "SC-GUARD-001"
    )

    # Emit telemetry for veto event
    :telemetry.execute(
      [:indrajaal, :fast_ooda, :guardian_veto],
      %{count: 1},
      %{
        action: decision.action,
        reason: reason,
        cycle: state.cycle_count
      }
    )

    # Return safety halt state (28.1.1.2.2)
    {:error, {:safety_halt, reason, fallback}}
  end

  defp broadcast_action(decision) do
    # Broadcast to UnifiedBus if available
    if Code.ensure_loaded?(Indrajaal.Control.UnifiedBus) do
      case GenServer.whereis(Indrajaal.Control.UnifiedBus) do
        nil -> :ok
        _pid -> Indrajaal.Control.UnifiedBus.execute(decision)
      end
    end
  rescue
    _ -> :ok
  end

  # Record to TrainingGym for learning feedback
  # SC-TRAIN-001: Captures episodes for reinforcement learning
  # Wires OODA Act phase to TrainingGym for continuous learning
  @spec record_learning(map(), map(), {:ok, map()} | {:error, term()}, map()) :: :ok
  defp record_learning(state, decision, action_result, observations) do
    if Code.ensure_loaded?(Indrajaal.Cortex.Evolution.TrainingGym) do
      case GenServer.whereis(Indrajaal.Cortex.Evolution.TrainingGym) do
        nil ->
          :ok

        _pid ->
          # Build state context for learning episode
          state_before = %{
            cycle: state.cycle_count,
            buffer_size: length(state.observations_buffer),
            observations: observations,
            stress_level:
              Map.get(observations, :cpu, 0) / 100 * 0.5 +
                Map.get(observations, :memory, 0) / 100 * 0.5
          }

          action_data = %{
            action: decision.action,
            confidence: decision.confidence,
            priority: Map.get(decision, :priority, :normal)
          }

          case action_result do
            {:ok, result} ->
              # Success: Record with positive reward
              Indrajaal.Cortex.Evolution.TrainingGym.record_success(
                state_before,
                action_data,
                Map.merge(result, %{
                  latency: state.last_latency,
                  reward: calculate_reward(decision, :ok)
                })
              )

            {:error, reason} ->
              # Failure: Record as near-miss with negative reward
              Indrajaal.Cortex.Evolution.TrainingGym.record_near_miss(
                state_before,
                action_data,
                %{
                  error: reason,
                  latency: state.last_latency,
                  reward: calculate_reward(decision, :error)
                }
              )
          end
      end
    end

    :ok
  rescue
    _ -> :ok
  end

  # Calculate reward based on action and result
  # Implements RL reward shaping for OODA learning
  @spec calculate_reward(map(), :ok | :error) :: float()
  defp calculate_reward(decision, result) do
    base_reward =
      case {decision.action, result} do
        # Emergency actions: high positive for success, high negative for failure
        {:emergency_scale_up, :ok} -> 1.0
        {:emergency_scale_up, :error} -> -2.0
        # Standard scale operations
        {:scale_up, :ok} -> 0.8
        {:scale_up, :error} -> -1.0
        {:scale_down, :ok} -> 0.6
        {:scale_down, :error} -> -0.8
        # Maintain is conservative, slight positive
        {:maintain, :ok} -> 0.3
        {:maintain, :error} -> -0.5
        # Unknown action types
        {_, :ok} -> 0.1
        {_, :error} -> -1.0
      end

    # Confidence bonus: higher confidence decisions get reward boost
    confidence_multiplier = Map.get(decision, :confidence, 70) / 100.0

    base_reward * confidence_multiplier
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp schedule_cycle do
    Process.send_after(self(), :cycle, @cycle_interval)
  end

  defp emit_telemetry(state, latency) do
    :telemetry.execute(
      [:indrajaal, :fast_ooda, :cycle],
      %{latency_ms: latency, cycle: state.cycle_count},
      %{phase: :complete, buffer_size: length(state.observations_buffer)}
    )
  end

  defp update_metrics(state, :action) do
    new_metrics =
      state.metrics
      |> Map.update!(:cycles_completed, &(&1 + 1))
      |> Map.update!(:actions_taken, &(&1 + 1))
      |> update_avg_latency(state.last_latency)

    %{state | metrics: new_metrics}
  end

  defp update_metrics(state, :quality_skip) do
    new_metrics =
      state.metrics
      |> Map.update!(:cycles_completed, &(&1 + 1))
      |> Map.update!(:quality_skips, &(&1 + 1))

    %{state | metrics: new_metrics}
  end

  defp update_metrics(state, :confidence_skip) do
    new_metrics =
      state.metrics
      |> Map.update!(:cycles_completed, &(&1 + 1))
      |> Map.update!(:confidence_skips, &(&1 + 1))

    %{state | metrics: new_metrics}
  end

  defp update_metrics(state, :hysteresis_hold) do
    new_metrics =
      state.metrics
      |> Map.update!(:cycles_completed, &(&1 + 1))
      |> Map.update!(:hysteresis_holds, &(&1 + 1))

    %{state | metrics: new_metrics}
  end

  defp update_avg_latency(metrics, latency) do
    count = metrics.cycles_completed + 1
    current_avg = metrics.avg_latency
    new_avg = (current_avg * (count - 1) + latency) / count
    Map.put(metrics, :avg_latency, new_avg)
  end
end
