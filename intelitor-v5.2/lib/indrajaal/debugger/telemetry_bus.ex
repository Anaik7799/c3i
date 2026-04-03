defmodule Indrajaal.Debugger.TelemetryBus do
  @moduledoc """
  Unified Telemetry Bus for Debugger Events.

  Provides centralized pub/sub for debugger telemetry with:
  - Zenoh mesh publishing for real-time events
  - gRPC streaming to connected clients
  - Fractal log integration (L1-L5)
  - OTEL trace correlation

  ## Usage

      # Emit debugger event
      TelemetryBus.emit_debugger(:breakpoint_hit, %{
        breakpoint_id: "bp-123",
        module: MyApp.User,
        line: 42
      })

      # Emit to Zenoh
      TelemetryBus.emit(:zenoh, :publish, %{
        topic: "indrajaal/debug/elixir/breakpoint/hit",
        payload: %{...}
      })

  ## STAMP Constraints

  - SC-DEBUG-001: Publish to Zenoh within 10ms
  - SC-DEBUG-002: Emit telemetry for all debug events
  - SC-DEBUG-003: Correlate with OTEL trace context
  - SC-DEBUG-008: Maximum 10K events/sec throughput
  - SC-BUS-001: Async messaging only
  - SC-BUS-002: No blocking operations
  - SC-BUS-003: Circuit breaker at 1000 events/sec
  - SC-BUS-004: Event ordering preserved

  ## AOR Rules

  - AOR-DEBUG-001: Emit structured telemetry events
  - AOR-DEBUG-002: Correlate with OTEL traces
  - AOR-BUS-001: Async dispatch only
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.Fractal.Decorator

  @zenoh_prefix "indrajaal/debug"
  @circuit_breaker_threshold 1000
  @rate_window_ms 1000

  # Event types
  @debugger_events ~w(
    session breakpoint_hit breakpoint_set breakpoint_removed
    step variable_inspected expression_evaluated
    stack_trace exception output
  )a

  # State
  defstruct [
    :subscribers,
    :event_count,
    :window_start,
    :circuit_open,
    :correlation_id,
    :otel_ctx
  ]

  # ==========================================================================
  # Client API
  # ==========================================================================

  @doc """
  Start the TelemetryBus.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Emit a debugger telemetry event.
  """
  def emit_debugger(event_type, metadata) when event_type in @debugger_events do
    GenServer.cast(__MODULE__, {:emit_debugger, event_type, metadata})
  end

  @doc """
  Emit to specific channel (zenoh, grpc, fractal, otel).
  """
  def emit(channel, action, payload) when channel in [:zenoh, :grpc, :fractal, :otel] do
    GenServer.cast(__MODULE__, {:emit, channel, action, payload})
  end

  @doc """
  Subscribe to debugger events.
  """
  def subscribe(subscriber_pid, event_filter \\ :all) do
    GenServer.call(__MODULE__, {:subscribe, subscriber_pid, event_filter})
  end

  @doc """
  Unsubscribe from debugger events.
  """
  def unsubscribe(subscriber_pid) do
    GenServer.call(__MODULE__, {:unsubscribe, subscriber_pid})
  end

  @doc """
  Get current statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
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
  def init(_opts) do
    # Attach telemetry handlers
    attach_telemetry_handlers()

    {:ok,
     %__MODULE__{
       subscribers: %{},
       event_count: 0,
       window_start: System.monotonic_time(:millisecond),
       circuit_open: false,
       correlation_id: nil,
       otel_ctx: nil
     }}
  end

  @impl true
  def handle_cast({:emit_debugger, event_type, metadata}, state) do
    state = check_rate_limit(state)

    if state.circuit_open do
      Logger.warning("[TelemetryBus] Circuit breaker open, dropping event: #{event_type}")
      {:noreply, state}
    else
      # Generate correlation ID for this event chain
      correlation_id = generate_correlation_id()

      # Enrich metadata with correlation
      enriched =
        Map.merge(metadata, %{
          correlation_id: correlation_id,
          timestamp: DateTime.utc_now(),
          event_type: event_type
        })

      # Dispatch to all channels asynchronously
      Task.start(fn -> dispatch_event(event_type, enriched) end)

      # Notify subscribers
      notify_subscribers(state.subscribers, event_type, enriched)

      # Emit to BEAM telemetry
      :telemetry.execute(
        [:debugger, :bus, event_type],
        %{count: 1},
        enriched
      )

      {:noreply, %{state | event_count: state.event_count + 1}}
    end
  end

  @impl true
  def handle_cast({:emit, :zenoh, :publish, payload}, state) do
    state = check_rate_limit(state)

    unless state.circuit_open do
      Task.start(fn -> publish_to_zenoh(payload) end)
    end

    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  @impl true
  def handle_cast({:emit, :grpc, :stream, payload}, state) do
    Task.start(fn -> stream_to_grpc(payload) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:emit, :fractal, :log, payload}, state) do
    Task.start(fn -> log_to_fractal(payload) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:emit, :otel, :span, payload}, state) do
    Task.start(fn -> emit_otel_span(payload) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:subscribe, pid, filter}, _from, state) do
    ref = Process.monitor(pid)
    subscribers = Map.put(state.subscribers, pid, %{ref: ref, filter: filter})
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_call({:unsubscribe, pid}, _from, state) do
    case Map.pop(state.subscribers, pid) do
      {nil, _} ->
        {:reply, {:error, :not_subscribed}, state}

      {%{ref: ref}, new_subscribers} ->
        Process.demonitor(ref, [:flush])
        {:reply, :ok, %{state | subscribers: new_subscribers}}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      subscribers: map_size(state.subscribers),
      event_count: state.event_count,
      circuit_open: state.circuit_open,
      rate: calculate_rate(state)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:circuit_open?, _from, state) do
    {:reply, state.circuit_open, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    subscribers = Map.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: subscribers}}
  end

  # ==========================================================================
  # Private Functions
  # ==========================================================================

  defp attach_telemetry_handlers do
    events = [
      [:debugger, :breakpoint, :set],
      [:debugger, :breakpoint, :hit],
      [:debugger, :step, :complete],
      [:debugger, :variable, :inspected],
      [:debugger, :session, :start],
      [:debugger, :session, :stop]
    ]

    :telemetry.attach_many(
      "debugger-bus-handler",
      events,
      &handle_telemetry_event/4,
      nil
    )
  end

  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    # Forward to fractal logging
    level = determine_log_level(event_name)
    domain = :debugger

    Decorator.log(level, domain, format_event_message(event_name), %{
      measurements: measurements,
      metadata: metadata
    })
  end

  defp determine_log_level([:debugger, :breakpoint, :hit]), do: :L3
  defp determine_log_level([:debugger, :session, _]), do: :L3
  defp determine_log_level([:debugger, _, _]), do: :L4
  defp determine_log_level(_), do: :L5

  defp format_event_message(event_name) do
    event_name
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
  end

  defp check_rate_limit(state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.window_start

    cond do
      elapsed >= @rate_window_ms ->
        # Reset window
        %{state | event_count: 0, window_start: now, circuit_open: false}

      state.event_count >= @circuit_breaker_threshold and not state.circuit_open ->
        Logger.warning(
          "[TelemetryBus] Circuit breaker triggered at #{state.event_count} events/sec"
        )

        %{state | circuit_open: true}

      true ->
        state
    end
  end

  defp calculate_rate(state) do
    now = System.monotonic_time(:millisecond)
    elapsed = max(now - state.window_start, 1)
    state.event_count * 1000 / elapsed
  end

  defp generate_correlation_id do
    "corr-" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  defp dispatch_event(event_type, metadata) do
    # Dispatch to all channels
    dispatch_to_zenoh(event_type, metadata)
    dispatch_to_fractal(event_type, metadata)
    dispatch_to_otel(event_type, metadata)
  end

  defp dispatch_to_zenoh(event_type, metadata) do
    topic = build_zenoh_topic(event_type, metadata)

    payload = %{
      event_type: event_type,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    publish_to_zenoh(%{topic: topic, payload: payload})
  end

  defp build_zenoh_topic(:session, %{session_id: session_id}) do
    "#{@zenoh_prefix}/session/#{session_id}"
  end

  defp build_zenoh_topic(:breakpoint_hit, %{session_id: session_id}) do
    "#{@zenoh_prefix}/breakpoint/hit/#{session_id}"
  end

  defp build_zenoh_topic(:breakpoint_set, %{module: module, line: line}) do
    "#{@zenoh_prefix}/breakpoint/#{module}/#{line}"
  end

  defp build_zenoh_topic(:step, %{session_id: session_id}) do
    "#{@zenoh_prefix}/step/#{session_id}"
  end

  defp build_zenoh_topic(:variable_inspected, %{session_id: session_id, variable: var}) do
    "#{@zenoh_prefix}/variable/#{session_id}/#{var}"
  end

  defp build_zenoh_topic(event_type, _metadata) do
    "#{@zenoh_prefix}/#{event_type}"
  end

  defp publish_to_zenoh(%{topic: topic, payload: payload, timeout: timeout}) do
    # In production, this would use the Zenoh NIF
    # For now, emit telemetry
    :telemetry.execute(
      [:debugger, :zenoh, :publish],
      %{topic_length: String.length(topic), payload_size: byte_size(inspect(payload))},
      %{topic: topic, timeout: timeout}
    )

    Logger.debug("[TelemetryBus] Zenoh publish: #{topic}")
    :ok
  end

  defp publish_to_zenoh(%{topic: topic, payload: payload}) do
    publish_to_zenoh(%{topic: topic, payload: payload, timeout: 10})
  end

  defp dispatch_to_fractal(event_type, metadata) do
    level = determine_log_level([:debugger, event_type])
    message = "Debugger event: #{event_type}"

    Decorator.log(level, :debugger, message, metadata)
  end

  defp dispatch_to_otel(event_type, metadata) do
    # Create span for debug event
    span_name = "debugger.#{event_type}"

    attributes = [
      {"debugger.event_type", to_string(event_type)},
      {"debugger.correlation_id", metadata[:correlation_id] || "unknown"}
    ]

    # In production, this would create OTEL span
    :telemetry.execute(
      [:debugger, :otel, :span],
      %{duration_ns: 0},
      %{span_name: span_name, attributes: attributes}
    )
  end

  defp stream_to_grpc(_payload) do
    # In production, stream to connected gRPC clients
    :ok
  end

  defp log_to_fractal(payload) do
    level = Map.get(payload, :level, :L4)
    domain = Map.get(payload, :domain, :debugger)
    message = Map.get(payload, :message, "Debug event")
    metadata = Map.get(payload, :metadata, %{})

    Decorator.log(level, domain, message, metadata)
  end

  defp emit_otel_span(_payload) do
    # In production, emit OTEL span
    :ok
  end

  defp notify_subscribers(subscribers, event_type, metadata) do
    Enum.each(subscribers, fn {pid, %{filter: filter}} ->
      if filter == :all or event_type in filter do
        send(pid, {:debugger_event, event_type, metadata})
      end
    end)
  end
end
