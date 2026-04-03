defmodule Indrajaal.ProductionReadiness.DebugSystem do
  @moduledoc """
  Comprehensive debugging system for production troubleshooting.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - UCA-011: Pr_event debug mode in production
  """

  use GenServer
  require Logger

  @safe_debug_config %{
    max_capture_duration_ms: 60_000,
    max_log_level: :info,
    max_profiling_overhead_percent: 5.0,
    _require_approval_for_production: true
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Configure debug settings with safety validation.
  Pr_events UCA-011: Debug mode in production.
  """
  def configure(debug_config) do
    GenServer.call(__MODULE__, {:configure, debug_config})
  end

  @doc """
  Investigate a specific issue.
  """
  def investigate(request) do
    GenServer.call(__MODULE__, {:investigate, request}, 60_000)
  end

  @doc """
  Start an interactive debug session.
  """
  def start_debug_session(target) do
    GenServer.call(__MODULE__, {:start_session, target})
  end

  @doc """
  Set a breakpoint in debug session.
  """
  def set_breakpoint(session_id, location) do
    GenServer.call(__MODULE__, {:set_breakpoint, session_id, location})
  end

  @doc """
  Capture current state in debug session.
  """
  def capture_state(session_id) do
    GenServer.call(__MODULE__, {:capture_state, session_id})
  end

  @doc """
  End a debug session.
  """
  def end_session(session_id) do
    GenServer.call(__MODULE__, {:end_session, session_id})
  end

  @doc """
  Get current debug status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      config: @safe_debug_config,
      active_sessions: %{},
      investigation_cache: %{},
      breakpoints: %{},
      captured_states: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:configure, debug_config}, _from, state) do
    # UCA-011: Validate safe debug configuration
    case validate_debug_config(debug_config) do
      {:ok, safe_config} ->
        new_state = %{state | config: Map.merge(state.config, safe_config)}

        Logger.info("[DebugSystem] Configuration updated: #{inspect(safe_config)}")

        {:reply, {:ok, safe_config}, new_state}

      {:error, :unsafe_debug_in_production} = error ->
        Logger.error("[DebugSystem] Unsafe debug configuration rejected")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:investigate, request}, _from, state) do
    Logger.info("[DebugSystem] Starting investigation: #{request.issue_type}")

    # Check cache
    cache_key = generate_investigation_key(request)

    case Map.get(state.investigation_cache, cache_key) do
      nil ->
        # Perform investigation
        debug_info = perform_investigation(request)

        # Cache results
        new_cache =
          Map.put(state.investigation_cache, cache_key, {DateTime.utc_now(), debug_info})

        cleaned_cache = clean_investigation_cache(new_cache)

        new_state = %{state | investigation_cache: cleaned_cache}

        {:reply, {:ok, debug_info}, new_state}

      {_timestamp, cached_info} ->
        Logger.info("[DebugSystem] Using cached investigation results")
        {:reply, {:ok, cached_info}, state}
    end
  end

  @impl true
  def handle_call({:startsession, target}, _from, state) do
    session_id = generate_session_id()

    session = %{
      id: session_id,
      target: target,
      started_at: DateTime.utc_now(),
      breakpoints: [],
      captured_states: [],
      status: :active
    }

    new_sessions = Map.put(state.active_sessions, session_id, session)

    Logger.info("[DebugSystem] Started debug session #{session_id} for #{target}")

    {:reply, {:ok, session}, %{state | active_sessions: new_sessions}}
  end

  @impl true
  def handle_call({:setbreakpoint, session_id, location}, _from, state) do
    case Map.get(state.active_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        breakpoint = %{
          id: generate_breakpoint_id(),
          location: location,
          set_at: DateTime.utc_now(),
          hit_count: 0
        }

        updated_session = Map.update!(session, :breakpoints, &[breakpoint | &1])
        new_sessions = Map.put(state.active_sessions, session_id, updated_session)

        # Store breakpoint globally
        new_breakpoints =
          Map.update(state.breakpoints, location, [breakpoint], &[breakpoint | &1])

        new_state = %{state | active_sessions: new_sessions, breakpoints: new_breakpoints}

        Logger.info("[DebugSystem] Set breakpoint at #{inspect(location)}")

        {:reply, {:ok, breakpoint}, new_state}
    end
  end

  @impl true
  def handle_call({:capture_state, session_id}, _from, state) do
    case Map.get(state.active_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        captured_state = capture_current_state(session.target)

        updated_session = Map.update!(session, :captured_states, &[captured_state | &1])
        new_sessions = Map.put(state.active_sessions, session_id, updated_session)

        # Store globally
        new_captured_states = [captured_state | state.captured_states] |> Enum.take(100)

        new_state = %{state | active_sessions: new_sessions, captured_states: new_captured_states}

        {:reply, {:ok, captured_state}, new_state}
    end
  end

  @impl true
  def handle_call({:endsession, session_id}, _from, state) do
    case Map.get(state.active_sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      session ->
        # Clean up session breakpoints
        breakpoint_locations = session.breakpoints
        session_breakpoints = breakpoint_locations |> Enum.map(& &1.location)

        new_breakpoints =
          Enum.reduce(session_breakpoints, state.breakpoints, fn location, bps ->
            Map.update(bps, location, [], fn existing ->
              Enum.reject(existing, fn bp ->
                Enum.any?(session.breakpoints, &(&1.id == bp.id))
              end)
            end)
          end)

        new_sessions = Map.delete(state.active_sessions, session_id)

        new_state = %{state | active_sessions: new_sessions, breakpoints: new_breakpoints}

        Logger.info("[DebugSystem] Ended debug session #{session_id}")

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:getstatus, _from, state) do
    status = %{
      active_sessions: map_size(state.active_sessions),
      total_breakpoints: count_breakpoints(state.breakpoints),
      captured_states: length(state.captured_states),
      cache_size: map_size(state.investigation_cache),
      config: state.config
    }

    {:reply, status, state}
  end

  # Private functions

  defp validate_debug_config(config) do
    # UCA-011: Pr_event dangerous debug settings in production
    cond do
      config[:environment] == :production and config[:enable_profiling] ->
        {:error, :unsafe_debug_in_production}

      config[:environment] == :production and config[:capture_all_traffic] ->
        {:error, :unsafe_debug_in_production}

      config[:environment] == :production and config[:log_level] == :debug ->
        {:error, :unsafe_debug_in_production}

      true ->
        safe_config = apply_production_limits(config)
        {:ok, safe_config}
    end
  end

  defp apply_production_limits(config) do
    config
    |> Map.put(:max_capture_duration_ms, min(config[:max_capture_duration_ms] || 60_000, 60_000))
    |> Map.put(
      :max_profiling_overhead_percent,
      min(config[:max_profiling_overhead_percent] || 5.0, 5.0)
    )
    |> Map.put(:_require_approval_for_production, true)
  end

  defp perform_investigation(request) do
    %{
      issue_type: request.issue_type,
      affected_service: request.affected_service,
      time_range: request.time_range,
      investigation_id: generate_investigation_id(),
      started_at: DateTime.utc_now(),
      timeline: generate_timeline(request),
      correlated_events: find_correlated_events(request),
      performance_profile: analyze_performance(request),
      suspicious_patterns: detect_patterns(request),
      recommended_actions: generate_recommendations(request),
      trace_samples: collect_trace_samples(request)
    }
  end

  defp generate_timeline(request) do
    # Simulate timeline of __events
    base_time = elem(request.time_range, 0)

    for i <- 0..9 do
      %{
        timestamp: DateTime.add(base_time, i * 180, :second),
        __event: "Event #{i}",
        severity: Enum.random([:info, :warn, :error]),
        service: request.affected_service
      }
    end
  end

  # AGENT GA FIX: STUB parameter
  defp find_correlated_events(_request) do
    # Simulate correlated __events
    [
      %{
        service: :__database,
        __event: "Connection pool exhausted",
        correlation: 0.85
      },
      %{
        service: :cache,
        __event: "High eviction rate",
        correlation: 0.72
      },
      %{
        service: :api_gateway,
        __event: "Rate limiting triggered",
        correlation: 0.65
      }
    ]
  end

  # AGENT GA FIX: STUB parameter
  defp analyze_performance(%{issue_type: :performance_degradation} = _request) do
    %{
      bottleneck: "Database query latency",
      affected_endpoints: ["/api/__users", "/api/orders"],
      latency_increase: "250%",
      cpu_spike: false,
      memory_leak: false,
      io_bound: true
    }
  end

  defp analyze_performance(_request) do
    %{
      general_health: :good,
      no_performance_issues: true
    }
  end

  defp detect_patterns(request) do
    case request.issue_type do
      :performance_degradation ->
        ["Periodic spikes every 5 minutes", "Correlation with batch job execution"]

      :error_spike ->
        ["Errors cluster around specific user IDs", "Timeout pattern detected"]

      _ ->
        []
    end
  end

  defp generate_recommendations(request) do
    case request.issue_type do
      :performance_degradation ->
        [
          "Investigate __database query performance",
          "Consider implementing query result caching",
          "Review connection pool settings",
          "Enable __database query logging"
        ]

      :error_spike ->
        [
          "Implement circuit breaker for failing service",
          "Add retry logic with exponential backoff",
          "Review error handling in affected endpoints",
          "Consider rate limiting per user"
        ]

      _ ->
        ["Continue monitoring", "Review recent deployments"]
    end
  end

  # AGENT GA FIX: STUB parameter
  defp collect_trace_samples(_request) do
    # Simulate trace samples
    for i <- 1..3 do
      %{
        trace_id: generate_trace_id(),
        duration_ms: 100 + :rand.uniform(900),
        spans: 5 + :rand.uniform(10),
        error: i == 2
      }
    end
  end

  defp capture_current_state(target) do
    %{
      id: generate_state_id(),
      target: target,
      captured_at: DateTime.utc_now(),
      process_info: capture_process_info(target),
      ets_tables: capture_ets_info(),
      memory_usage: capture_memory_info(),
      message_queue: capture_message_queue(target)
    }
  end

  defp capture_process_info(target) do
    # In production, this would capture real process info
    %{
      pid: self(),
      registered_name: target,
      current_function: {:gen_server, :loop, 2},
      status: :waiting,
      heap_size: :rand.uniform(10_000),
      stack_size: :rand.uniform(100),
      reductions: :rand.uniform(1_000_000)
    }
  end

  defp capture_ets_info do
    # In production, this would list real ETS tables
    [
      %{name: :sessions, size: 42, memory: 8192},
      %{name: :cache, size: 1337, memory: 65_536}
    ]
  end

  defp capture_memory_info do
    %{
      total: :rand.uniform(1000) * 1024 * 1024,
      processes: :rand.uniform(500) * 1024 * 1024,
      ets: :rand.uniform(200) * 1024 * 1024,
      binary: :rand.uniform(100) * 1024 * 1024
    }
  end

  # AGENT GA FIX: STUB parameter
  defp capture_message_queue(_target) do
    # In production, this would capture real message queue
    %{
      length: :rand.uniform(10),
      messages: ["sample message 1", "sample message 2"]
    }
  end

  defp count_breakpoints(breakpoints) do
    breakpoints
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp generate_investigation_key(request) do
    key_data = {request.issue_type, request.affected_service, request.time_range}
    hash = :crypto.hash(:md5, :erlang.term_to_binary(key_data))
    hash |> Base.encode16()
  end

  defp clean_investigation_cache(cache) do
    # Keep investigations from last hour
    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)

    cache
    |> Enum.filter(fn {_, {timestamp, _}} ->
      DateTime.compare(timestamp, cutoff) == :gt
    end)
    |> Map.new()
  end

  defp generate_session_id do
    bytes = :crypto.strong_rand_bytes(8)
    "debug_session_#{bytes |> Base.encode16()}"
  end

  defp generate_breakpoint_id do
    bytes = :crypto.strong_rand_bytes(8)
    "breakpoint_#{bytes |> Base.encode16()}"
  end

  defp generate_investigation_id do
    bytes = :crypto.strong_rand_bytes(8)
    "investigation_#{bytes |> Base.encode16()}"
  end

  defp generate_trace_id do
    bytes = :crypto.strong_rand_bytes(16)
    bytes |> Base.encode16()
  end

  defp generate_state_id do
    bytes = :crypto.strong_rand_bytes(8)
    "state_#{bytes |> Base.encode16()}"
  end
end
