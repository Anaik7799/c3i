defmodule Indrajaal.Observability.OtelLogger do
  @moduledoc """
  OpenTelemetry Logger integration for automatic trace correlation.

  This module provides automatic correlation between logs and distributed traces,
  ensuring that all log entries include trace_id and span_id from the current
  OpenTelemetry context. This enables seamless debugging across distributed
  _requests in the SigNoz observability platform.

  ## Features

  - Automatic trace __context injection into log metadata
  - Correlation of logs with distributed traces
  - Support for both synchronous and asynchronous operations
  - Integration with Elixir's Logger and OpenTelemetry

  ## Usage

  The module automatically enhances all Logger calls with trace information
  when an active OpenTelemetry span is present:

      Logger.info("Processing _request", user_id: user.id)
      # Automatically includes trace_id and span_id in metadata

  ## STAMP Safety Constraints

  - SC1: Pr_event trace __context loss during async operations
  - SC2: Ensure tenant isolation in multi-tenant logs
  - SC3: Graceful degradation when OpenTelemetry is unavailable
  """

  require Logger

  @doc """
  Defines a macro that other modules can use to get otel-aware logging.
  """
  defmacro __using__(_opts) do
    quote do
      require Logger
      import Indrajaal.Observability.OtelLogger
    end
  end

  @doc """
  Logs a message with automatic OpenTelemetry trace __context injection.

  ## Parameters

  - `level` - Log level (:debug, :info, :warning, :error)
  - `message` - Log message (string or function returning string)
  - `metadata` - Additional metadata (keyword list)

  ## Examples

      otel_log(:info, "Processing _request")
      otel_log(:error, "Failed to process", error: :timeout, retry: 3)
      otel_log(:debug, fn -> "Expensive debug: \#{inspect(data)}" end)
  """
  defmacro otel_log(level, message, metadata \\ []) do
    quote do
      require OpenTelemetry.Tracer

      # Get current trace __context
      ctx = :otel_tracer.current_span_ctx()

      # Extract trace information
      trace_metadata =
        case ctx do
          :undefined ->
            []

          _ ->
            trace_id = format_trace_id(ctx)
            span_id = format_span_id(ctx)

            if trace_id && span_id do
              [trace_id: trace_id, span_id: span_id]
            else
              []
            end
        end

      # Merge with existing metadata and ensure tenant isolation
      merged_metadata =
        unquote(metadata)
        |> Keyword.merge(trace_metadata)
        |> Keyword.merge(Logger.metadata())
        |> ensure_tenant_metadata()

      # Log with enhanced metadata
      case unquote(level) do
        :debug -> Logger.debug(unquote(message), merged_metadata)
        :info -> Logger.info(unquote(message), merged_metadata)
        :warning -> Logger.warning(unquote(message), merged_metadata)
        :warn -> Logger.warning(unquote(message), merged_metadata)
        :error -> Logger.error(unquote(message), merged_metadata)
        _ -> Logger.info(unquote(message), merged_metadata)
      end
    end
  end

  @doc """
  Creates a correlated child span and logs the operation.

  This function creates a new span that is properly correlated with the
  parent span and logs both the start and completion of the operation.

  ## Examples

      with_otel_span "database.query" do
        # Your database query here
        Repo.all(MySchema)
      end

      with_otel_span "external.api.call", %{service: "payment"} do
        PaymentAPI.charge(amount)
      end
  """
  defmacro with_otel_span(name, attributes \\ %{}, do: block) do
    quote do
      require OpenTelemetry.Tracer
      alias Indrajaal.Observability.OtelLogger

      # Log span start
      OtelLogger.otel_log(:debug, "Starting span: #{unquote(name)}")

      # Execute within span
      # Agent: Worker-2 (SOPv5.1 OpenTelemetry Fix)
      # Pattern: Converting function form to macro block form
      OpenTelemetry.Tracer.with_span unquote(name), %{attributes: unquote(attributes)} do
        try do
          result = unquote(block)
          OtelLogger.otel_log(:debug, "Completed span: #{unquote(name)}")
          result
        rescue
          error ->
            OtelLogger.otel_log(:error, "Failed span: #{unquote(name)}",
              error: Exception.message(error),
              error_type: error.__struct__
            )

            reraise error, __STACKTRACE__
        end
      end
    end
  end

  @doc """
  Ensures tenant metadata is present for multi-tenant isolation.
  """
  def ensure_tenant_metadata(metadata) do
    if Keyword.has_key?(metadata, :tenant_id) do
      metadata
    else
      # Try to get from Logger metadata or default
      tenant_id = Logger.metadata()[:tenant_id] || "default"
      Keyword.put(metadata, :tenant_id, tenant_id)
    end
  end

  @doc """
  Formats log output for different environments with trace context.

  ## Examples

      format_with_trace(:info, "User logged in",
        trace_id: "abc123", span_id: "def456", user_id: 42)
      # => "[abc123:def456] User logged in user_id=42"
  """
  def format_with_trace(_level, message, metadata) do
    trace_part =
      case {metadata[:trace_id], metadata[:span_id]} do
        {nil, nil} -> ""
        {trace_id, nil} -> "[#{trace_id}] "
        {nil, span_id} -> "[:#{span_id}] "
        {trace_id, span_id} -> "[#{trace_id}:#{span_id}] "
      end

    meta_string =
      metadata
      |> Keyword.drop([:trace_id, :span_id])
      |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{inspect(v)}" end)

    "#{trace_part}#{message} #{meta_string}" |> String.trim()
  end

  @doc """
  Asynchronously logs with trace __context propagation.

  This ensures trace __context is maintained even in async operations
  like Task.async or GenServer calls.

  ## Examples

      async_otel_log(fn ->
        # This will maintain trace __context
        otel_log(:info, "Async operation completed")
      end)
  """
  def async_otel_log(fun) when is_function(fun, 0) do
    # Capture current trace __context
    current_ctx = :otel_tracer.current_span_ctx()

    Task.async(fn ->
      # Restore trace __context in async process
      if current_ctx != :undefined do
        if Code.ensure_loaded?(OpenTelemetry) do
          OpenTelemetry.Tracer.set_current_span(current_ctx)
        end
      end

      fun.()
    end)
  end

  @doc """
  Enriches log metadata with standard observability fields.

  Adds fields like correlation_id, _request_id, and other standard
  observability metadata to improve log correlation and searching.
  """
  def enrich_metadata(metadata) do
    enriched = metadata

    # Add correlation ID if not present
    enriched =
      if Keyword.has_key?(enriched, :correlation_id) do
        enriched
      else
        correlation_id = generate_correlation_id(:logging, :event)
        Keyword.put(enriched, :correlation_id, correlation_id)
      end

    # Add timestamp
    enriched = Keyword.put(enriched, :timestamp, DateTime.utc_now())

    # Add service metadata
    enriched
    |> Keyword.put_new(:service, "intelitor")
    |> Keyword.put_new(:environment, Application.get_env(:indrajaal, :environment, :dev))
  end

  @doc """
  Logger backend behavior for OpenTelemetry integration.

  This backend automatically injects trace __context into all log messages.
  """
  def init(_opts) do
    {:ok, %{}}
  end

  def handle_event({level, _gl, {Logger, msg, _ts, metadata}}, state) do
    # Get current trace __context
    ctx = :otel_tracer.current_span_ctx()

    # Enhance metadata with trace __context
    enhanced_metadata =
      case ctx do
        :undefined ->
          metadata

        _ ->
          trace_id = format_trace_id(ctx)
          span_id = format_span_id(ctx)

          metadata
          |> Keyword.put_new(:trace_id, trace_id)
          |> Keyword.put_new(:span_id, span_id)
      end

    # Forward to console backend with enhanced metadata
    :logger.log(level, msg, enhanced_metadata)

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  def codechange(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  # Helper functions

  defp format_trace_id(ctx) do
    ctx
    |> :otel_span.trace_id()
    |> Base.encode16(case: :lower)
  rescue
    _ -> nil
  end

  defp format_span_id(ctx) do
    ctx
    |> :otel_span.span_id()
    |> Base.encode16(case: :lower)
  rescue
    _ -> nil
  end

  defp generate_correlation_id(domain, event) do
    "#{domain}_#{event}_#{System.unique_integer([:positive])}"
  end
end
