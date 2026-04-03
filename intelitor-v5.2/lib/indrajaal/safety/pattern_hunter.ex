defmodule Indrajaal.Safety.PatternHunter do
  @moduledoc """
  Enhanced Pre-Error Pattern Hunter - Predictive Threat Detection System (v2.0).

  ## What
  Proactively scans for "pre-error" signatures and threat patterns before they
  manifest as actual errors. Uses pattern recognition, heuristic analysis, and
  machine learning to identify degradation trajectories and security threats.

  ## Why
  Traditional error handling is reactive. The Pattern Hunter implements
  predictive defense by identifying patterns that precede errors:
  - Memory leak signatures (gradual increase before OOM)
  - Queue buildup patterns (message accumulation before timeout)
  - Resource exhaustion curves (disk/CPU approaching limits)
  - Behavioral anomalies (deviation from baseline)
  - Security threats (unauthorized access patterns)
  - Process spawn storms (runaway process creation)

  ## Pattern Types
  - :process_spawn_storm - Too many processes spawned rapidly
  - :memory_leak - Gradual memory increase
  - :error_cascade - Error rate spike
  - :timeout_pattern - Repeated timeouts
  - :resource_exhaustion - CPU/memory/file handles depleted
  - :suspicious_access - Unauthorized access attempts

  ## OODA Integration
  - OBSERVE: Continuous telemetry collection
  - ORIENT: Pattern matching against signatures + heuristic analysis
  - DECIDE: Risk scoring and threshold evaluation
  - ACT: Preemptive alerts to Sentinel/Guardian/SymbioticDefense

  ## Learning Capability
  Records new patterns discovered during runtime and updates signature database.
  Uses adaptive thresholds based on observed baseline behavior.

  ## Constraints
  - SC-OODA-001: Cycle time <100ms
  - SC-SEC-044: Security checks required
  - AOR-FMEA-001: Risk Assessment before fix prioritization
  - Integration with ErrorPatternEngine, Sentinel, SymbioticDefense
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.{ErrorPatternEngine, Guardian, Sentinel, SymbioticDefense}

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type pattern_type ::
          :process_spawn_storm
          | :memory_leak
          | :error_cascade
          | :timeout_pattern
          | :resource_exhaustion
          | :suspicious_access
          | :connection_exhaustion
          | :queue_buildup
          | :latency_degradation
          | :authentication_anomaly
          | :custom

  @type severity :: :low | :medium | :high | :critical | :extinction

  @type pattern :: %{
          id: String.t(),
          name: atom(),
          type: pattern_type(),
          matcher: (map(), list(), map() -> {boolean(), float()}),
          risk_score: 1..10,
          severity: severity(),
          category: atom(),
          time_to_error_ms: pos_integer(),
          description: String.t(),
          enabled: boolean(),
          learning_enabled: boolean()
        }

  @type detection :: %{
          id: String.t(),
          pattern_id: String.t(),
          pattern_name: atom(),
          type: pattern_type(),
          risk_score: 1..10,
          severity: severity(),
          category: atom(),
          confidence: float(),
          time_to_error_ms: pos_integer(),
          description: String.t(),
          metrics: map(),
          detected_at: DateTime.t()
        }

  # ============================================================================
  # Configuration
  # ============================================================================

  # SC-BIO-EXT-001: Pattern detection < 10ms (computation per cycle)
  # Scan interval determines responsiveness — 50ms for SIL-6 biomorphic timing
  @scan_interval_ms 50
  @risk_threshold 7
  @history_window_size 100
  @learning_threshold 5
  @max_learned_patterns 50
  @heuristic_sensitivity 0.75

  # Required pattern types per specification
  @pattern_types [
    :process_spawn_storm,
    :memory_leak,
    :error_cascade,
    :timeout_pattern,
    :resource_exhaustion,
    :suspicious_access
  ]

  # ============================================================================
  # State Definition
  # ============================================================================

  defstruct [
    :name,
    telemetry_history: [],
    event_stream: [],
    active_patterns: [],
    detected_patterns: [],
    learned_patterns: [],
    baseline_metrics: %{},
    adaptive_thresholds: %{},
    stats: %{
      scans: 0,
      patterns_detected: 0,
      preemptive_alerts: 0,
      patterns_learned: 0,
      sentinel_reports: 0
    }
  ]

  # ============================================================================
  # Built-in Pattern Signatures (SC-SEC-044 compliant)
  # ============================================================================

  @builtin_patterns [
    # Process Spawn Storm Detection
    %{
      id: "PS-001",
      name: :process_spawn_storm,
      type: :process_spawn_storm,
      risk_score: 9,
      severity: :critical,
      category: :system,
      time_to_error_ms: 10_000,
      description: "Rapid process spawning detected - potential spawn storm",
      enabled: true,
      learning_enabled: true
    },
    # Memory Leak Detection
    %{
      id: "ML-001",
      name: :memory_leak_trajectory,
      type: :memory_leak,
      risk_score: 8,
      severity: :high,
      category: :performance,
      time_to_error_ms: 60_000,
      description: "Memory usage increasing >5% per minute - potential leak",
      enabled: true,
      learning_enabled: true
    },
    # Error Cascade Detection
    %{
      id: "EC-001",
      name: :error_cascade,
      type: :error_cascade,
      risk_score: 8,
      severity: :high,
      category: :data,
      time_to_error_ms: 15_000,
      description: "Error rate increased 3x baseline - cascade in progress",
      enabled: true,
      learning_enabled: true
    },
    # Timeout Pattern Detection
    %{
      id: "TP-001",
      name: :timeout_pattern,
      type: :timeout_pattern,
      risk_score: 7,
      severity: :high,
      category: :performance,
      time_to_error_ms: 30_000,
      description: "Repeated timeouts detected - service degradation",
      enabled: true,
      learning_enabled: true
    },
    # Resource Exhaustion Detection
    %{
      id: "RE-001",
      name: :resource_exhaustion,
      type: :resource_exhaustion,
      risk_score: 9,
      severity: :critical,
      category: :system,
      time_to_error_ms: 20_000,
      description: "System resources approaching exhaustion",
      enabled: true,
      learning_enabled: true
    },
    # Suspicious Access Detection
    %{
      id: "SA-001",
      name: :suspicious_access,
      type: :suspicious_access,
      risk_score: 10,
      severity: :critical,
      category: :security,
      time_to_error_ms: 5_000,
      description: "Unauthorized access pattern detected",
      enabled: true,
      learning_enabled: false
    },
    # Connection Pool Exhaustion
    %{
      id: "CE-001",
      name: :connection_exhaustion,
      type: :resource_exhaustion,
      risk_score: 9,
      severity: :critical,
      category: :connection,
      time_to_error_ms: 10_000,
      description: "Connection pool >90% utilized",
      enabled: true,
      learning_enabled: true
    },
    # Queue Buildup
    %{
      id: "QB-001",
      name: :queue_buildup,
      type: :resource_exhaustion,
      risk_score: 7,
      severity: :high,
      category: :performance,
      time_to_error_ms: 30_000,
      description: "Message queue growing faster than processing",
      enabled: true,
      learning_enabled: true
    },
    # Latency Degradation
    %{
      id: "LD-001",
      name: :latency_degradation,
      type: :timeout_pattern,
      risk_score: 6,
      severity: :medium,
      category: :performance,
      time_to_error_ms: 45_000,
      description: "P99 latency >2x baseline",
      enabled: true,
      learning_enabled: true
    },
    # Authentication Anomaly
    %{
      id: "AA-001",
      name: :authentication_anomaly,
      type: :suspicious_access,
      risk_score: 9,
      severity: :critical,
      category: :security,
      time_to_error_ms: 5_000,
      description: "Unusual authentication pattern detected",
      enabled: true,
      learning_enabled: false
    },
    # Disk Space Critical
    %{
      id: "DS-001",
      name: :disk_space_critical,
      type: :resource_exhaustion,
      risk_score: 8,
      severity: :high,
      category: :system,
      time_to_error_ms: 300_000,
      description: "Disk usage >90%",
      enabled: true,
      learning_enabled: true
    },
    # Phase 6: Test Anomaly Patterns (SC-SIL6-004, SC-BIO-001)
    # Test Pass Rate Declining — 3 consecutive runs with decreasing pass rate
    %{
      id: "TPR-001",
      name: :test_pass_rate_declining,
      type: :error_cascade,
      risk_score: 7,
      severity: :high,
      category: :quality,
      time_to_error_ms: 60_000,
      description: "Test pass rate declining across 3+ consecutive F# agent runs",
      enabled: true,
      learning_enabled: true
    },
    # Test Duration Spike — duration >2x historical average
    %{
      id: "TDS-001",
      name: :test_duration_spike,
      type: :latency_degradation,
      risk_score: 6,
      severity: :medium,
      category: :quality,
      time_to_error_ms: 120_000,
      description: "F# test run duration >2x historical average — possible regression",
      enabled: true,
      learning_enabled: true
    },
    # New Failure Cluster — >5 new failures in same module
    %{
      id: "NFC-001",
      name: :new_failure_cluster,
      type: :error_cascade,
      risk_score: 8,
      severity: :high,
      category: :quality,
      time_to_error_ms: 30_000,
      description: ">5 new test failures in same module — targeted re-test recommended",
      enabled: true,
      learning_enabled: true
    }
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the Pattern Hunter.

  ## Options
  - `:name` - Process name (default: __MODULE__)
  - `:scan_interval` - Milliseconds between scans (default: 50, SC-BIO-EXT-001)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Analyze an event stream for threat patterns.

  Returns detected patterns with confidence scores.

  ## Example
      iex> PatternHunter.analyze([event1, event2, event3])
      {:ok, [%{pattern_name: :memory_leak, confidence: 0.85, ...}]}
  """
  @spec analyze(list()) :: {:ok, list(detection())}
  def analyze(event_stream) when is_list(event_stream) do
    GenServer.call(__MODULE__, {:analyze, event_stream})
  end

  @doc """
  Register a custom pattern matcher.

  ## Parameters
  - `pattern_name` - Unique atom name for the pattern
  - `matcher_fn` - Function (current_metrics, history, baseline) -> {matched?, confidence}

  ## Example
      iex> PatternHunter.register_pattern(:my_pattern, fn _curr, _hist, _base ->
      ...>   {true, 0.95}
      ...> end)
      :ok
  """
  @spec register_pattern(atom(), (map(), list(), map() -> {boolean(), float()})) :: :ok
  def register_pattern(pattern_name, matcher_fn)
      when is_atom(pattern_name) and is_function(matcher_fn, 3) do
    GenServer.cast(__MODULE__, {:register_pattern, pattern_name, matcher_fn})
  end

  @doc """
  Get all currently active patterns (built-in + learned + custom).
  """
  @spec get_active_patterns() :: list(pattern())
  def get_active_patterns do
    GenServer.call(__MODULE__, :get_active_patterns)
  end

  @doc """
  Report a detected pattern to Sentinel for threat response.
  """
  @spec report_to_sentinel(detection()) :: :ok
  def report_to_sentinel(pattern) when is_map(pattern) do
    GenServer.cast(__MODULE__, {:report_to_sentinel, pattern})
  end

  @doc """
  Report telemetry observation for pattern analysis.
  """
  @spec observe(map()) :: :ok
  def observe(telemetry) when is_map(telemetry) do
    GenServer.cast(__MODULE__, {:observe, telemetry})
  end

  @doc """
  Get current hunt status and detected patterns.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get all pattern signatures being hunted.
  """
  @spec signatures() :: list()
  def signatures do
    @builtin_patterns
  end

  @doc """
  Get supported pattern types.
  """
  @spec pattern_types() :: list(pattern_type())
  def pattern_types, do: @pattern_types

  @doc """
  Force immediate scan cycle.
  """
  @spec scan_now() :: :ok
  def scan_now do
    GenServer.cast(__MODULE__, :scan_now)
  end

  @doc """
  Set baseline metrics for anomaly detection.
  """
  @spec set_baseline(map()) :: :ok
  def set_baseline(metrics) when is_map(metrics) do
    GenServer.cast(__MODULE__, {:set_baseline, metrics})
  end

  @doc """
  Enable or disable a pattern by ID.
  """
  @spec set_pattern_enabled(String.t(), boolean()) :: :ok
  def set_pattern_enabled(pattern_id, enabled) do
    GenServer.cast(__MODULE__, {:set_pattern_enabled, pattern_id, enabled})
  end

  @doc """
  Get learned patterns discovered during runtime.
  """
  @spec get_learned_patterns() :: list()
  def get_learned_patterns do
    GenServer.call(__MODULE__, :get_learned_patterns)
  end

  @doc """
  Clear learned patterns (for testing or reset).
  """
  @spec clear_learned_patterns() :: :ok
  def clear_learned_patterns do
    GenServer.cast(__MODULE__, :clear_learned_patterns)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__),
      active_patterns: @builtin_patterns,
      baseline_metrics: default_baseline(),
      adaptive_thresholds: default_thresholds()
    }

    # Start hunt cycle
    schedule_scan()

    Logger.info(
      "[PatternHunter] Initialized with #{length(@builtin_patterns)} patterns, " <>
        "#{length(@pattern_types)} pattern types, learning enabled"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:analyze, event_stream}, _from, state) do
    # Store events for analysis
    new_state = %{state | event_stream: event_stream}

    # Run analysis cycle
    current_metrics = collect_system_metrics()
    detections = run_full_analysis(current_metrics, event_stream, state)

    {:reply, {:ok, detections}, new_state}
  end

  @impl true
  def handle_call(:get_active_patterns, _from, state) do
    all_patterns = state.active_patterns ++ state.learned_patterns
    enabled_patterns = Enum.filter(all_patterns, & &1.enabled)
    {:reply, enabled_patterns, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      active_patterns:
        length(Enum.filter(state.active_patterns ++ state.learned_patterns, & &1.enabled)),
      total_patterns: length(state.active_patterns) + length(state.learned_patterns),
      learned_patterns: length(state.learned_patterns),
      detected_patterns: state.detected_patterns,
      history_size: length(state.telemetry_history),
      baseline_metrics: state.baseline_metrics,
      adaptive_thresholds: state.adaptive_thresholds,
      stats: state.stats,
      pattern_types: @pattern_types
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:get_learned_patterns, _from, state) do
    {:reply, state.learned_patterns, state}
  end

  @impl true
  def handle_cast({:observe, telemetry}, state) do
    observation = Map.put(telemetry, :observed_at, System.monotonic_time(:millisecond))
    new_history = [observation | Enum.take(state.telemetry_history, @history_window_size - 1)]

    # Check for learnable patterns in the observation
    new_state = maybe_learn_pattern(telemetry, %{state | telemetry_history: new_history})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:scan_now, state) do
    {:noreply, run_hunt_cycle(state)}
  end

  @impl true
  def handle_cast({:set_baseline, metrics}, state) do
    new_baseline = Map.merge(state.baseline_metrics, metrics)
    new_thresholds = update_adaptive_thresholds(new_baseline, state.adaptive_thresholds)
    {:noreply, %{state | baseline_metrics: new_baseline, adaptive_thresholds: new_thresholds}}
  end

  @impl true
  def handle_cast({:register_pattern, pattern_name, matcher_fn}, state) do
    custom_pattern = %{
      id: "CUSTOM-#{:erlang.unique_integer([:positive])}",
      name: pattern_name,
      type: :custom,
      matcher: matcher_fn,
      risk_score: 5,
      severity: :medium,
      category: :custom,
      time_to_error_ms: 30_000,
      description: "Custom pattern: #{pattern_name}",
      enabled: true,
      learning_enabled: false
    }

    new_patterns = [custom_pattern | state.active_patterns]

    Logger.info("[PatternHunter] Registered custom pattern: #{pattern_name}")

    {:noreply, %{state | active_patterns: new_patterns}}
  end

  @impl true
  def handle_cast({:report_to_sentinel, pattern}, state) do
    do_report_to_sentinel(pattern)

    new_stats = Map.update!(state.stats, :sentinel_reports, &(&1 + 1))
    {:noreply, %{state | stats: new_stats}}
  end

  @impl true
  def handle_cast({:set_pattern_enabled, pattern_id, enabled}, state) do
    new_patterns =
      Enum.map(state.active_patterns, fn p ->
        if p.id == pattern_id, do: %{p | enabled: enabled}, else: p
      end)

    {:noreply, %{state | active_patterns: new_patterns}}
  end

  @impl true
  def handle_cast(:clear_learned_patterns, state) do
    {:noreply, %{state | learned_patterns: []}}
  end

  @impl true
  def handle_info(:scan, state) do
    new_state = run_hunt_cycle(state)
    schedule_scan()
    {:noreply, new_state}
  end

  # ============================================================================
  # Hunt Cycle (OODA Implementation)
  # ============================================================================

  defp run_hunt_cycle(state) do
    cycle_start = System.monotonic_time(:microsecond)

    # OBSERVE: Collect current system state
    current_metrics = collect_system_metrics()

    # ORIENT: Match against patterns + heuristic analysis
    all_patterns = state.active_patterns ++ state.learned_patterns
    enabled_patterns = Enum.filter(all_patterns, & &1.enabled)

    detections =
      hunt_patterns(
        current_metrics,
        state.telemetry_history,
        state.baseline_metrics,
        enabled_patterns
      )

    # Add heuristic detections
    heuristic_detections =
      run_heuristic_analysis(current_metrics, state.telemetry_history, state.adaptive_thresholds)

    all_detections = detections ++ heuristic_detections

    # DECIDE: Evaluate risk and determine response
    high_risk = Enum.filter(all_detections, fn d -> d.risk_score >= @risk_threshold end)

    # ACT: Send preemptive alerts
    new_state =
      if length(high_risk) > 0 do
        send_preemptive_alerts(high_risk)
        update_stats(state, length(all_detections), length(high_risk))
      else
        update_stats(state, length(all_detections), 0)
      end

    # SC-BIO-EXT-001: Measure detection latency — target < 10ms per cycle
    cycle_duration_us = System.monotonic_time(:microsecond) - cycle_start

    :telemetry.execute(
      [:indrajaal, :pattern_hunter, :ooda_cycle],
      %{
        duration_us: cycle_duration_us,
        detections: length(all_detections),
        high_risk: length(high_risk)
      },
      %{}
    )

    if cycle_duration_us > 10_000 do
      Logger.warning(
        "[PatternHunter] OODA cycle exceeded 10ms target: #{div(cycle_duration_us, 1000)}ms (SC-BIO-EXT-001)"
      )
    end

    %{
      new_state
      | detected_patterns: all_detections,
        stats: Map.update!(new_state.stats, :scans, &(&1 + 1))
    }
  end

  defp run_full_analysis(current_metrics, event_stream, state) do
    all_patterns = state.active_patterns ++ state.learned_patterns
    enabled_patterns = Enum.filter(all_patterns, & &1.enabled)

    # Combine telemetry history with event stream
    combined_history = event_stream ++ state.telemetry_history

    # Pattern-based detection
    pattern_detections =
      hunt_patterns(current_metrics, combined_history, state.baseline_metrics, enabled_patterns)

    # Heuristic detection
    heuristic_detections =
      run_heuristic_analysis(current_metrics, combined_history, state.adaptive_thresholds)

    # Event stream specific analysis
    event_detections = analyze_event_stream(event_stream)

    pattern_detections ++ heuristic_detections ++ event_detections
  end

  # ============================================================================
  # Pattern Matching Engine
  # ============================================================================

  defp hunt_patterns(current, history, baseline, patterns) do
    patterns
    |> Enum.map(fn pattern ->
      {matched, confidence} = match_pattern(pattern, current, history, baseline)

      if matched and confidence >= @heuristic_sensitivity do
        create_detection(pattern, confidence, current)
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp match_pattern(%{matcher: matcher}, current, history, baseline)
       when is_function(matcher, 3) do
    # Custom pattern with explicit matcher function
    matcher.(current, history, baseline)
  end

  defp match_pattern(pattern, current, history, baseline) do
    # Built-in pattern matching
    case pattern.type do
      :process_spawn_storm -> match_process_spawn_storm(current, history)
      :memory_leak -> match_memory_leak(current, history)
      :error_cascade -> match_error_cascade(history, baseline)
      :timeout_pattern -> match_timeout_pattern(history)
      :resource_exhaustion -> match_resource_exhaustion(current, pattern.name)
      :suspicious_access -> match_suspicious_access(history)
      _ -> match_by_name(pattern.name, current, history, baseline)
    end
  end

  # Process Spawn Storm Detection
  defp match_process_spawn_storm(current, history) do
    if length(history) >= 5 do
      process_counts = Enum.map(history, fn h -> h[:process_count] || current.process_count end)
      oldest = List.last(process_counts)
      newest = List.first(process_counts)
      spawn_rate = newest - oldest

      # Storm threshold: >200 processes per scan interval or >1000 total new
      cond do
        spawn_rate > 1000 -> {true, min(100.0, spawn_rate / 10.0)}
        spawn_rate > 200 -> {true, min(90.0, spawn_rate / 3.0)}
        current.process_count > 50_000 -> {true, 75.0}
        true -> {false, 0.0}
      end
    else
      {false, 0.0}
    end
  end

  # Memory Leak Detection
  defp match_memory_leak(current, history) do
    if length(history) >= 10 do
      recent = Enum.take(history, 10)
      memory_samples = Enum.map(recent, fn h -> h[:total_memory] || current.total_memory end)

      # Check if monotonically increasing (each sample >= previous)
      # Note: history is newest-first, so samples are [newest, ..., oldest]
      # For increasing memory: oldest < newest, so reversed order should be ascending
      increasing =
        memory_samples
        |> Enum.reverse()
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.all?(fn [a, b] -> b >= a end)

      if increasing do
        # Growth rate: (newest - oldest) / oldest * 100
        oldest = List.last(memory_samples)
        newest = List.first(memory_samples)
        growth_rate = (newest - oldest) / max(oldest, 1) * 100

        if growth_rate > 5 do
          {true, min(100.0, growth_rate * 10.0)}
        else
          {false, 0.0}
        end
      else
        {false, 0.0}
      end
    else
      {false, 0.0}
    end
  end

  # Error Cascade Detection
  defp match_error_cascade(history, baseline) do
    if length(history) >= 5 do
      recent_errors = Enum.count(history, fn h -> Map.get(h, :error, false) end)
      baseline_rate = Map.get(baseline, :error_rate, 0.01)
      current_rate = recent_errors / max(length(history), 1)

      if current_rate > baseline_rate * 3 do
        {true, min(100.0, current_rate / baseline_rate * 20.0)}
      else
        {false, 0.0}
      end
    else
      {false, 0.0}
    end
  end

  # Timeout Pattern Detection
  defp match_timeout_pattern(history) do
    if length(history) >= 5 do
      recent_timeouts =
        Enum.count(history, fn h ->
          Map.get(h, :timeout, false) or Map.get(h, :error_type) == :timeout
        end)

      if recent_timeouts >= 3 do
        {true, min(100.0, recent_timeouts * 20.0)}
      else
        {false, 0.0}
      end
    else
      {false, 0.0}
    end
  end

  # Resource Exhaustion Detection
  defp match_resource_exhaustion(current, pattern_name) do
    case pattern_name do
      :connection_exhaustion ->
        # Would check actual connection pool - placeholder for now
        if current.port_count > 30_000 do
          {true, min(100.0, current.port_count / 300.0)}
        else
          {false, 0.0}
        end

      :disk_space_critical ->
        # Would check disk usage - placeholder
        {false, 0.0}

      _ ->
        # Generic resource exhaustion checks
        # Assume 16GB max
        memory_pct = current.total_memory / (16 * 1024 * 1024 * 1024) * 100
        # Default max processes
        process_pct = current.process_count / 262_144 * 100

        cond do
          memory_pct > 90 -> {true, 95.0}
          process_pct > 80 -> {true, 85.0}
          current.run_queue > 200 -> {true, min(100.0, current.run_queue / 2.0)}
          true -> {false, 0.0}
        end
    end
  end

  # Suspicious Access Detection (SC-SEC-044)
  defp match_suspicious_access(history) do
    if length(history) >= 10 do
      recent_auth = Enum.filter(history, fn h -> Map.has_key?(h, :auth_event) end)
      failed = Enum.count(recent_auth, fn h -> h[:auth_event] == :failed end)

      # Look for brute force patterns
      unique_ips =
        recent_auth
        |> Enum.map(fn h -> h[:source_ip] end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> length()

      cond do
        # Definite attack
        failed > 10 -> {true, 95.0}
        # Brute force from single IP
        failed > 5 and unique_ips == 1 -> {true, 90.0}
        failed > 5 -> {true, min(100.0, failed * 15.0)}
        true -> {false, 0.0}
      end
    else
      {false, 0.0}
    end
  end

  # Fallback matcher for named patterns
  defp match_by_name(name, current, history, baseline) do
    case name do
      :queue_buildup ->
        if current.run_queue > 100 do
          {true, min(100.0, current.run_queue * 1.0)}
        else
          {false, 0.0}
        end

      :latency_degradation ->
        match_latency_degradation(history, baseline)

      :authentication_anomaly ->
        match_suspicious_access(history)

      _ ->
        {false, 0.0}
    end
  end

  defp match_latency_degradation(history, baseline) do
    if length(history) >= 5 do
      recent_latencies =
        history
        |> Enum.map(fn h -> Map.get(h, :latency_ms, 0) end)
        |> Enum.filter(&(&1 > 0))

      if length(recent_latencies) > 0 do
        avg_latency = Enum.sum(recent_latencies) / length(recent_latencies)
        baseline_latency = Map.get(baseline, :latency_p99, 100)

        if avg_latency > baseline_latency * 2 do
          {true, min(100.0, avg_latency / baseline_latency * 30.0)}
        else
          {false, 0.0}
        end
      else
        {false, 0.0}
      end
    else
      {false, 0.0}
    end
  end

  # ============================================================================
  # Heuristic Detection Engine
  # ============================================================================

  defp run_heuristic_analysis(current_metrics, history, thresholds) do
    detections = []

    # Anomaly detection based on statistical deviation
    detections = detect_statistical_anomalies(current_metrics, history, thresholds, detections)

    # Trend analysis
    detections = detect_dangerous_trends(history, thresholds, detections)

    detections
  end

  defp detect_statistical_anomalies(current, history, thresholds, detections) do
    if length(history) >= 10 do
      # Memory anomaly
      memory_mean = calculate_mean(history, :total_memory, current.total_memory)
      memory_std = calculate_std(history, :total_memory, memory_mean)
      memory_threshold = Map.get(thresholds, :memory_std_threshold, 2.0)

      detections =
        if memory_std > 0 and
             abs(current.total_memory - memory_mean) > memory_std * memory_threshold do
          anomaly = %{
            id: "HEUR-MEM-#{:erlang.unique_integer([:positive])}",
            pattern_id: "HEURISTIC",
            pattern_name: :memory_anomaly,
            type: :memory_leak,
            risk_score: 6,
            severity: :medium,
            category: :heuristic,
            confidence: 75.0,
            time_to_error_ms: 60_000,
            description: "Statistical memory anomaly detected",
            metrics: %{current: current.total_memory, mean: memory_mean, std: memory_std},
            detected_at: DateTime.utc_now()
          }

          [anomaly | detections]
        else
          detections
        end

      # Process count anomaly
      proc_mean = calculate_mean(history, :process_count, current.process_count)
      proc_std = calculate_std(history, :process_count, proc_mean)
      proc_threshold = Map.get(thresholds, :process_std_threshold, 2.5)

      if proc_std > 0 and abs(current.process_count - proc_mean) > proc_std * proc_threshold do
        anomaly = %{
          id: "HEUR-PROC-#{:erlang.unique_integer([:positive])}",
          pattern_id: "HEURISTIC",
          pattern_name: :process_anomaly,
          type: :process_spawn_storm,
          risk_score: 7,
          severity: :high,
          category: :heuristic,
          confidence: 80.0,
          time_to_error_ms: 30_000,
          description: "Statistical process count anomaly detected",
          metrics: %{current: current.process_count, mean: proc_mean, std: proc_std},
          detected_at: DateTime.utc_now()
        }

        [anomaly | detections]
      else
        detections
      end
    else
      detections
    end
  end

  defp detect_dangerous_trends(history, _thresholds, detections) do
    if length(history) >= 20 do
      # Look for consistently increasing trends
      memory_samples =
        history
        |> Enum.take(20)
        |> Enum.map(fn h -> h[:total_memory] || 0 end)

      if monotonically_increasing?(memory_samples) do
        trend = %{
          id: "HEUR-TREND-#{:erlang.unique_integer([:positive])}",
          pattern_id: "HEURISTIC",
          pattern_name: :dangerous_memory_trend,
          type: :memory_leak,
          risk_score: 8,
          severity: :high,
          category: :heuristic,
          confidence: 85.0,
          time_to_error_ms: 120_000,
          description: "Consistent upward memory trend over 20 samples",
          metrics: %{samples: length(memory_samples)},
          detected_at: DateTime.utc_now()
        }

        [trend | detections]
      else
        detections
      end
    else
      detections
    end
  end

  # ============================================================================
  # Event Stream Analysis
  # ============================================================================

  defp analyze_event_stream(events) do
    events
    |> Enum.reduce([], fn event, detections ->
      cond do
        Map.get(event, :type) == :error and Map.get(event, :severity) == :critical ->
          detection = %{
            id: "EVT-#{:erlang.unique_integer([:positive])}",
            pattern_id: "EVENT",
            pattern_name: :critical_error_event,
            type: :error_cascade,
            risk_score: 8,
            severity: :critical,
            category: :event,
            confidence: 90.0,
            time_to_error_ms: 5_000,
            description: "Critical error in event stream",
            metrics: event,
            detected_at: DateTime.utc_now()
          }

          [detection | detections]

        Map.get(event, :auth_failed, false) ->
          detection = %{
            id: "EVT-AUTH-#{:erlang.unique_integer([:positive])}",
            pattern_id: "EVENT",
            pattern_name: :auth_failure_event,
            type: :suspicious_access,
            risk_score: 7,
            severity: :high,
            category: :security,
            confidence: 85.0,
            time_to_error_ms: 10_000,
            description: "Authentication failure in event stream",
            metrics: event,
            detected_at: DateTime.utc_now()
          }

          [detection | detections]

        true ->
          detections
      end
    end)
  end

  # ============================================================================
  # Learning Engine
  # ============================================================================

  defp maybe_learn_pattern(telemetry, state) do
    # Only learn from significant events
    if should_learn?(telemetry, state) do
      new_pattern = create_learned_pattern(telemetry, state)

      if new_pattern && length(state.learned_patterns) < @max_learned_patterns do
        Logger.info("[PatternHunter] Learned new pattern: #{new_pattern.name}")

        new_learned = [new_pattern | state.learned_patterns]
        new_stats = Map.update!(state.stats, :patterns_learned, &(&1 + 1))
        %{state | learned_patterns: new_learned, stats: new_stats}
      else
        state
      end
    else
      state
    end
  end

  defp should_learn?(telemetry, state) do
    # Learn when we see repeated anomalies
    anomaly_count = Map.get(telemetry, :anomaly_count, 0)
    error = Map.get(telemetry, :error, false)

    anomaly_count >= @learning_threshold or
      (error and length(state.telemetry_history) >= 10)
  end

  defp create_learned_pattern(telemetry, _state) do
    error_type = Map.get(telemetry, :error_type, :unknown)
    source = Map.get(telemetry, :source, :system)

    %{
      id: "LEARNED-#{:erlang.unique_integer([:positive])}",
      name: String.to_atom("learned_#{error_type}_#{source}"),
      type: infer_pattern_type(telemetry),
      risk_score: 5,
      severity: :medium,
      category: :learned,
      time_to_error_ms: 30_000,
      description: "Learned pattern from #{source}: #{error_type}",
      enabled: true,
      learning_enabled: false,
      source_telemetry: telemetry
    }
  end

  defp infer_pattern_type(telemetry) do
    cond do
      Map.get(telemetry, :memory_spike, false) -> :memory_leak
      Map.get(telemetry, :timeout, false) -> :timeout_pattern
      Map.get(telemetry, :auth_failed, false) -> :suspicious_access
      Map.get(telemetry, :error_cascade, false) -> :error_cascade
      Map.get(telemetry, :resource_low, false) -> :resource_exhaustion
      true -> :custom
    end
  end

  # ============================================================================
  # Alert System & Integration
  # ============================================================================

  defp send_preemptive_alerts(detections) do
    Enum.each(detections, fn detection ->
      Logger.warning(
        "[PatternHunter] PRE-ERROR DETECTED: #{detection.pattern_name} " <>
          "(type: #{detection.type}, risk: #{detection.risk_score}, confidence: #{detection.confidence}%)"
      )

      # ZUIP S-04: Publish detection to Zenoh mesh (fire-and-forget)
      Indrajaal.Observability.ZenohSafetyPublisher.publish_pattern_detected(
        detection.type,
        %{
          pattern_name: detection.pattern_name,
          risk_score: detection.risk_score,
          confidence: detection.confidence,
          time_to_error_ms: detection.time_to_error_ms
        }
      )

      # Report to Sentinel for process-level monitoring
      do_report_to_sentinel(detection)

      # Report to Guardian for safety oversight
      report_to_guardian(detection)

      # For security threats, also notify SymbioticDefense
      if detection.type in [:suspicious_access] do
        report_to_symbiotic_defense(detection)
      end

      # Notify ErrorPatternEngine for pattern correlation
      notify_error_pattern_engine(detection)
    end)
  end

  defp do_report_to_sentinel(detection) do
    # SC-SEC-044: Security check - report threat to Sentinel
    signal = %{
      type: :pre_error,
      pattern_type: detection.type,
      pattern_name: detection.pattern_name,
      risk_score: detection.risk_score,
      severity: rpn_from_detection(detection),
      confidence: detection.confidence,
      time_to_error_ms: detection.time_to_error_ms,
      timestamp: DateTime.utc_now()
    }

    try do
      Sentinel.report_signal(signal)
    rescue
      _ -> :ok
    end
  end

  defp report_to_guardian(detection) do
    try do
      Guardian.report_threat(%{
        type: :pre_error,
        signature: detection.pattern_name,
        risk_score: detection.risk_score,
        category: detection.category,
        time_to_error_ms: detection.time_to_error_ms,
        timestamp: DateTime.utc_now()
      })
    rescue
      _ -> :ok
    end
  end

  defp report_to_symbiotic_defense(detection) do
    try do
      SymbioticDefense.report_lineage_threat(%{
        type: detection.type,
        pattern: detection.pattern_name,
        severity: detection.severity,
        source: :pattern_hunter,
        timestamp: DateTime.utc_now()
      })
    rescue
      _ -> :ok
    end
  end

  defp notify_error_pattern_engine(detection) do
    try do
      ErrorPatternEngine.analyze_error(%{
        type: :pre_error_warning,
        signature: detection.pattern_name,
        category: detection.category,
        severity: detection.severity
      })
    rescue
      _ -> :ok
    end
  end

  # ============================================================================
  # Detection Creation
  # ============================================================================

  defp create_detection(pattern, confidence, metrics) do
    %{
      id: "DET-#{:erlang.unique_integer([:positive])}",
      pattern_id: pattern.id,
      pattern_name: pattern.name,
      type: pattern.type,
      risk_score: pattern.risk_score,
      severity: pattern.severity,
      category: pattern.category,
      confidence: confidence,
      time_to_error_ms: pattern.time_to_error_ms,
      description: pattern.description,
      metrics: sanitize_metrics(metrics),
      detected_at: DateTime.utc_now()
    }
  end

  defp sanitize_metrics(metrics) when is_map(metrics) do
    Map.take(metrics, [:total_memory, :process_count, :run_queue, :port_count, :timestamp])
  end

  defp sanitize_metrics(_), do: %{}

  # ============================================================================
  # System Metrics Collection
  # ============================================================================

  defp collect_system_metrics do
    memory = :erlang.memory()

    %{
      total_memory: memory[:total],
      process_memory: memory[:processes],
      atom_memory: memory[:atom],
      binary_memory: memory[:binary],
      ets_memory: memory[:ets],
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count),
      run_queue: :erlang.statistics(:run_queue),
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  # ============================================================================
  # Statistics & Helpers
  # ============================================================================

  defp calculate_mean(history, key, default) do
    values = Enum.map(history, fn h -> h[key] || default end)
    if length(values) > 0, do: Enum.sum(values) / length(values), else: default
  end

  defp calculate_std(history, key, mean) do
    values = Enum.map(history, fn h -> h[key] || mean end)

    if length(values) > 1 do
      variance =
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values) - 1)

      :math.sqrt(variance)
    else
      0.0
    end
  end

  defp monotonically_increasing?([]), do: false
  defp monotonically_increasing?([_]), do: false

  defp monotonically_increasing?(list) do
    list
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> a >= b end)
  end

  defp rpn_from_detection(detection) do
    # RPN = Risk Priority Number (FMEA style)
    detection.risk_score * 10
  end

  defp update_stats(state, detected, alerted) do
    %{
      state
      | stats: %{
          state.stats
          | patterns_detected: state.stats.patterns_detected + detected,
            preemptive_alerts: state.stats.preemptive_alerts + alerted
        }
    }
  end

  defp schedule_scan do
    Process.send_after(self(), :scan, @scan_interval_ms)
  end

  defp default_baseline do
    %{
      error_rate: 0.01,
      latency_p99: 100,
      memory_baseline: :erlang.memory(:total),
      process_count_baseline: :erlang.system_info(:process_count)
    }
  end

  defp default_thresholds do
    %{
      memory_std_threshold: 2.0,
      process_std_threshold: 2.5,
      error_rate_threshold: 3.0,
      latency_threshold: 2.0
    }
  end

  defp update_adaptive_thresholds(baseline, current_thresholds) do
    # Adjust thresholds based on baseline
    # Lower thresholds if baseline shows high variability
    memory_baseline = Map.get(baseline, :memory_baseline, 0)
    process_baseline = Map.get(baseline, :process_count_baseline, 0)

    memory_threshold =
      if memory_baseline > 1024 * 1024 * 1024, do: 2.5, else: 2.0

    process_threshold =
      if process_baseline > 10_000, do: 3.0, else: 2.5

    %{
      current_thresholds
      | memory_std_threshold: memory_threshold,
        process_std_threshold: process_threshold
    }
  end
end
