defmodule Indrajaal.Observability.TraceLogCorrelation do
  @moduledoc """
  Trace-Log Correlation Engine for SigNoz Integration

  ## Agent: Helper Agent 3 - Trace-Log Correlation Implementation (LEAD)
  ## SOPv5.1 Compliance: Maximum parallelization with cybernetic feedback
  ## Multi-Agent Coordination: Implementation following comprehensive TDG test suite

  This module provides comprehensive trace-log correlation capabilities:

  - OpenTelemetry trace __context extraction and propagation
  - Log entry enrichment with trace metadata
  - High-performance correlation algorithms with <1ms overhead
  - STAMP safety constraints enforcement (SC1-SC5)
  - Integration with Phoenix LiveView, Ecto, and background jobs
  - Graceful fallback mechanisms and error recovery
  - PII scrubbing and security filtering
  - Maximum parallelization support for high-throughput scenarios

  ## Usage

      # Extract trace __context from process metadata
      {:ok, __context} = TraceLogCorrelation.extract_trace_context(%{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7"
      })

      # Correlate log entry with trace __context
      log_entry = %{level: :info, message: "User action", metadata: %{}}
      {:ok, correlated_entry} = TraceLogCorrelation.correlate_log_with_trace(log_entry, _context)

  ## STAMP Safety Constraints

  - SC1: Data Integrity - Accurate trace-log correlation with validation
  - SC2: Performance - <1ms correlation overhead with optimized algorithms
  - SC3: Security - PII filtering and sensitive data protection
  - SC4: Availability - Graceful fallbacks when tracing unavailable
  - SC5: Compliance - Complete audit trail of correlation activities
  """

  require Logger

  @sensitive_keys [:password, :api_key, :auth_token, :secret, :private_key, :oauth_token]
  @trace_id_pattern ~r/^[a-f0-9]{32}$/
  @span_id_pattern ~r/^[a-f0-9]{16}$/
  # 1ms maximum correlation overhead
  @max_correlation_time_ms 1

  @doc """
  Extracts OpenTelemetry trace __context from process metadata.

  ## Parameters

  - `metadata` - Process metadata containing trace information

  ## Returns

  - `{:ok, __context}` - Successfully extracted trace __context
  - `{:error, reason}` - Extraction failed with reason

  ## Examples

      # Valid trace __context
      {:ok, __context} = extract_trace_context(%{
        trace_id: "4bf92f3577b34da6a3ce929d0e0e4736",
        span_id: "00f067aa0ba902b7",
        trace_flags: "01"
      })

      # Fallback for missing __context
      {:ok, fallback} = extract_trace_context(%{})
  """
  @spec extract_trace_context(map()) :: {:ok, map()} | {:error, atom()}
  def extract_trace_context(metadata) when is_map(metadata) do
    Logger.debug("🔍 Extracting trace __context from metadata",
      keys: Map.keys(metadata)
    )

    start_time = System.monotonic_time(:microsecond)

    context =
      cond do
        has_valid_trace_context?(metadata) ->
          build_trace_context(metadata)

        has_opentelemetry_context?(metadata) ->
          extract_opentelemetry_context(metadata)

        true ->
          generate_fallback_context(metadata)
      end

    end_time = System.monotonic_time(:microsecond)
    duration_ms = (end_time - start_time) / 1000

    Logger.debug("✅ Trace __context extracted successfully",
      __context_type: context.__context_type,
      duration_ms: duration_ms
    )

    # Log via dual logging for compliance (SC5)
    Indrajaal.Observability.DualLogging.log_domain_event(
      :observability,
      :trace_context_extracted,
      %{
        __context_type: context.__context_type,
        has_trace_id: Map.has_key?(context, :trace_id),
        duration_ms: duration_ms
      },
      :debug
    )

    {:ok, context}
  end

  def extract_trace_context(_invalidmetadata) do
    Logger.warning("⚠️ Invalid metadata provided for trace __context extraction")
    {:error, :invalid_metadata}
  end

  @doc """
  Correlates a log entry with trace context, enriching it with trace metadata.

  ## Parameters

  - `log_entry` - Log entry to be correlated
  - `trace_context` - Trace __context for correlation

  ## Returns

  - `{:ok, correlated_entry}` - Successfully correlated log entry
  - `{:error, reason}` - Correlation failed with reason
  """
  @spec correlate_log_with_trace(map(), map()) :: {:ok, map()} | {:error, atom()}
  def correlate_log_with_trace(log_entry, trace_context)
      when is_map(log_entry) and is_map(trace_context) do
    Logger.debug("🔗 Correlating log entry with trace __context",
      level: log_entry[:level],
      has_trace_id: Map.has_key?(trace_context, :trace_id)
    )

    start_time = System.monotonic_time(:microsecond)

    with {:ok, validated_entry} <- validate_log_entry(log_entry),
         {:ok, validated_context} <- validate_trace_context(trace_context),
         {:ok, enriched_metadata} <- enrich_log_metadata(validated_entry, validated_context),
         {:ok, filtered_metadata} <- filter_sensitive_data(enriched_metadata) do
      end_time = System.monotonic_time(:microsecond)
      duration_ms = (end_time - start_time) / 1000

      correlated_entry = %{
        validated_entry
        | metadata: Map.merge(validated_entry.metadata, filtered_metadata)
      }

      # Performance validation (SC2)
      if duration_ms > @max_correlation_time_ms do
        Logger.warning("⚠️ Correlation exceeded performance target",
          duration_ms: duration_ms,
          target_ms: @max_correlation_time_ms
        )
      end

      Logger.debug("✅ Log-trace correlation completed successfully",
        duration_ms: duration_ms,
        correlation_id: filtered_metadata[:correlation_id]
      )

      # Record correlation metrics
      record_correlation_metrics(duration_ms, :success, trace_context)

      {:ok, correlated_entry}
    else
      {:error, reason} = error ->
        end_time = System.monotonic_time(:microsecond)
        duration_ms = (end_time - start_time) / 1000

        Logger.warning("⚠️ Log-trace correlation failed",
          reason: reason,
          duration_ms: duration_ms
        )

        record_correlation_metrics(duration_ms, :failure, trace_context)
        error
    end
  end

  def correlate_log_with_trace(_invalid_log, _invalidcontext) do
    {:error, :invalid_parameters}
  end

  @doc """
  Injects trace metadata into a log entry for correlation.

  ## Parameters

  - `log_entry` - Log entry to enrich
  - `trace_context` - Trace __context containing metadata

  ## Returns

  - `{:ok, enriched_entry}` - Log entry with injected trace metadata
  - `{:error, reason}` - Injection failed with reason
  """
  @spec inject_trace_metadata(map(), map()) :: {:ok, map()} | {:error, atom()}
  def inject_trace_metadata(log_entry, trace_context)
      when is_map(log_entry) and is_map(trace_context) do
    trace_metadata = %{
      trace_id: trace_context[:trace_id],
      span_id: trace_context[:span_id],
      trace_flags: trace_context[:trace_flags],
      correlation_id: trace_context[:correlation_id] || generate_correlation_id(),
      correlation_timestamp: DateTime.utc_now()
    }

    # Filter out nil values
    filtered_trace_metadata =
      trace_metadata
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    enriched_entry = %{
      log_entry
      | metadata: Map.merge(log_entry.metadata || %{}, filtered_trace_metadata)
    }

    Logger.debug("✅ Trace metadata injected into log entry",
      metadata_keys: Map.keys(filtered_trace_metadata)
    )

    {:ok, enriched_entry}
  end

  def inject_trace_metadata(_invalid_log, _invalidcontext) do
    {:error, :invalid_parameters}
  end

  # Private Functions

  @spec has_valid_trace_context?(map()) :: boolean()
  defp has_valid_trace_context?(metadata) do
    trace_id = metadata[:trace_id]
    span_id = metadata[:span_id]

    is_binary(trace_id) and is_binary(span_id) and
      Regex.match?(@trace_id_pattern, trace_id) and
      Regex.match?(@span_id_pattern, span_id)
  end

  @spec has_opentelemetry_context?(map()) :: boolean()
  defp has_opentelemetry_context?(metadata) do
    # Check for various OpenTelemetry __context keys
    Map.has_key?(metadata, :otel_trace_id) or
      Map.has_key?(metadata, :opentelemetry_trace_id) or
      Map.has_key?(metadata, :"ot-trace-id")
  end

  @spec build_trace_context(map()) :: map()
  defp build_trace_context(metadata) do
    %{
      trace_id: metadata.trace_id,
      span_id: metadata.span_id,
      trace_flags: metadata[:trace_flags] || "01",
      __context_type: :direct,
      correlation_id: generate_correlation_id(),
      extracted_at: DateTime.utc_now()
    }
  end

  @spec extract_opentelemetry_context(map()) :: map()
  defp extract_opentelemetry_context(metadata) do
    trace_id =
      metadata[:otel_trace_id] ||
        metadata[:opentelemetry_trace_id] ||
        metadata[:"ot-trace-id"]

    span_id =
      metadata[:otel_span_id] ||
        metadata[:opentelemetry_span_id] ||
        metadata[:"ot-span-id"]

    %{
      trace_id: trace_id,
      span_id: span_id,
      trace_flags: metadata[:otel_trace_flags] || "01",
      __context_type: :opentelemetry,
      correlation_id: generate_correlation_id(),
      extracted_at: DateTime.utc_now()
    }
  end

  @spec generate_fallback_context(map()) :: map()
  defp generate_fallback_context(_metadata) do
    correlation_id = generate_correlation_id()

    %{
      correlation_id: correlation_id,
      __context_type: :fallback,
      generated_at: DateTime.utc_now(),
      fallback_reason: :no_trace_context
    }
  end

  @spec validate_log_entry(map()) :: {:ok, map()} | {:error, atom()}
  defp validate_log_entry(log_entry) do
    cond do
      not is_atom(log_entry[:level]) ->
        {:error, :invalid_log_level}

      not is_binary(log_entry[:message]) ->
        {:error, :invalid_log_message}

      true ->
        # Ensure metadata exists
        validated = Map.put_new(log_entry, :metadata, %{})
        {:ok, validated}
    end
  end

  @spec validate_trace_context(map()) :: {:ok, map()} | {:error, atom()}
  defp validate_trace_context(trace_context) do
    # All trace __contexts are valid - we handle fallbacks gracefully
    {:ok, trace_context}
  end

  @spec enrich_log_metadata(map(), map()) :: {:ok, map()}
  defp enrich_log_metadata(_log_entry, trace_context) do
    enrichment = %{
      correlation_id: trace_context[:correlation_id] || generate_correlation_id(),
      correlation_timestamp: DateTime.utc_now()
    }

    # Add trace-specific metadata if available
    trace_enrichment =
      case trace_context[:__context_type] do
        :direct ->
          %{
            trace_id: trace_context.trace_id,
            span_id: trace_context.span_id,
            trace_flags: trace_context.trace_flags
          }

        :opentelemetry ->
          %{
            trace_id: trace_context.trace_id,
            span_id: trace_context.span_id,
            otel_context: true
          }

        :fallback ->
          %{fallback_correlation: true}

        _ ->
          %{}
      end

    # Merge enrichments
    final_enrichment = Map.merge(enrichment, trace_enrichment)

    # Add integration-specific metadata
    integration_metadata = extract_integration_metadata(trace_context)
    complete_enrichment = Map.merge(final_enrichment, integration_metadata)

    {:ok, complete_enrichment}
  end

  @spec extract_integration_metadata(map()) :: map()
  defp extract_integration_metadata(trace_context) do
    integration_keys = [
      :phoenix_component,
      :phoenix_action,
      :ecto_repo,
      :ecto_query,
      :job_queue,
      :job_worker
    ]

    trace_context
    |> Map.take(integration_keys)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  @spec filter_sensitive_data(map()) :: {:ok, map()}
  defp filter_sensitive_data(metadata) do
    # SC3: Security - Filter sensitive data
    filtered =
      metadata
      |> Enum.reject(fn {key, _value} ->
        key_string = to_string(key)

        Enum.any?(@sensitive_keys, fn sensitive ->
          String.contains?(String.downcase(key_string), to_string(sensitive))
        end)
      end)
      |> Map.new()

    Logger.debug("🔒 Filtered sensitive data from correlation metadata",
      original_keys: map_size(metadata),
      filtered_keys: map_size(filtered)
    )

    {:ok, filtered}
  end

  defp generate_correlation_id do
    # Generate a unique correlation ID
    timestamp = System.system_time(:nanosecond)
    random_bytes = :crypto.strong_rand_bytes(8)

    "indrajaal_#{timestamp}_#{Base.encode16(random_bytes, case: :lower)}"
  end

  @spec record_correlation_metrics(float(), atom(), map()) :: :ok
  defp record_correlation_metrics(duration_ms, status, trace_context) do
    # Record telemetry metrics for observability
    :telemetry.execute(
      [:indrajaal, :trace_correlation],
      %{
        duration_ms: duration_ms,
        success: if(status == :success, do: 1, else: 0)
      },
      %{
        status: status,
        __context_type: trace_context[:__context_type] || :unknown
      }
    )

    Logger.debug("📊 Correlation metrics recorded",
      duration_ms: duration_ms,
      status: status,
      __context_type: trace_context[:__context_type]
    )

    :ok
  end
end
