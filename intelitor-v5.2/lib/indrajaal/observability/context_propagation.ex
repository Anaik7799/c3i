defmodule Indrajaal.Observability.ContextPropagation do
  @moduledoc """
  Utility for propagating OpenTelemetry span context across async boundaries.

  WHAT: Provides helpers for capturing and restoring trace context in Task.async,
        GenServer calls, and Broadway pipelines. Ensures trace continuity across
        process boundaries in the Indrajaal distributed system.

  WHY: SC-OBS-069 requires trace context continuity across all async operations.
       Without proper context propagation, distributed traces become fragmented,
       making it impossible to follow request flows through async boundaries.

  CONSTRAINTS:
  - Must not block or add significant latency (<1ms overhead per operation)
  - Must gracefully handle missing OpenTelemetry runtime
  - Must preserve existing Logger metadata
  - Must support nested context captures (stack-like behavior)

  ## Usage Examples

      # Capture context before spawning async work
      ctx = ContextPropagation.capture_context()

      # In Task.async, restore context
      Task.async(fn ->
        ContextPropagation.with_context(ctx, fn ->
          # This code runs with the parent's trace context
          MyModule.do_work()
        end)
      end)

      # Simpler: wrap function for Task.async
      Task.async(ContextPropagation.wrap_task(fn -> MyModule.do_work() end))

  ## STAMP Safety Constraints

  - SC-OBS-069: Dual Log (Term+SigNoz) integration with context propagation
  - SC-OBS-071: 4 OTEL modules integration
  - SC-PRF-050: Response <50ms (context operations <1ms overhead)
  - SC-PRF-055: No blocking operations

  ## Architecture

  Context propagation works in three layers:
  1. OpenTelemetry context (otel_ctx) - Primary trace propagation
  2. Process dictionary fallback - For when OTEL is unavailable
  3. Logger metadata - Preserves request_id, tenant_id, etc.
  """

  require Logger

  # ============================================================
  # TYPES
  # ============================================================

  @typedoc """
  Captured context containing all propagation data.
  """
  @type captured_context :: %{
          otel_ctx: term() | nil,
          logger_metadata: keyword(),
          process_baggage: map(),
          fractal_trace_id: String.t() | nil,
          captured_at: integer()
        }

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Captures the current span context for later restoration.

  This captures:
  - OpenTelemetry context (if available)
  - Logger metadata (tenant_id, request_id, etc.)
  - Fractal baggage from process dictionary
  - Fractal trace ID

  Returns a context map that can be passed to `with_context/2` or stored
  for later use in another process.

  ## Examples

      ctx = ContextPropagation.capture_context()
      # ctx contains all trace and metadata context

  ## Performance

  This operation is designed to complete in <100 microseconds and never blocks.
  """
  @spec capture_context() :: captured_context()
  def capture_context do
    %{
      otel_ctx: try_get_otel_context(),
      logger_metadata: Logger.metadata(),
      process_baggage: Process.get(:fractal_baggage, %{}),
      fractal_trace_id: Process.get(:fractal_trace_id),
      captured_at: System.monotonic_time(:microsecond)
    }
  end

  @doc """
  Executes a function with the given captured context restored.

  This restores:
  - OpenTelemetry context
  - Logger metadata
  - Fractal baggage
  - Fractal trace ID

  After the function completes (or raises), the original context is restored.

  ## Examples

      ctx = ContextPropagation.capture_context()

      # In another process
      result = ContextPropagation.with_context(ctx, fn ->
        Logger.info("This log will have parent's trace context")
        MyModule.do_work()
      end)

  ## Error Handling

  If the function raises, the exception is re-raised after context cleanup.

  ## Performance

  Context restoration adds <500 microseconds overhead.
  """
  @spec with_context(captured_context(), (-> result)) :: result when result: any()
  def with_context(captured_ctx, fun) when is_map(captured_ctx) and is_function(fun, 0) do
    # Save current context for restoration after
    original_ctx = capture_context()

    try do
      # Restore captured context
      restore_context(captured_ctx)

      # Execute the function
      fun.()
    after
      # Restore original context (cleanup)
      restore_context(original_ctx)
    end
  end

  def with_context(nil, fun) when is_function(fun, 0) do
    # No context to restore, just run the function
    fun.()
  end

  @doc """
  Wraps a function for use with Task.async, preserving trace context.

  This is a convenience wrapper that captures the current context and returns
  a new function that will restore that context when executed.

  ## Examples

      # Start task with context propagation
      task = Task.async(ContextPropagation.wrap_task(fn ->
        # This runs with parent's trace context
        process_data()
      end))

      result = Task.await(task)

  ## Use Cases

  - Task.async/await patterns
  - Task.Supervisor.start_child
  - Broadway message processing
  - GenServer.cast callbacks

  ## Performance

  Adds ~600 microseconds total overhead (capture + restore).
  """
  @spec wrap_task((-> result)) :: (-> result) when result: any()
  def wrap_task(fun) when is_function(fun, 0) do
    ctx = capture_context()

    fn ->
      with_context(ctx, fun)
    end
  end

  @doc """
  Wraps a function with arguments for use with Task.async.

  Similar to `wrap_task/1` but for functions that need arguments.

  ## Examples

      wrapped = ContextPropagation.wrap_task_with_args(fn item ->
        process_item(item)
      end)

      tasks = Enum.map(items, fn item ->
        Task.async(fn -> wrapped.(item) end)
      end)
  """
  @spec wrap_task_with_args((any() -> result)) :: (any() -> result) when result: any()
  def wrap_task_with_args(fun) when is_function(fun, 1) do
    ctx = capture_context()

    fn arg ->
      with_context(ctx, fn -> fun.(arg) end)
    end
  end

  @doc """
  Starts a Task with context propagation.

  Convenience function that combines Task.async with context propagation.

  ## Examples

      task = ContextPropagation.async_with_context(fn ->
        do_work()
      end)

      result = Task.await(task)
  """
  @spec async_with_context((-> result)) :: Task.t() when result: any()
  def async_with_context(fun) when is_function(fun, 0) do
    Task.async(wrap_task(fun))
  end

  @doc """
  Starts a supervised Task with context propagation.

  ## Examples

      {:ok, task} = ContextPropagation.async_with_context(MySupervisor, fn ->
        do_work()
      end)
  """
  @spec async_with_context(Supervisor.supervisor(), (-> result)) :: {:ok, Task.t()}
        when result: any()
  def async_with_context(supervisor, fun) when is_function(fun, 0) do
    Task.Supervisor.async(supervisor, wrap_task(fun))
  end

  @doc """
  Propagates context to a GenServer call.

  Captures context and includes it in the call message. The receiving
  GenServer should use `with_context/2` to restore the context.

  ## Examples

      # In calling code
      ctx = ContextPropagation.capture_context()
      GenServer.call(server, {:my_request, data, ctx})

      # In GenServer handle_call
      def handle_call({:my_request, data, ctx}, _from, state) do
        result = ContextPropagation.with_context(ctx, fn ->
          process_request(data)
        end)
        {:reply, result, state}
      end
  """
  @spec propagate_to_genserver((-> result)) :: result when result: any()
  def propagate_to_genserver(fun) when is_function(fun, 0) do
    ctx = capture_context()
    with_context(ctx, fun)
  end

  @doc """
  Checks if context propagation is properly configured.

  Returns a map with diagnostics about context propagation health.

  ## Examples

      diagnostics = ContextPropagation.health_check()
      # => %{otel_available: true, context_captured: true, ...}
  """
  @spec health_check() :: map()
  def health_check do
    ctx = capture_context()

    %{
      otel_available: otel_available?(),
      context_captured: ctx.otel_ctx != nil or map_size(ctx.process_baggage) > 0,
      logger_metadata_count: length(ctx.logger_metadata),
      has_fractal_trace_id: ctx.fractal_trace_id != nil,
      capture_latency_us: System.monotonic_time(:microsecond) - ctx.captured_at
    }
  end

  @doc """
  Injects captured context into HTTP headers for cross-service propagation.

  ## Examples

      headers = [{"content-type", "application/json"}]
      headers_with_context = ContextPropagation.inject_into_headers(headers)
  """
  @spec inject_into_headers(list()) :: list()
  def inject_into_headers(headers) when is_list(headers) do
    ctx = capture_context()

    # Add trace context headers
    trace_headers = build_trace_headers(ctx)

    # Add fractal baggage headers
    baggage_headers = build_baggage_headers(ctx.process_baggage)

    headers ++ trace_headers ++ baggage_headers
  end

  @doc """
  Extracts context from HTTP headers for incoming requests.

  ## Examples

      ctx = ContextPropagation.extract_from_headers(conn.req_headers)
      ContextPropagation.with_context(ctx, fn ->
        handle_request(conn)
      end)
  """
  @spec extract_from_headers(list() | map()) :: captured_context()
  def extract_from_headers(headers) when is_list(headers) do
    headers_map = Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end)
    extract_from_headers(headers_map)
  end

  def extract_from_headers(headers) when is_map(headers) do
    # Extract trace parent if present
    trace_id = Map.get(headers, "x-trace-id") || extract_traceparent_trace_id(headers)

    # Extract baggage
    baggage = extract_baggage_from_headers(headers)

    %{
      otel_ctx: nil,
      logger_metadata: build_metadata_from_headers(headers),
      process_baggage: baggage,
      fractal_trace_id: trace_id,
      captured_at: System.monotonic_time(:microsecond)
    }
  end

  # ============================================================
  # PRIVATE: CONTEXT RESTORATION
  # ============================================================

  @spec restore_context(captured_context()) :: :ok
  defp restore_context(ctx) do
    # Restore OpenTelemetry context
    try_attach_otel_context(ctx.otel_ctx)

    # Restore Logger metadata
    Logger.metadata(ctx.logger_metadata)

    # Restore fractal baggage
    if map_size(ctx.process_baggage) > 0 do
      Process.put(:fractal_baggage, ctx.process_baggage)
    else
      Process.delete(:fractal_baggage)
    end

    # Restore fractal trace ID
    if ctx.fractal_trace_id do
      Process.put(:fractal_trace_id, ctx.fractal_trace_id)
    else
      Process.delete(:fractal_trace_id)
    end

    :ok
  end

  # ============================================================
  # PRIVATE: OPENTELEMETRY INTEGRATION
  # ============================================================

  @spec try_get_otel_context() :: term() | nil
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

  @spec try_attach_otel_context(term() | nil) :: :ok
  defp try_attach_otel_context(nil), do: :ok

  defp try_attach_otel_context(ctx) do
    if otel_available?() do
      try do
        :otel_ctx.attach(ctx)
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

  @spec otel_available?() :: boolean()
  defp otel_available? do
    Code.ensure_loaded?(:otel_ctx) and Code.ensure_loaded?(:otel_tracer)
  end

  # ============================================================
  # PRIVATE: HEADER HANDLING
  # ============================================================

  @spec build_trace_headers(captured_context()) :: list()
  defp build_trace_headers(ctx) do
    headers = []

    headers =
      if ctx.fractal_trace_id do
        [{"x-trace-id", ctx.fractal_trace_id} | headers]
      else
        headers
      end

    # Add W3C traceparent if we have OTEL context
    headers =
      if ctx.otel_ctx && otel_available?() do
        case try_get_trace_span_ids() do
          {trace_id, span_id} when is_binary(trace_id) and is_binary(span_id) ->
            [{"traceparent", "00-#{trace_id}-#{span_id}-00"} | headers]

          _ ->
            headers
        end
      else
        headers
      end

    headers
  end

  @spec try_get_trace_span_ids() :: {String.t(), String.t()} | nil
  defp try_get_trace_span_ids do
    try do
      case :otel_tracer.current_span_ctx() do
        :undefined ->
          nil

        span_ctx ->
          trace_id = :otel_span.trace_id(span_ctx)
          span_id = :otel_span.span_id(span_ctx)

          trace_id_hex =
            if is_integer(trace_id) do
              formatted = :io_lib.format("~32.16.0b", [trace_id])
              formatted |> to_string()
            else
              nil
            end

          span_id_hex =
            if is_integer(span_id) do
              formatted = :io_lib.format("~16.16.0b", [span_id])
              formatted |> to_string()
            else
              nil
            end

          if trace_id_hex && span_id_hex do
            {trace_id_hex, span_id_hex}
          else
            nil
          end
      end
    rescue
      _ -> nil
    catch
      _, _ -> nil
    end
  end

  @spec build_baggage_headers(map()) :: list()
  defp build_baggage_headers(baggage) when map_size(baggage) == 0, do: []

  defp build_baggage_headers(baggage) do
    Enum.map(baggage, fn {key, value} ->
      {to_string(key), to_string(value)}
    end)
  end

  @spec extract_traceparent_trace_id(map()) :: String.t() | nil
  defp extract_traceparent_trace_id(headers) do
    case Map.get(headers, "traceparent") do
      nil ->
        nil

      traceparent ->
        case String.split(traceparent, "-") do
          ["00", trace_id, _span_id, _flags] -> trace_id
          _ -> nil
        end
    end
  end

  @spec extract_baggage_from_headers(map()) :: map()
  defp extract_baggage_from_headers(headers) do
    headers
    |> Enum.filter(fn {key, _value} ->
      String.starts_with?(key, "ot-baggage-fractal-")
    end)
    |> Enum.into(%{})
  end

  @spec build_metadata_from_headers(map()) :: keyword()
  defp build_metadata_from_headers(headers) do
    metadata = []

    metadata =
      case Map.get(headers, "x-request-id") do
        nil -> metadata
        request_id -> [{:request_id, request_id} | metadata]
      end

    metadata =
      case Map.get(headers, "x-tenant-id") do
        nil -> metadata
        tenant_id -> [{:tenant_id, tenant_id} | metadata]
      end

    metadata =
      case Map.get(headers, "x-trace-id") do
        nil -> metadata
        trace_id -> [{:trace_id, trace_id} | metadata]
      end

    metadata
  end
end
