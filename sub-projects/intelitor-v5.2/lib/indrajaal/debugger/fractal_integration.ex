defmodule Indrajaal.Debugger.FractalIntegration do
  @moduledoc """
  Fractal logging integration for closed-loop debugger telemetry.

  WHAT: Integrates debugger events with 5-level fractal logging system.
  WHY: SC-DEBUG-002 requires all debug events to emit structured telemetry.
  CONSTRAINTS: L1-L5 hierarchy, OTEL correlation, RCA support.

  ## Fractal Level Mapping for Debugger Events

  ```
  L1 (Ecosystem)   - Debug session lifecycle across nodes
  L2 (Cluster)     - Multi-process debugging coordination
  L3 (Domain)      - Module-level breakpoint/step events
  L4 (Component)   - Function-level debugging detail
  L5 (Trace)       - Variable inspection, expression evaluation
  ```

  ## 5-Order Effects Analysis Support

  The debugger integration supports RCA (Root Cause Analysis) by correlating:

  1st Order → Breakpoint hit, immediate pause
  2nd Order → Stack unwinding, variable capture
  3rd Order → OTEL trace correlation, log aggregation
  4th Order → Cross-language debugging (Elixir ↔ F#)
  5th Order → Historical pattern analysis, predictive debugging

  ## STAMP Constraints

  - SC-DEBUG-002: Emit telemetry for all debug events
  - SC-DEBUG-003: Correlate with OTEL trace context
  - SC-LOG-001: Async dispatch (non-blocking)
  - SC-LOG-003: PII masking for variable inspection
  - SC-LOG-004: L1/L2 must link to L3 TraceID

  ## AOR Rules

  - AOR-DEBUG-001: Emit structured telemetry events
  - AOR-DEBUG-002: Correlate with OTEL traces
  - AOR-LOG-001: Patient Mode (never blocks caller)
  """

  require Logger

  alias Indrajaal.Observability.DualLogging
  alias Indrajaal.Debugger.TelemetryBus

  # Level mapping for debugger events
  @level_mapping %{
    # Session lifecycle - L1 (ecosystem-wide)
    session_start: :L1,
    session_end: :L1,
    session_pause: :L1,
    session_resume: :L1,

    # Breakpoint events - L3 (domain level)
    breakpoint_hit: :L3,
    breakpoint_set: :L3,
    breakpoint_removed: :L3,
    breakpoint_validated: :L3,

    # Stepping events - L3/L4 (domain/component)
    step_over: :L3,
    step_into: :L4,
    step_out: :L3,
    step_continue: :L3,

    # Stack/execution - L4 (component level)
    stack_trace: :L4,
    exception_caught: :L4,
    process_spawn: :L4,
    process_exit: :L4,

    # Variable/expression - L5 (trace level)
    variable_inspected: :L5,
    expression_evaluated: :L5,
    watch_updated: :L5,
    memory_inspected: :L5,

    # Cross-language events - L2 (cluster level)
    bridge_connected: :L2,
    bridge_disconnected: :L2,
    cross_language_call: :L2,
    grpc_request: :L2,
    grpc_response: :L2
  }

  # Domain for debugger events
  @debug_domain :debugger

  # ==========================================================================
  # Public API
  # ==========================================================================

  @doc """
  Start the fractal integration module.

  Attaches telemetry handlers and sets up the logging pipeline.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Log a debugger event at the appropriate fractal level.

  Automatically determines the fractal level based on event type
  and enriches the metadata with OTEL correlation.
  """
  @spec log_event(atom(), map()) :: :ok
  def log_event(event_type, metadata \\ %{}) do
    level = Map.get(@level_mapping, event_type, :L3)
    log_at_level(level, event_type, metadata)
  end

  @doc """
  Log a debugger event at a specific fractal level.
  """
  @spec log_at_level(atom(), atom(), map()) :: :ok
  def log_at_level(level, event_type, metadata) do
    # Enrich with correlation data
    enriched =
      enrich_metadata(event_type, metadata)
      |> Map.put(:fractal_level, level)

    # Format message
    message = format_debug_message(event_type, enriched)

    # Emit via dual logging (terminal + SigNoz)
    log_level = level_to_log_level(level)
    DualLogging.log_domain_event(@debug_domain, message, enriched, log_level)

    # Also emit to TelemetryBus for Zenoh distribution
    emit_to_telemetry_bus(event_type, enriched)

    :ok
  end

  # Map fractal levels to Elixir log levels
  defp level_to_log_level(:L1), do: :notice
  defp level_to_log_level(:L2), do: :info
  defp level_to_log_level(:L3), do: :info
  defp level_to_log_level(:L4), do: :debug
  defp level_to_log_level(:L5), do: :debug
  defp level_to_log_level(_), do: :info

  @doc """
  Perform 5-level RCA (Root Cause Analysis) correlation.

  Links events across the 5 fractal levels to enable drill-down
  analysis from ecosystem view (L1) to trace detail (L5).
  """
  @spec correlate_rca(String.t(), [atom()]) :: {:ok, map()} | {:error, term()}
  def correlate_rca(correlation_id, event_types \\ []) do
    # Build correlation query
    query = %{
      correlation_id: correlation_id,
      event_types: event_types,
      levels: [:L1, :L2, :L3, :L4, :L5]
    }

    # Collect events across levels
    events = collect_correlated_events(query)

    # Build RCA chain
    rca_chain = build_rca_chain(events)

    {:ok,
     %{
       correlation_id: correlation_id,
       event_count: length(events),
       rca_chain: rca_chain,
       impact_analysis: analyze_5_order_effects(events)
     }}
  end

  @doc """
  Create a debug span for OTEL integration.

  Returns a span context that correlates with fractal logs.
  """
  @spec start_debug_span(atom(), map()) :: map()
  def start_debug_span(operation, attributes \\ %{}) do
    span_name = "debugger.#{operation}"
    trace_id = get_current_trace_id()

    span_ctx = %{
      span_name: span_name,
      trace_id: trace_id,
      span_id: generate_span_id(),
      start_time: System.monotonic_time(:nanosecond),
      attributes:
        Map.merge(attributes, %{
          "debugger.operation" => to_string(operation),
          "debugger.language" => Map.get(attributes, :language, "elixir")
        })
    }

    # Emit span start
    :telemetry.execute(
      [:debugger, :span, :start],
      %{count: 1},
      %{span_ctx: span_ctx}
    )

    span_ctx
  end

  @doc """
  End a debug span.
  """
  @spec end_debug_span(map(), :ok | {:error, term()}) :: :ok
  def end_debug_span(span_ctx, result \\ :ok) do
    duration_ns = System.monotonic_time(:nanosecond) - span_ctx.start_time

    status =
      case result do
        :ok -> "OK"
        {:error, _} -> "ERROR"
        _ -> "UNKNOWN"
      end

    :telemetry.execute(
      [:debugger, :span, :end],
      %{duration_ns: duration_ns},
      %{span_ctx: span_ctx, status: status}
    )

    :ok
  end

  # ==========================================================================
  # GenServer Callbacks
  # ==========================================================================

  use GenServer

  @impl true
  def init(opts) do
    # Attach telemetry handlers
    attach_handlers()

    # Subscribe to TelemetryBus for cross-module events
    subscribe_to_bus()

    state = %{
      started_at: DateTime.utc_now(),
      event_count: 0,
      opts: opts
    }

    Logger.info("[FractalIntegration] Started - SC-DEBUG-002 active")

    {:ok, state}
  end

  @impl true
  def handle_info({:debugger_event, event_type, metadata}, state) do
    # Forward TelemetryBus events to fractal logging
    log_event(event_type, metadata)
    {:noreply, %{state | event_count: state.event_count + 1}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    detach_handlers()
    :ok
  end

  # ==========================================================================
  # Private Functions
  # ==========================================================================

  defp enrich_metadata(event_type, metadata) do
    trace_id = get_current_trace_id()
    span_id = get_current_span_id()

    metadata
    |> Map.put(:event_type, event_type)
    |> Map.put(:trace_id, trace_id)
    |> Map.put(:span_id, span_id)
    |> Map.put(:timestamp, DateTime.utc_now())
    |> Map.put(:fractal_level, Map.get(@level_mapping, event_type, :L3))
    |> maybe_mask_pii()
  end

  defp maybe_mask_pii(metadata) do
    # Mask sensitive fields (SC-LOG-003)
    sensitive_keys = [:password, :token, :secret, :key, :credential]

    Enum.reduce(sensitive_keys, metadata, fn key, acc ->
      if Map.has_key?(acc, key) do
        Map.put(acc, key, "[REDACTED]")
      else
        acc
      end
    end)
  end

  defp format_debug_message(event_type, metadata) do
    session_id = Map.get(metadata, :session_id, "unknown")
    language = Map.get(metadata, :language, "elixir")

    case event_type do
      :session_start ->
        "Debug session started: #{session_id} (#{language})"

      :session_end ->
        "Debug session ended: #{session_id}"

      :breakpoint_hit ->
        module = Map.get(metadata, :module, "?")
        line = Map.get(metadata, :line, "?")
        "Breakpoint hit at #{module}:#{line}"

      :breakpoint_set ->
        module = Map.get(metadata, :module, "?")
        line = Map.get(metadata, :line, "?")
        "Breakpoint set at #{module}:#{line}"

      :breakpoint_removed ->
        bp_id = Map.get(metadata, :breakpoint_id, "?")
        "Breakpoint removed: #{bp_id}"

      :step_over ->
        "Step over executed"

      :step_into ->
        "Step into executed"

      :step_out ->
        "Step out executed"

      :step_continue ->
        "Execution continued"

      :variable_inspected ->
        var_name = Map.get(metadata, :variable_name, "?")
        "Variable inspected: #{var_name}"

      :expression_evaluated ->
        expr = Map.get(metadata, :expression, "?") |> String.slice(0..50)
        "Expression evaluated: #{expr}..."

      :stack_trace ->
        frame_count = Map.get(metadata, :frame_count, 0)
        "Stack trace captured: #{frame_count} frames"

      :exception_caught ->
        exception = Map.get(metadata, :exception_type, "?")
        "Exception caught: #{exception}"

      :bridge_connected ->
        target = Map.get(metadata, :target_language, "?")
        "Cross-language bridge connected: #{target}"

      :bridge_disconnected ->
        target = Map.get(metadata, :target_language, "?")
        "Cross-language bridge disconnected: #{target}"

      :cross_language_call ->
        from = Map.get(metadata, :from_language, "?")
        to = Map.get(metadata, :to_language, "?")
        "Cross-language call: #{from} → #{to}"

      :grpc_request ->
        method = Map.get(metadata, :method, "?")
        "gRPC request: #{method}"

      :grpc_response ->
        method = Map.get(metadata, :method, "?")
        status = Map.get(metadata, :status, "?")
        "gRPC response: #{method} -> #{status}"

      _ ->
        "Debug event: #{event_type}"
    end
  end

  defp emit_to_telemetry_bus(event_type, metadata) do
    # Emit to TelemetryBus if it's a known debugger event
    known_events = [
      :session,
      :breakpoint_hit,
      :breakpoint_set,
      :breakpoint_removed,
      :step,
      :variable_inspected,
      :expression_evaluated,
      :stack_trace,
      :exception,
      :output
    ]

    # Map compound event types to bus event types
    bus_event_type =
      case event_type do
        :session_start -> :session
        :session_end -> :session
        :step_over -> :step
        :step_into -> :step
        :step_out -> :step
        :step_continue -> :step
        :exception_caught -> :exception
        other -> other
      end

    if bus_event_type in known_events do
      TelemetryBus.emit_debugger(bus_event_type, metadata)
    end
  rescue
    _ -> :ok
  end

  defp attach_handlers do
    events = [
      # Debug session events
      [:debugger, :session, :start],
      [:debugger, :session, :stop],

      # Breakpoint events
      [:debugger, :breakpoint, :set],
      [:debugger, :breakpoint, :hit],
      [:debugger, :breakpoint, :removed],

      # Step events
      [:debugger, :step, :over],
      [:debugger, :step, :into],
      [:debugger, :step, :out],
      [:debugger, :step, :continue],

      # Variable events
      [:debugger, :variable, :inspected],
      [:debugger, :expression, :evaluated],

      # Bridge events
      [:debugger, :bridge, :connected],
      [:debugger, :bridge, :disconnected],

      # gRPC events
      [:debugger, :grpc, :request],
      [:debugger, :grpc, :response]
    ]

    :telemetry.attach_many(
      "fractal-debugger-integration",
      events,
      &handle_telemetry_event/4,
      nil
    )
  end

  defp detach_handlers do
    :telemetry.detach("fractal-debugger-integration")
  rescue
    _ -> :ok
  end

  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    # Convert telemetry event name to debugger event type
    event_type = event_name_to_type(event_name)

    # Merge measurements into metadata
    enriched =
      Map.merge(metadata, %{
        measurements: measurements,
        telemetry_event: Enum.join(event_name, ".")
      })

    # Log via fractal system
    log_event(event_type, enriched)
  end

  defp event_name_to_type([:debugger, :session, :start]), do: :session_start
  defp event_name_to_type([:debugger, :session, :stop]), do: :session_end
  defp event_name_to_type([:debugger, :breakpoint, :set]), do: :breakpoint_set
  defp event_name_to_type([:debugger, :breakpoint, :hit]), do: :breakpoint_hit
  defp event_name_to_type([:debugger, :breakpoint, :removed]), do: :breakpoint_removed
  defp event_name_to_type([:debugger, :step, :over]), do: :step_over
  defp event_name_to_type([:debugger, :step, :into]), do: :step_into
  defp event_name_to_type([:debugger, :step, :out]), do: :step_out
  defp event_name_to_type([:debugger, :step, :continue]), do: :step_continue
  defp event_name_to_type([:debugger, :variable, :inspected]), do: :variable_inspected
  defp event_name_to_type([:debugger, :expression, :evaluated]), do: :expression_evaluated
  defp event_name_to_type([:debugger, :bridge, :connected]), do: :bridge_connected
  defp event_name_to_type([:debugger, :bridge, :disconnected]), do: :bridge_disconnected
  defp event_name_to_type([:debugger, :grpc, :request]), do: :grpc_request
  defp event_name_to_type([:debugger, :grpc, :response]), do: :grpc_response

  defp event_name_to_type(event_name) do
    event_name
    |> List.last()
    |> to_string()
    |> String.to_atom()
  end

  defp subscribe_to_bus do
    TelemetryBus.subscribe(self(), :all)
  rescue
    _ -> :ok
  end

  defp get_current_trace_id do
    # Get from OTEL context
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        generate_trace_id()

      ctx when is_tuple(ctx) ->
        # Extract trace_id from span context
        elem(ctx, 1) |> Integer.to_string(16) |> String.pad_leading(32, "0")

      _ ->
        generate_trace_id()
    end
  rescue
    _ -> generate_trace_id()
  end

  defp get_current_span_id do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        generate_span_id()

      ctx when is_tuple(ctx) ->
        elem(ctx, 2) |> Integer.to_string(16) |> String.pad_leading(16, "0")

      _ ->
        generate_span_id()
    end
  rescue
    _ -> generate_span_id()
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # ==========================================================================
  # RCA (Root Cause Analysis) Support
  # ==========================================================================

  defp collect_correlated_events(query) do
    # In production, this would query DuckDB or similar
    # For now, return mock structure
    [
      %{level: :L1, event: :session_start, correlation_id: query.correlation_id},
      %{level: :L3, event: :breakpoint_hit, correlation_id: query.correlation_id},
      %{level: :L4, event: :stack_trace, correlation_id: query.correlation_id},
      %{level: :L5, event: :variable_inspected, correlation_id: query.correlation_id}
    ]
    |> Enum.filter(fn e ->
      query.event_types == [] or e.event in query.event_types
    end)
  end

  defp build_rca_chain(events) do
    # Group by level and build causal chain
    events
    |> Enum.group_by(& &1.level)
    |> Enum.sort_by(fn {level, _} -> level_to_order(level) end)
    |> Enum.map(fn {level, level_events} ->
      %{
        level: level,
        order: level_to_order(level),
        events: level_events,
        description: level_description(level)
      }
    end)
  end

  defp level_to_order(:L1), do: 1
  defp level_to_order(:L2), do: 2
  defp level_to_order(:L3), do: 3
  defp level_to_order(:L4), do: 4
  defp level_to_order(:L5), do: 5
  defp level_to_order(_), do: 0

  defp level_description(:L1), do: "Ecosystem - Session lifecycle across nodes"
  defp level_description(:L2), do: "Cluster - Multi-process coordination"
  defp level_description(:L3), do: "Domain - Module-level events"
  defp level_description(:L4), do: "Component - Function-level detail"
  defp level_description(:L5), do: "Trace - Variable/expression detail"
  defp level_description(_), do: "Unknown level"

  defp analyze_5_order_effects(events) do
    # Build 5-order impact analysis
    %{
      first_order: %{
        description: "Immediate effect",
        effects: Enum.filter(events, &(&1.level == :L5)) |> length(),
        example: "Breakpoint hit, execution paused"
      },
      second_order: %{
        description: "Adjacent system reaction",
        effects: Enum.filter(events, &(&1.level == :L4)) |> length(),
        example: "Stack unwinding, variable capture"
      },
      third_order: %{
        description: "Integration effects",
        effects: Enum.filter(events, &(&1.level == :L3)) |> length(),
        example: "OTEL trace correlation, log aggregation"
      },
      fourth_order: %{
        description: "Cross-system effects",
        effects: Enum.filter(events, &(&1.level == :L2)) |> length(),
        example: "Cross-language debugging, gRPC coordination"
      },
      fifth_order: %{
        description: "Ecosystem effects",
        effects: Enum.filter(events, &(&1.level == :L1)) |> length(),
        example: "Session management, predictive debugging"
      }
    }
  end
end
