defmodule Indrajaal.Cluster.Zenoh.TracePropagator do
  @moduledoc """
  OTEL trace context propagation for Zenoh messages.

  Enables distributed tracing across Zenoh pub/sub by injecting and
  extracting W3C Trace Context headers in messages.

  ## STAMP Constraints

  - SC-ZENOH-TRACE-001: Trace context in all cross-node messages
  - SC-ZENOH-TRACE-002: W3C Trace Context format
  - SC-OBS-069: Dual logging integration

  ## W3C Trace Context Format

  The traceparent header format:
  ```
  version-trace_id-span_id-trace_flags
  00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
  ```

  ## Usage

      # Inject trace context before publishing
      message = %{type: :alarm, alarm_id: "123"}
      traced_message = TracePropagator.inject(message)
      ZenohMesh.publish(key, traced_message)

      # Extract trace context when receiving
      {:ok, context} = TracePropagator.extract(message)
      TracePropagator.create_child_span(context, "process_alarm")

  """

  require Logger

  @type trace_context :: %{
          trace_id: String.t(),
          span_id: String.t(),
          parent_span_id: String.t() | nil,
          trace_flags: String.t(),
          traceparent: String.t()
        }

  @supported_version "00"
  @default_trace_flags "01"

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Injects trace context into a message for cross-node propagation.

  ## Examples

      iex> TracePropagator.inject(%{type: :event, data: "test"})
      %{type: :event, data: "test", _trace_context: %{...}}

  """
  @spec inject(term()) :: map()
  def inject(message) when is_map(message) do
    context = current_or_new_context()
    Map.put(message, :_trace_context, context)
  end

  def inject(message) when is_binary(message) do
    context = current_or_new_context()
    %{payload: message, _trace_context: context}
  end

  def inject(message) do
    context = current_or_new_context()
    %{payload: message, _trace_context: context}
  end

  @doc """
  Extracts trace context from a received message.

  ## Examples

      iex> TracePropagator.extract(%{data: "test", _trace_context: %{...}})
      {:ok, %{trace_id: "...", span_id: "..."}}

  """
  @spec extract(map()) :: {:ok, trace_context()} | {:error, atom()}
  def extract(message) when is_map(message) do
    case Map.get(message, :_trace_context) do
      nil ->
        {:error, :no_trace_context}

      context when is_map(context) ->
        if valid_context?(context) do
          {:ok, context}
        else
          {:error, :invalid_trace_context}
        end

      _ ->
        {:error, :invalid_trace_context}
    end
  end

  def extract(_), do: {:error, :no_trace_context}

  @doc """
  Creates a child span from a parent context.

  ## Examples

      iex> TracePropagator.create_child_span(parent_context, "child_operation")
      %{trace_id: "...", span_id: "...", parent_span_id: "...", operation: "child_operation"}

  """
  @spec create_child_span(trace_context(), String.t()) :: trace_context()
  def create_child_span(parent_context, operation) do
    child_span_id = generate_span_id()

    %{
      trace_id: parent_context.trace_id,
      span_id: child_span_id,
      parent_span_id: parent_context.span_id,
      trace_flags: Map.get(parent_context, :trace_flags, @default_trace_flags),
      operation: operation,
      traceparent:
        format_traceparent(%{
          trace_id: parent_context.trace_id,
          span_id: child_span_id,
          trace_flags: Map.get(parent_context, :trace_flags, @default_trace_flags)
        })
    }
  end

  @doc """
  Formats a trace context into W3C traceparent header format.

  ## Examples

      iex> TracePropagator.format_traceparent(%{trace_id: "abc", span_id: "def"})
      "00-abc-def-01"

  """
  @spec format_traceparent(map()) :: String.t()
  def format_traceparent(context) do
    trace_id = Map.fetch!(context, :trace_id)
    span_id = Map.fetch!(context, :span_id)
    trace_flags = Map.get(context, :trace_flags, @default_trace_flags)

    "#{@supported_version}-#{trace_id}-#{span_id}-#{trace_flags}"
  end

  @doc """
  Parses a W3C traceparent header into a trace context.

  ## Examples

      iex> TracePropagator.parse_traceparent("00-abc123-def456-01")
      {:ok, %{version: "00", trace_id: "abc123", span_id: "def456", trace_flags: "01"}}

  """
  @spec parse_traceparent(String.t()) :: {:ok, map()} | {:error, atom()}
  def parse_traceparent(traceparent) when is_binary(traceparent) do
    case String.split(traceparent, "-") do
      [version, trace_id, span_id, trace_flags] when version == @supported_version ->
        {:ok,
         %{
           version: version,
           trace_id: trace_id,
           span_id: span_id,
           trace_flags: trace_flags
         }}

      [version, _trace_id, _span_id, _trace_flags] when version != @supported_version ->
        {:error, :unsupported_version}

      _ ->
        {:error, :invalid_traceparent}
    end
  end

  @doc """
  Generates a new trace ID (32-character hex string).
  """
  @spec generate_trace_id() :: String.t()
  def generate_trace_id do
    bytes = :crypto.strong_rand_bytes(16)
    bytes |> Base.encode16(case: :lower)
  end

  @doc """
  Generates a new span ID (16-character hex string).
  """
  @spec generate_span_id() :: String.t()
  def generate_span_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  @doc """
  Executes a function within a new span context.

  Creates a new span, executes the function with the context,
  and returns the function's result.

  ## Examples

      TracePropagator.with_span("process_message", fn context ->
        # context contains trace_id, span_id, etc.
        process(message, context)
      end)

  """
  @spec with_span(String.t(), (trace_context() -> term())) :: term()
  def with_span(operation, fun) when is_function(fun, 1) do
    context = new_context()
    context_with_op = Map.put(context, :operation, operation)

    Logger.debug("[TracePropagator] Starting span: #{operation}, trace_id: #{context.trace_id}")

    result = fun.(context_with_op)

    Logger.debug("[TracePropagator] Completed span: #{operation}")

    result
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp current_or_new_context do
    # Try to get current OTEL context, fall back to new context
    case get_current_otel_context() do
      nil -> new_context()
      context -> context
    end
  end

  defp new_context do
    trace_id = generate_trace_id()
    span_id = generate_span_id()

    %{
      trace_id: trace_id,
      span_id: span_id,
      parent_span_id: nil,
      trace_flags: @default_trace_flags,
      traceparent: "#{@supported_version}-#{trace_id}-#{span_id}-#{@default_trace_flags}"
    }
  end

  defp get_current_otel_context do
    # Try to extract from OTEL if available
    # This integrates with the existing OTEL infrastructure
    try do
      case :otel_tracer.current_span_ctx() do
        :undefined ->
          nil

        span_ctx when is_tuple(span_ctx) ->
          # Extract trace_id and span_id from OTEL span context
          trace_id = extract_trace_id_from_otel(span_ctx)
          span_id = extract_span_id_from_otel(span_ctx)

          if trace_id && span_id do
            %{
              trace_id: trace_id,
              span_id: span_id,
              parent_span_id: nil,
              trace_flags: @default_trace_flags,
              traceparent: "#{@supported_version}-#{trace_id}-#{span_id}-#{@default_trace_flags}"
            }
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

  defp extract_trace_id_from_otel(span_ctx) do
    try do
      # OTEL span context is a tuple with trace_id as first element
      trace_id = elem(span_ctx, 0)

      if is_integer(trace_id) do
        trace_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(32, "0")
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  defp extract_span_id_from_otel(span_ctx) do
    try do
      # OTEL span context has span_id as second element
      span_id = elem(span_ctx, 1)

      if is_integer(span_id) do
        span_id
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(16, "0")
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  defp valid_context?(context) do
    Map.has_key?(context, :trace_id) && Map.has_key?(context, :span_id)
  end
end
