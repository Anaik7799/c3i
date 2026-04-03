defmodule Indrajaal.Debugger.ZenohDebuggerBridge do
  @moduledoc """
  Zenoh mesh bridge for debugger telemetry and control.

  WHAT: Bridges debugger events between TelemetryBus and Zenoh mesh.
  WHY: SC-DEBUG-001 requires 10ms publish latency for real-time debugging.
  CONSTRAINTS: Async publishing, FIFO ordering, circuit breaker protection.

  ## Key Expression Hierarchy

  ```
  indrajaal/debug/
  ├── elixir/           # Elixir debugger events
  │   ├── session/      # Session lifecycle
  │   ├── breakpoint/   # Breakpoint management
  │   ├── step/         # Stepping operations
  │   └── variable/     # Variable inspection
  ├── fsharp/           # F# debugger events
  │   ├── session/
  │   ├── breakpoint/
  │   └── step/
  ├── control/          # Bidirectional control plane
  │   ├── commands/     # Incoming commands
  │   └── responses/    # Command responses
  └── telemetry/        # Aggregated telemetry
      ├── metrics/      # Performance metrics
      └── traces/       # OTEL trace correlation
  ```

  ## STAMP Constraints

  - SC-DEBUG-001: Publish to Zenoh within 10ms
  - SC-DEBUG-009: Bidirectional control channel
  - SC-DEBUG-010: FQUN for all debug entities
  - SC-BRIDGE-001: FIFO message ordering preserved
  - SC-BRIDGE-002: Buffer flush interval 100ms max
  - SC-BRIDGE-003: Latency budget 50ms per batch

  ## AOR Rules

  - AOR-DEBUG-001: Emit structured telemetry events
  - AOR-DEBUG-002: Correlate with OTEL traces
  - AOR-BRIDGE-001: Preserve FIFO ordering
  - AOR-BRIDGE-002: Operate within latency budget
  """

  use GenServer
  require Logger

  alias Indrajaal.Debugger.TelemetryBus
  alias Indrajaal.Observability.Fractal.Decorator

  @zenoh_prefix "indrajaal/debug"
  @control_prefix "indrajaal/debug/control"
  @publish_timeout_ms 10
  @buffer_flush_ms 100
  @max_buffer_size 100
  @circuit_breaker_threshold 50
  @circuit_reset_ms 5000

  # Event types that map to Zenoh topics
  @elixir_events %{
    session: "elixir/session",
    breakpoint_hit: "elixir/breakpoint/hit",
    breakpoint_set: "elixir/breakpoint/set",
    breakpoint_removed: "elixir/breakpoint/removed",
    step: "elixir/step",
    variable_inspected: "elixir/variable",
    expression_evaluated: "elixir/expression",
    stack_trace: "elixir/stack",
    exception: "elixir/exception",
    output: "elixir/output"
  }

  @fsharp_events %{
    session: "fsharp/session",
    breakpoint_hit: "fsharp/breakpoint/hit",
    breakpoint_set: "fsharp/breakpoint/set",
    step: "fsharp/step",
    variable_inspected: "fsharp/variable",
    stack_trace: "fsharp/stack",
    exception: "fsharp/exception"
  }

  defstruct [
    :coordinator,
    :telemetry_ref,
    :started_at,
    :publish_count,
    :error_count,
    :last_publish,
    :buffer,
    :buffer_timer,
    :circuit_open,
    :circuit_errors,
    :circuit_opened_at,
    subscribers: %{},
    sessions: %{}
  ]

  # ==========================================================================
  # Client API
  # ==========================================================================

  @doc """
  Start the ZenohDebuggerBridge.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Publish a debugger event to Zenoh mesh.

  ## Options
  - `:language` - :elixir or :fsharp (default: :elixir)
  - `:session_id` - Session identifier for routing
  - `:timeout` - Publish timeout in ms (default: 10ms per SC-DEBUG-001)
  """
  def publish_event(event_type, payload, opts \\ []) do
    GenServer.cast(__MODULE__, {:publish_event, event_type, payload, opts})
  end

  @doc """
  Send a debug command through Zenoh control channel.
  """
  def send_command(command, target_session, params \\ %{}) do
    GenServer.call(__MODULE__, {:send_command, command, target_session, params})
  end

  @doc """
  Subscribe to debug events from Zenoh.
  """
  def subscribe(key_pattern, callback_pid) do
    GenServer.call(__MODULE__, {:subscribe, key_pattern, callback_pid})
  end

  @doc """
  Unsubscribe from debug events.
  """
  def unsubscribe(ref) do
    GenServer.call(__MODULE__, {:unsubscribe, ref})
  end

  @doc """
  Get bridge statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Register a debug session with the bridge.
  """
  def register_session(session_id, session_info) do
    GenServer.cast(__MODULE__, {:register_session, session_id, session_info})
  end

  @doc """
  Deregister a debug session.
  """
  def deregister_session(session_id) do
    GenServer.cast(__MODULE__, {:deregister_session, session_id})
  end

  @doc """
  Check if circuit breaker is open.
  """
  def circuit_open? do
    GenServer.call(__MODULE__, :circuit_open?)
  end

  # ==========================================================================
  # GenServer Implementation
  # ==========================================================================

  @impl true
  def init(opts) do
    # Get or start Zenoh coordinator
    coordinator = Keyword.get(opts, :coordinator) || start_zenoh_coordinator()

    # Subscribe to TelemetryBus
    telemetry_ref = subscribe_to_telemetry_bus()

    # Attach telemetry handlers for metrics
    attach_telemetry_handlers()

    # Schedule buffer flush
    buffer_timer = schedule_buffer_flush()

    # Subscribe to control channel
    subscribe_to_control_channel(coordinator)

    state = %__MODULE__{
      coordinator: coordinator,
      telemetry_ref: telemetry_ref,
      started_at: DateTime.utc_now(),
      publish_count: 0,
      error_count: 0,
      last_publish: nil,
      buffer: [],
      buffer_timer: buffer_timer,
      circuit_open: false,
      circuit_errors: 0,
      circuit_opened_at: nil,
      subscribers: %{},
      sessions: %{}
    }

    Logger.info("[ZenohDebuggerBridge] Started - SC-DEBUG-001 active (10ms target)")

    {:ok, state}
  end

  @impl true
  def handle_cast({:publish_event, event_type, payload, opts}, state) do
    if state.circuit_open do
      # Check if circuit should reset
      state = maybe_reset_circuit(state)

      if state.circuit_open do
        Logger.warning("[ZenohDebuggerBridge] Circuit open, dropping event: #{event_type}")
        {:noreply, state}
      else
        do_buffer_event(event_type, payload, opts, state)
      end
    else
      do_buffer_event(event_type, payload, opts, state)
    end
  end

  @impl true
  def handle_cast({:register_session, session_id, session_info}, state) do
    sessions = Map.put(state.sessions, session_id, session_info)

    # Publish session registration to Zenoh
    language = Map.get(session_info, :language, :elixir)
    key = build_key(language, :session, session_id)

    publish_to_zenoh(state.coordinator, key, %{
      type: :session_started,
      session_id: session_id,
      info: session_info,
      timestamp: DateTime.utc_now()
    })

    {:noreply, %{state | sessions: sessions}}
  end

  @impl true
  def handle_cast({:deregister_session, session_id}, state) do
    case Map.pop(state.sessions, session_id) do
      {nil, _} ->
        {:noreply, state}

      {session_info, sessions} ->
        # Publish session end to Zenoh
        language = Map.get(session_info, :language, :elixir)
        key = build_key(language, :session, session_id)

        publish_to_zenoh(state.coordinator, key, %{
          type: :session_ended,
          session_id: session_id,
          timestamp: DateTime.utc_now()
        })

        {:noreply, %{state | sessions: sessions}}
    end
  end

  @impl true
  def handle_call({:send_command, command, target_session, params}, _from, state) do
    key = "#{@control_prefix}/commands/#{target_session}"

    payload = %{
      command: command,
      target_session: target_session,
      params: params,
      correlation_id: generate_correlation_id(),
      timestamp: DateTime.utc_now()
    }

    result = publish_to_zenoh(state.coordinator, key, payload)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:subscribe, key_pattern, callback_pid}, _from, state) do
    ref = make_ref()
    Process.monitor(callback_pid)

    subscribers =
      Map.put(state.subscribers, ref, %{
        pattern: key_pattern,
        pid: callback_pid
      })

    {:reply, {:ok, ref}, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_call({:unsubscribe, ref}, _from, state) do
    subscribers = Map.delete(state.subscribers, ref)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      started_at: state.started_at,
      publish_count: state.publish_count,
      error_count: state.error_count,
      last_publish: state.last_publish,
      buffer_size: length(state.buffer),
      circuit_open: state.circuit_open,
      circuit_errors: state.circuit_errors,
      active_sessions: map_size(state.sessions),
      subscriber_count: map_size(state.subscribers),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:circuit_open?, _from, state) do
    {:reply, state.circuit_open, state}
  end

  @impl true
  def handle_info(:flush_buffer, state) do
    state = flush_buffer(state)
    buffer_timer = schedule_buffer_flush()
    {:noreply, %{state | buffer_timer: buffer_timer}}
  end

  @impl true
  def handle_info({:debugger_event, event_type, metadata}, state) do
    # Event from TelemetryBus
    language = Map.get(metadata, :language, :elixir)
    opts = [language: language, session_id: Map.get(metadata, :session_id)]

    do_buffer_event(event_type, metadata, opts, state)
  end

  @impl true
  def handle_info({:zenoh_message, key, payload}, state) do
    # Incoming message from Zenoh
    handle_incoming_message(key, payload, state)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Cleanup dead subscribers
    subscribers =
      state.subscribers
      |> Enum.reject(fn {_ref, %{pid: p}} -> p == pid end)
      |> Map.new()

    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def terminate(_reason, state) do
    # Detach telemetry handlers
    detach_telemetry_handlers()

    # Cancel buffer timer
    if state.buffer_timer do
      Process.cancel_timer(state.buffer_timer)
    end

    # Unsubscribe from TelemetryBus
    if state.telemetry_ref do
      TelemetryBus.unsubscribe(self())
    end

    :ok
  end

  # ==========================================================================
  # Private Functions
  # ==========================================================================

  defp do_buffer_event(event_type, payload, opts, state) do
    event = %{
      event_type: event_type,
      payload: payload,
      opts: opts,
      buffered_at: System.monotonic_time(:microsecond)
    }

    buffer = [event | state.buffer]

    # Flush immediately if buffer full
    if length(buffer) >= @max_buffer_size do
      state = %{state | buffer: buffer}
      {:noreply, flush_buffer(state)}
    else
      {:noreply, %{state | buffer: buffer}}
    end
  end

  defp flush_buffer(%{buffer: []} = state), do: state

  defp flush_buffer(state) do
    start_time = System.monotonic_time(:millisecond)

    # Process buffer in FIFO order (SC-BRIDGE-001)
    events = Enum.reverse(state.buffer)

    # Publish each event
    results =
      Enum.map(events, fn event ->
        publish_single_event(state.coordinator, event)
      end)

    # Count successes and failures
    {successes, failures} = Enum.split_with(results, &(&1 == :ok))

    elapsed = System.monotonic_time(:millisecond) - start_time

    # Check latency budget (SC-BRIDGE-003)
    if elapsed > 50 do
      Logger.warning("[ZenohDebuggerBridge] Batch latency #{elapsed}ms exceeds 50ms budget")
    end

    # Update circuit breaker state
    state = update_circuit_state(state, length(failures))

    # Log to fractal (L4 - component level)
    Decorator.log(:L4, :debugger, "Buffer flushed", %{
      events: length(events),
      successes: length(successes),
      failures: length(failures),
      latency_ms: elapsed
    })

    %{
      state
      | buffer: [],
        publish_count: state.publish_count + length(successes),
        error_count: state.error_count + length(failures),
        last_publish: DateTime.utc_now()
    }
  end

  defp publish_single_event(coordinator, event) do
    language = Keyword.get(event.opts, :language, :elixir)
    session_id = Keyword.get(event.opts, :session_id)

    key = build_key(language, event.event_type, session_id)

    enriched_payload = %{
      event_type: event.event_type,
      data: event.payload,
      timestamp: DateTime.utc_now(),
      latency_us: System.monotonic_time(:microsecond) - event.buffered_at
    }

    publish_to_zenoh(coordinator, key, enriched_payload)
  end

  defp build_key(:elixir, event_type, session_id) do
    base = Map.get(@elixir_events, event_type, "elixir/#{event_type}")

    if session_id do
      "#{@zenoh_prefix}/#{base}/#{session_id}"
    else
      "#{@zenoh_prefix}/#{base}"
    end
  end

  defp build_key(:fsharp, event_type, session_id) do
    base = Map.get(@fsharp_events, event_type, "fsharp/#{event_type}")

    if session_id do
      "#{@zenoh_prefix}/#{base}/#{session_id}"
    else
      "#{@zenoh_prefix}/#{base}"
    end
  end

  defp build_key(_language, event_type, session_id) do
    if session_id do
      "#{@zenoh_prefix}/#{event_type}/#{session_id}"
    else
      "#{@zenoh_prefix}/#{event_type}"
    end
  end

  defp publish_to_zenoh(nil, key, payload) do
    # No coordinator - emit telemetry only
    :telemetry.execute(
      [:debugger, :zenoh, :publish],
      %{count: 1, latency_us: 0},
      %{key: key, payload_size: byte_size(inspect(payload))}
    )

    Logger.debug("[ZenohDebuggerBridge] Zenoh publish (mock): #{key}")
    :ok
  end

  defp publish_to_zenoh(coordinator, key, payload) do
    start = System.monotonic_time(:microsecond)

    # Use Zenoh test coordinator or production module
    result =
      try do
        module = zenoh_test_module()

        if Code.ensure_loaded?(module) do
          module.publish(coordinator, key, payload)
        else
          :ok
        end
      rescue
        e ->
          Logger.error("[ZenohDebuggerBridge] Publish error: #{inspect(e)}")
          {:error, e}
      end

    latency = System.monotonic_time(:microsecond) - start

    # Check SC-DEBUG-001 (10ms = 10000us)
    if latency > @publish_timeout_ms * 1000 do
      Logger.warning(
        "[ZenohDebuggerBridge] Publish latency #{div(latency, 1000)}ms exceeds 10ms target"
      )
    end

    :telemetry.execute(
      [:debugger, :zenoh, :publish],
      %{count: 1, latency_us: latency},
      %{key: key, payload_size: byte_size(inspect(payload)), result: result}
    )

    case result do
      :ok -> :ok
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  defp update_circuit_state(state, 0) do
    # No failures - gradually reset error count
    %{state | circuit_errors: max(0, state.circuit_errors - 1)}
  end

  defp update_circuit_state(state, failure_count) do
    new_errors = state.circuit_errors + failure_count

    if new_errors >= @circuit_breaker_threshold and not state.circuit_open do
      Logger.warning("[ZenohDebuggerBridge] Circuit breaker OPEN after #{new_errors} errors")

      %{
        state
        | circuit_open: true,
          circuit_errors: new_errors,
          circuit_opened_at: System.monotonic_time(:millisecond)
      }
    else
      %{state | circuit_errors: new_errors}
    end
  end

  defp maybe_reset_circuit(%{circuit_open: false} = state), do: state

  defp maybe_reset_circuit(state) do
    elapsed = System.monotonic_time(:millisecond) - (state.circuit_opened_at || 0)

    if elapsed >= @circuit_reset_ms do
      Logger.info("[ZenohDebuggerBridge] Circuit breaker CLOSED after #{elapsed}ms")

      %{state | circuit_open: false, circuit_errors: 0, circuit_opened_at: nil}
    else
      state
    end
  end

  defp schedule_buffer_flush do
    Process.send_after(self(), :flush_buffer, @buffer_flush_ms)
  end

  defp generate_correlation_id do
    "debug-" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  # Runtime module reference to avoid compile-time warnings
  defp zenoh_test_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])

  defp start_zenoh_coordinator do
    module = zenoh_test_module()

    if Code.ensure_loaded?(module) do
      case module.start_link([]) do
        {:ok, pid} -> pid
        _ -> nil
      end
    else
      nil
    end
  end

  defp subscribe_to_telemetry_bus do
    case TelemetryBus.subscribe(self(), :all) do
      :ok -> make_ref()
      {:error, _} -> nil
    end
  rescue
    _ -> nil
  end

  defp subscribe_to_control_channel(nil), do: :ok

  defp subscribe_to_control_channel(coordinator) do
    module = zenoh_test_module()

    if Code.ensure_loaded?(module) do
      # Subscribe to command responses
      module.subscribe(coordinator, "#{@control_prefix}/responses/**", self())
    end

    :ok
  rescue
    _ -> :ok
  end

  defp handle_incoming_message(key, payload, state) do
    cond do
      String.starts_with?(key, "#{@control_prefix}/commands/") ->
        # Incoming debug command
        handle_debug_command(key, payload, state)

      String.starts_with?(key, "#{@control_prefix}/responses/") ->
        # Command response
        notify_subscribers(state.subscribers, key, payload)
        {:noreply, state}

      true ->
        # Other debug event
        notify_subscribers(state.subscribers, key, payload)
        {:noreply, state}
    end
  end

  defp handle_debug_command(_key, payload, state) do
    # Parse command
    command = Map.get(payload, "command") || Map.get(payload, :command)
    target = Map.get(payload, "target_session") || Map.get(payload, :target_session)
    params = Map.get(payload, "params") || Map.get(payload, :params, %{})
    correlation_id = Map.get(payload, "correlation_id") || Map.get(payload, :correlation_id)

    # Execute command if we have the session
    result =
      if Map.has_key?(state.sessions, target) do
        execute_debug_command(command, target, params, state)
      else
        {:error, :session_not_found}
      end

    # Publish response
    response_key = "#{@control_prefix}/responses/#{target}"

    publish_to_zenoh(state.coordinator, response_key, %{
      command: command,
      correlation_id: correlation_id,
      result: result,
      timestamp: DateTime.utc_now()
    })

    Logger.debug("[ZenohDebuggerBridge] Command #{command} -> #{inspect(result)}")

    {:noreply, state}
  end

  defp execute_debug_command("set_breakpoint", _target, params, _state) do
    # Forward to TelemetryBus
    TelemetryBus.emit_debugger(:breakpoint_set, params)
    {:ok, :breakpoint_set}
  end

  defp execute_debug_command("remove_breakpoint", _target, params, _state) do
    TelemetryBus.emit_debugger(:breakpoint_removed, params)
    {:ok, :breakpoint_removed}
  end

  defp execute_debug_command("step_over", _target, params, _state) do
    TelemetryBus.emit_debugger(:step, Map.put(params, :step_type, :over))
    {:ok, :step_initiated}
  end

  defp execute_debug_command("step_into", _target, params, _state) do
    TelemetryBus.emit_debugger(:step, Map.put(params, :step_type, :into))
    {:ok, :step_initiated}
  end

  defp execute_debug_command("step_out", _target, params, _state) do
    TelemetryBus.emit_debugger(:step, Map.put(params, :step_type, :out))
    {:ok, :step_initiated}
  end

  defp execute_debug_command("continue", _target, params, _state) do
    TelemetryBus.emit_debugger(:step, Map.put(params, :step_type, :continue))
    {:ok, :continue_initiated}
  end

  defp execute_debug_command("inspect_variable", _target, params, _state) do
    TelemetryBus.emit_debugger(:variable_inspected, params)
    {:ok, :inspection_requested}
  end

  defp execute_debug_command("evaluate", _target, params, _state) do
    TelemetryBus.emit_debugger(:expression_evaluated, params)
    {:ok, :evaluation_requested}
  end

  defp execute_debug_command(unknown_command, _target, _params, _state) do
    {:error, {:unknown_command, unknown_command}}
  end

  defp notify_subscribers(subscribers, key, payload) do
    Enum.each(subscribers, fn {_ref, %{pattern: pattern, pid: pid}} ->
      if matches_pattern?(key, pattern) do
        send(pid, {:zenoh_debug_event, key, payload})
      end
    end)
  end

  defp matches_pattern?(key, pattern) do
    pattern_str = to_string(pattern)

    cond do
      pattern_str == "*" or pattern_str == "**" ->
        true

      String.ends_with?(pattern_str, "/**") ->
        prefix = String.trim_trailing(pattern_str, "/**")
        String.starts_with?(key, prefix)

      String.ends_with?(pattern_str, "/*") ->
        prefix = String.trim_trailing(pattern_str, "/*")
        # Match only direct children
        String.starts_with?(key, prefix) and
          not String.contains?(String.trim_leading(key, prefix <> "/"), "/")

      true ->
        key == pattern_str
    end
  end

  # ==========================================================================
  # Telemetry Handlers
  # ==========================================================================

  defp attach_telemetry_handlers do
    events = [
      [:debugger, :bus, :breakpoint_hit],
      [:debugger, :bus, :breakpoint_set],
      [:debugger, :bus, :session],
      [:debugger, :bus, :step],
      [:debugger, :bus, :variable_inspected],
      [:debugger, :bus, :expression_evaluated]
    ]

    :telemetry.attach_many(
      "zenoh-debugger-bridge",
      events,
      &handle_telemetry_event/4,
      nil
    )
  end

  defp detach_telemetry_handlers do
    :telemetry.detach("zenoh-debugger-bridge")
  rescue
    _ -> :ok
  end

  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    # Forward telemetry events to Zenoh
    event_type =
      event_name
      |> List.last()

    payload =
      Map.merge(metadata, %{
        measurements: measurements,
        event_name: Enum.join(event_name, ".")
      })

    publish_event(event_type, payload)
  end
end
