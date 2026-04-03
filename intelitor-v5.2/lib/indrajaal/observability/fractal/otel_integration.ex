defmodule Indrajaal.Observability.Fractal.OtelIntegration do
  @moduledoc """
  OpenTelemetry Integration for the Fractal Logging System.

  Provides seamless integration between the Fractal logging levels and
  OpenTelemetry spans, enabling:
  - Automatic span creation for traced functions
  - Fractal-level injection into span attributes
  - Baggage propagation with `ot-baggage-fractal-*` headers
  - TraceID linking for L1/L2 logs (SC-LOG-004)

  ## STAMP Compliance
  - SC-LOG-004: L1/L2 must link to L3 TraceID (propagated via baggage)
  - SC-OBS-069: Dual Log (Term+SigNoz) integration

  ## Baggage Headers
  The following baggage headers are propagated:
  - `ot-baggage-fractal-level` - Current fractal level (l1-l5)
  - `ot-baggage-fractal-module` - Module name
  - `ot-baggage-fractal-function` - Function name
  - `ot-baggage-fractal-boost` - Active boost ID (if any)
  - `ot-baggage-fractal-trace-id` - L3 TraceID for correlation

  ## Usage

      # Start a fractal span
      span_ctx = OtelIntegration.start_fractal_span(MyModule, :my_func, :l3)

      # ... do work ...

      # End the span
      OtelIntegration.end_fractal_span(span_ctx, :ok)

      # Or with error
      OtelIntegration.end_fractal_span(span_ctx, {:error, exception})
  """

  require Logger

  alias Indrajaal.Observability.Fractal.{FractalControl, HLC}

  # ============================================================
  # TYPES
  # ============================================================

  @type fractal_level :: FractalControl.fractal_level()
  @type span_context :: map() | nil

  # ============================================================
  # CONSTANTS
  # ============================================================

  @fractal_baggage_prefix "ot-baggage-fractal-"

  @baggage_keys %{
    level: "#{@fractal_baggage_prefix}level",
    module: "#{@fractal_baggage_prefix}module",
    function: "#{@fractal_baggage_prefix}function",
    boost: "#{@fractal_baggage_prefix}boost",
    trace_id: "#{@fractal_baggage_prefix}trace-id",
    hlc: "#{@fractal_baggage_prefix}hlc",
    # SC-LOG-009: Additional baggage for key alias pre-registration
    expr: "#{@fractal_baggage_prefix}expr",
    depth: "#{@fractal_baggage_prefix}depth",
    filter: "#{@fractal_baggage_prefix}filter"
  }

  @level_to_string %{
    l1: "L1",
    l2: "L2",
    l3: "L3",
    l4: "L4",
    l5: "L5"
  }

  # ============================================================
  # SPAN MANAGEMENT
  # ============================================================

  @doc """
  Start a new OTel span for a fractal-traced function.

  Creates a span with fractal-specific attributes:
  - `fractal.level` - The fractal level (L1-L5)
  - `fractal.module` - The module name
  - `fractal.function` - The function name
  - `fractal.hlc` - HLC timestamp for causal ordering

  ## Parameters
  - `module` - The module containing the function
  - `function` - The function name
  - `level` - The fractal level

  ## Returns
  A span context map that must be passed to `end_fractal_span/2`.
  """
  @spec start_fractal_span(atom(), atom(), fractal_level()) :: span_context()
  def start_fractal_span(module, function, level) do
    span_name = build_span_name(module, function)

    # Get current trace context
    parent_ctx = get_current_trace_context()

    # Generate HLC timestamp for L3+
    hlc = if level in [:l3, :l4, :l5], do: HLC.now(), else: nil

    # Build span attributes
    attributes = build_span_attributes(module, function, level, hlc)

    # Try to create OTel span if available
    span_ctx = try_create_otel_span(span_name, attributes, parent_ctx)

    # Set baggage for downstream propagation
    set_fractal_baggage(module, function, level, span_ctx)

    %{
      span_name: span_name,
      span_ctx: span_ctx,
      parent_ctx: parent_ctx,
      level: level,
      module: module,
      function: function,
      hlc: hlc,
      start_time: System.monotonic_time(:microsecond)
    }
  end

  @doc """
  End a fractal span with a result status.

  ## Parameters
  - `span_context` - The context returned from `start_fractal_span/3`
  - `result` - Either `:ok` or `{:error, exception}`
  """
  @spec end_fractal_span(span_context(), :ok | {:error, term()}) :: :ok
  def end_fractal_span(nil, _result), do: :ok

  def end_fractal_span(span_context, result) do
    duration = System.monotonic_time(:microsecond) - span_context.start_time

    # Set duration attribute
    set_span_attribute("fractal.duration_us", duration)

    case result do
      :ok ->
        set_span_status(:ok)

      {:error, exception} ->
        set_span_status(:error, Exception.message(exception))
        record_span_exception(exception)
    end

    # Try to end OTel span
    try_end_otel_span(span_context.span_ctx)

    # Clear fractal baggage
    clear_fractal_baggage()

    :ok
  end

  # ============================================================
  # BAGGAGE MANAGEMENT
  # ============================================================

  @doc """
  Get all fractal baggage from the current context.

  ## Returns
  A map of fractal-related baggage entries.
  """
  @spec get_fractal_baggage() :: map()
  def get_fractal_baggage do
    # First try OTel baggage API
    otel_baggage = try_get_otel_baggage()

    # Merge with process dictionary fallback
    process_baggage = get_process_baggage()

    Map.merge(process_baggage, otel_baggage)
  end

  @doc """
  Get a specific fractal baggage value.
  """
  @spec get_fractal_baggage(atom()) :: String.t() | nil
  def get_fractal_baggage(key) when is_atom(key) do
    baggage = get_fractal_baggage()
    Map.get(baggage, to_string(key)) || Map.get(baggage, key)
  end

  @doc """
  Set fractal baggage for the current context.

  Propagates through both OTel baggage and process dictionary.
  """
  @spec set_fractal_baggage(atom(), atom(), fractal_level(), span_context()) :: :ok
  def set_fractal_baggage(module, function, level, span_ctx) do
    level_str = Map.get(@level_to_string, level, "L4")
    module_str = String.replace(to_string(module), "Elixir.", "")
    function_str = to_string(function)

    # Build key expression for SC-LOG-009 compliance
    key_expr = "Indrajaal/#{module_str}/#{function_str}"

    baggage = %{
      @baggage_keys.level => level_str,
      @baggage_keys.module => module_str,
      @baggage_keys.function => function_str,
      # SC-LOG-009: Key alias pre-registration headers
      @baggage_keys.expr => key_expr,
      @baggage_keys.depth => level_str,
      @baggage_keys.filter => "enabled"
    }

    # Add trace ID if available
    baggage =
      case get_trace_id(span_ctx) do
        nil -> baggage
        trace_id -> Map.put(baggage, @baggage_keys.trace_id, trace_id)
      end

    # Add active boost if any
    baggage =
      case get_active_boost_id() do
        nil -> baggage
        boost_id -> Map.put(baggage, @baggage_keys.boost, boost_id)
      end

    # Set in OTel baggage
    try_set_otel_baggage(baggage)

    # Also set in process dictionary as fallback
    set_process_baggage(baggage)

    :ok
  end

  @doc """
  Clear all fractal baggage from the current context.
  """
  @spec clear_fractal_baggage() :: :ok
  def clear_fractal_baggage do
    # Clear OTel baggage
    Enum.each(Map.values(@baggage_keys), &try_remove_otel_baggage/1)

    # Clear process dictionary
    clear_process_baggage()

    :ok
  end

  @doc """
  Propagate fractal baggage to HTTP headers.

  Used for cross-service trace correlation.
  """
  @spec inject_baggage_headers(list()) :: list()
  def inject_baggage_headers(headers) when is_list(headers) do
    baggage = get_fractal_baggage()

    baggage_headers =
      Enum.map(baggage, fn {key, value} ->
        {to_string(key), to_string(value)}
      end)

    headers ++ baggage_headers
  end

  @doc """
  Extract fractal baggage from HTTP headers.

  Used when receiving requests with fractal trace context.
  """
  @spec extract_baggage_headers(list() | map()) :: map()
  def extract_baggage_headers(headers) when is_list(headers) do
    headers
    |> Enum.filter(fn {key, _value} ->
      String.starts_with?(to_string(key), @fractal_baggage_prefix)
    end)
    |> Enum.into(%{})
  end

  def extract_baggage_headers(headers) when is_map(headers) do
    headers
    |> Enum.filter(fn {key, _value} ->
      String.starts_with?(to_string(key), @fractal_baggage_prefix)
    end)
    |> Enum.into(%{})
  end

  # ============================================================
  # TRACE CORRELATION (SC-LOG-004)
  # ============================================================

  @doc """
  Get the current L3 TraceID for correlation.

  L1 and L2 logs MUST link to an L3 TraceID for proper correlation.
  """
  @spec get_l3_trace_id() :: String.t() | nil
  def get_l3_trace_id do
    # Try OTel trace ID first
    case try_get_otel_trace_id() do
      nil ->
        # Fallback to fractal baggage, then direct process dict
        case get_fractal_baggage(:trace_id) do
          nil -> Process.get(:fractal_trace_id)
          trace_id -> trace_id
        end

      trace_id ->
        trace_id
    end
  end

  @doc """
  Link a lower-level log entry to an L3 trace.

  This ensures SC-LOG-004 compliance by correlating L1/L2 logs
  with their parent L3 transaction.
  """
  @spec link_to_l3_trace(map()) :: map()
  def link_to_l3_trace(log_entry) do
    case get_l3_trace_id() do
      nil ->
        log_entry

      trace_id ->
        Map.merge(log_entry, %{
          l3_trace_id: trace_id,
          trace_correlation: true
        })
    end
  end

  # ============================================================
  # PRIVATE: SPAN HELPERS
  # ============================================================

  defp build_span_name(module, function) do
    module_str = String.replace(to_string(module), "Elixir.", "")
    "fractal:#{module_str}.#{function}"
  end

  defp build_span_attributes(module, function, level, hlc) do
    base_attrs = %{
      "fractal.level" => Map.get(@level_to_string, level, "L4"),
      "fractal.module" => String.replace(to_string(module), "Elixir.", ""),
      "fractal.function" => to_string(function),
      "fractal.enabled" => true
    }

    # Add HLC for L3+
    if hlc do
      Map.merge(base_attrs, %{
        "fractal.hlc.physical" => hlc.physical,
        "fractal.hlc.counter" => hlc.counter,
        "fractal.hlc.node_id" => hlc.node_id
      })
    else
      base_attrs
    end
  end

  defp get_current_trace_context do
    # Try to get current OTel context
    try_get_otel_context()
  end

  defp get_trace_id(span_ctx) do
    # Try to extract trace ID from span context
    case span_ctx do
      %{trace_id: trace_id} when is_binary(trace_id) -> trace_id
      _ -> Process.get(:fractal_trace_id)
    end
  end

  defp get_active_boost_id do
    case FractalControl.get_active_boosts() do
      [boost | _] -> boost.id
      [] -> nil
    end
  end

  # ============================================================
  # PRIVATE: OTEL API WRAPPERS
  # ============================================================

  defp try_create_otel_span(span_name, attributes, parent_ctx) do
    if otel_available?() do
      try do
        tracer = :opentelemetry.get_application_tracer(:indrajaal)

        span_opts = %{
          kind: :internal,
          attributes: attributes |> Enum.into([])
        }

        span_opts =
          if parent_ctx do
            Map.put(span_opts, :parent, parent_ctx)
          else
            span_opts
          end

        :otel_tracer.start_span(tracer, span_name, span_opts)
      rescue
        _ -> nil
      catch
        _, _ -> nil
      end
    else
      nil
    end
  end

  defp try_end_otel_span(nil), do: :ok

  defp try_end_otel_span(span_ctx) do
    if otel_available?() do
      try do
        :otel_span.end_span(span_ctx)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp try_get_otel_baggage do
    if otel_available?() do
      try do
        :otel_baggage.get_all()
        |> Enum.filter(fn {key, _value} ->
          String.starts_with?(to_string(key), "fractal")
        end)
        |> Enum.into(%{})
      rescue
        _ -> %{}
      catch
        _, _ -> %{}
      end
    else
      %{}
    end
  end

  defp try_set_otel_baggage(baggage) do
    if otel_available?() do
      try do
        Enum.each(baggage, fn {key, value} ->
          :otel_baggage.set(key, value)
        end)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp try_remove_otel_baggage(key) do
    if otel_available?() do
      try do
        # Use dynamic call to avoid compile-time warning for optional OTEL API
        # otel_baggage doesn't have remove/1, clear the entire baggage if needed
        current = :otel_baggage.get_all()
        filtered = Map.delete(current, key)
        :otel_baggage.set(filtered)
        :ok
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp try_get_otel_context do
    if otel_available?() do
      try do
        :otel_ctx.get_current()
      rescue
        _ -> nil
      catch
        _, _ -> nil
      end
    else
      nil
    end
  end

  defp try_get_otel_trace_id do
    if otel_available?() do
      try do
        case :otel_tracer.current_span_ctx() do
          :undefined ->
            nil

          span_ctx ->
            trace_id = :otel_span.trace_id(span_ctx)

            if trace_id do
              to_string(:io_lib.format("~32.16.0b", [trace_id]))
            else
              nil
            end
        end
      rescue
        _ -> nil
      catch
        _, _ -> nil
      end
    else
      nil
    end
  end

  defp set_span_attribute(key, value) do
    if otel_available?() do
      try do
        :otel_span.set_attribute(:otel_tracer.current_span_ctx(), key, value)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp set_span_status(:ok) do
    if otel_available?() do
      try do
        :otel_span.set_status(:otel_tracer.current_span_ctx(), :ok, "")
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp set_span_status(:error, message) do
    if otel_available?() do
      try do
        :otel_span.set_status(:otel_tracer.current_span_ctx(), :error, message)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp record_span_exception(exception) do
    if otel_available?() do
      try do
        # record_exception/5: (SpanCtx, Class, Message, StackTrace, Attributes)
        span_ctx = :otel_tracer.current_span_ctx()
        # Use Process.info to get current stacktrace as fallback
        stack_info = Process.info(self(), :current_stacktrace)
        stacktrace = stack_info |> elem(1)

        :otel_span.record_exception(
          span_ctx,
          :error,
          Exception.message(exception),
          stacktrace,
          []
        )
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp otel_available? do
    Code.ensure_loaded?(:opentelemetry) and Code.ensure_loaded?(:otel_tracer)
  end

  # ============================================================
  # PRIVATE: PROCESS DICTIONARY FALLBACK
  # ============================================================

  defp get_process_baggage do
    Process.get(:fractal_baggage, %{})
  end

  defp set_process_baggage(baggage) do
    existing = Process.get(:fractal_baggage, %{})
    Process.put(:fractal_baggage, Map.merge(existing, baggage))
  end

  defp clear_process_baggage do
    Process.delete(:fractal_baggage)
  end
end
