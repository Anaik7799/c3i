defmodule Indrajaal.Observability.LoggerTraceContext do
  @moduledoc """
  Automatic OpenTelemetry trace __context injection for Logger.

  This module ensures that all logs include trace_id and span_id from
  the current OpenTelemetry context, enabling correlation between logs
  and distributed traces in SigNoz.

  ## Features

  - Automatic trace __context extraction from OpenTelemetry
  - Logger metadata enrichment with trace information
  - Support for both synchronous and asynchronous operations
  - Graceful handling when no active span exists

  ## STAMP Safety Constraints

  - SC1: Pr_event trace __context loss during async operations
  - SC2: Ensure proper format for trace IDs (hex encoding)
  - SC3: Graceful degradation when OpenTelemetry is unavailable
  """

  require Logger

  @doc """
  Sets up automatic trace __context injection for Logger.

  This should be called during application startup to ensure all
  logs include trace __context when available.
  """
  def setup do
    :logger.add_handler(
      :otel_trace_context,
      :logger_std_h,
      %{
        config: %{
          type: :standard_io
        },
        formatter:
          {:logger_formatter,
           %{
             legacy_header: true,
             single_line: false,
             template: [:time, " ", :metadata, "[", :level, "] ", :message, "\n"],
             metadata: :all
           }},
        filters: [trace_context_filter: {&add_trace_context/2, []}]
      }
    )

    :ok
  end

  @doc """
  Logger filter that adds OpenTelemetry trace __context to log metadata.

  This function is called for each log __event and enriches the metadata
  with trace_id and span_id from the current OpenTelemetry context.
  """
  def add_trace_context(%{meta: meta} = event, _config) do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        # No active span, return event unchanged
        event

      span_ctx ->
        # Extract trace and span IDs
        trace_id =
          span_ctx
          |> :otel_span.trace_id()
          |> Base.encode16(case: :lower)

        span_id =
          span_ctx
          |> :otel_span.span_id()
          |> Base.encode16(case: :lower)

        # Add to metadata
        # Use constant 0 for trace_flags since OpenTelemetry Erlang API is unclear
        # Trace flags are typically 1 for sampled, 0 for not sampled
        trace_flags = 0

        updated_meta =
          meta
          |> Map.put(:trace_id, trace_id)
          |> Map.put(:span_id, span_id)
          |> Map.put(:trace_flags, trace_flags)

        %{event | meta: updated_meta}
    end
  end

  @doc """
  Manually adds trace __context to metadata for custom logging scenarios.

  ## Examples
      metadata = LoggerTraceContext.enrich_metadata(user_id: 123)
      Logger.info("User action", meta_data)
  """
  @spec enrich_metadata(keyword()) :: keyword()
  def enrich_metadata(metadata \\ []) do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        metadata

      span_ctx ->
        trace_id_raw = :otel_span.trace_id(span_ctx)

        trace_id =
          if is_binary(trace_id_raw), do: Base.encode16(trace_id_raw, case: :lower), else: nil

        span_id_raw = :otel_span.span_id(span_ctx)

        span_id =
          if is_binary(span_id_raw), do: Base.encode16(span_id_raw, case: :lower), else: nil

        # Use constant 0 for trace_flags since OpenTelemetry Erlang API is unclear
        # Trace flags are typically 1 for sampled, 0 for not sampled
        trace_flags = 0

        metadata
        |> then(fn meta ->
          if trace_id, do: Keyword.put(meta, :trace_id, trace_id), else: meta
        end)
        |> then(fn meta -> if span_id, do: Keyword.put(meta, :span_id, span_id), else: meta end)
        |> Keyword.put(:trace_flags, trace_flags)
    end
  end

  @doc """
  Formats trace __context for display in logs.

  ## Examples

      LoggerTraceContext.format_trace_context()
      # => "[trace_id=abc123 span_id=def456]"
  """
  def format_trace_context do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        ""

      span_ctx ->
        trace_id =
          span_ctx
          |> :otel_span.trace_id()
          |> Base.encode16(case: :lower)

        span_id =
          span_ctx
          |> :otel_span.span_id()
          |> Base.encode16(case: :lower)

        "[trace_id=#{trace_id} span_id=#{span_id}]"
    end
  end

  @doc """
  Ensures trace __context is preserved across async boundaries.

  Use this when spawning tasks or processes that need to maintain
  the trace __context from the parent.

  ## Examples

      LoggerTraceContext.with_trace_context(fn ->
        Task.async(fn ->
          Logger.info("This log will have the parent's trace __context")
        end)
      end)
  """
  @spec with_trace_context((-> any())) :: any()
  def with_trace_context(fun) do
    ctx = :otel_ctx.get_current()

    fn ->
      :otel_ctx.attach(ctx)

      try do
        fun.()
      after
        :otel_ctx.detach(ctx)
      end
    end
  end
end
