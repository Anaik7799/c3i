defmodule Indrajaal.Observability.Domains.IntegrationInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Integration domain.

  Provides comprehensive telemetry and tracing for external API requests,
  webhook processing, data synchronization, rate limiting, and retry mechanisms.

  ## Telemetry Events

  External API Events:
  - `[:indrajaal, :integration, :external_api, :request_start]`
  - `[:indrajaal, :integration, :external_api, :request_stop]`
  - `[:indrajaal, :integration, :external_api, :error]`

  Webhook Events:
  - `[:indrajaal, :integration, :webhook, :received]`
  - `[:indrajaal, :integration, :webhook, :processed]`

  Data Sync Events:
  - `[:indrajaal, :integration, :data_sync, :start]`
  - `[:indrajaal, :integration, :data_sync, :stop]`

  Rate Limit Events:
  - `[:indrajaal, :integration, :rate_limit, :exceeded]`
  - `[:indrajaal, :integration, :retry, :attempt]`

  ## Tracing Spans

  - `integration.external_request` (root)
  - `integration.request_preparation`
  - `integration.request_execution`
  - `integration.response_parsing`
  - `integration.error_handling`

  ## STAMP Safety Constraints

  - SC-OBS-065: Logging enabled for ALL key operations
  - SC-OBS-066: OpenTelemetry validation at startup
  - SC-OBS-069: Dual logging (Terminal + SigNoz)
  - SC-OBS-070: Trace context injection
  """

  use Indrajaal.Observability.InstrumentationBase, domain: :integration

  @doc """
  Sets up telemetry handlers for the Integration domain.
  """
  def setup do
    Logger.info("Setting up Integration domain instrumentation")
    attach_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :integration, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :integration}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :integration, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok, [domain: :integration]}
  end

  def shutdown do
    :ok
  end

  @doc """
  Attaches all telemetry handlers for the Integration domain.
  """
  def attach_handlers do
    # External API handlers
    :telemetry.attach_many(
      "integration-external-api",
      [
        [:indrajaal, :integration, :external_api, :request_start],
        [:indrajaal, :integration, :external_api, :request_stop],
        [:indrajaal, :integration, :external_api, :error]
      ],
      &handle_external_api_event/4,
      %{}
    )

    # Webhook handlers
    :telemetry.attach_many(
      "integration-webhook",
      [
        [:indrajaal, :integration, :webhook, :received],
        [:indrajaal, :integration, :webhook, :processed]
      ],
      &handle_webhook_event/4,
      %{}
    )

    # Data sync handlers
    :telemetry.attach_many(
      "integration-data-sync",
      [
        [:indrajaal, :integration, :data_sync, :start],
        [:indrajaal, :integration, :data_sync, :stop]
      ],
      &handle_data_sync_event/4,
      %{}
    )

    # Rate limit handlers
    :telemetry.attach_many(
      "integration-rate-limit",
      [
        [:indrajaal, :integration, :rate_limit, :exceeded],
        [:indrajaal, :integration, :retry, :attempt]
      ],
      &handle_rate_limit_event/4,
      %{}
    )

    Logger.debug("Integration domain telemetry handlers attached")
    :ok
  end

  # =============================================================================
  # External API Instrumentation
  # =============================================================================

  @doc """
  Emits telemetry for external API request start.

  ## Parameters
  - `endpoint` - The external API endpoint URL
  - `method` - HTTP method (GET, POST, etc.)
  - `metadata` - Additional metadata (tenant_id, user_id, etc.)
  """
  def emit_external_api_start(endpoint, method, metadata \\ %{}) do
    measurements = %{
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:endpoint, endpoint)
      |> Map.put(:method, method)
      |> Map.put(:request_id, generate_request_id())

    :telemetry.execute(
      [:indrajaal, :integration, :external_api, :request_start],
      measurements,
      enriched_metadata
    )

    Logger.info("External API request started",
      endpoint: endpoint,
      method: method,
      request_id: enriched_metadata.request_id,
      tenant_id: metadata[:tenant_id]
    )

    enriched_metadata.request_id
  end

  @doc """
  Emits telemetry for external API request completion.

  ## Parameters
  - `request_id` - The request ID from emit_external_api_start
  - `status_code` - HTTP response status code
  - `duration_ms` - Request duration in milliseconds
  - `metadata` - Additional metadata
  """
  def emit_external_api_stop(request_id, status_code, duration_ms, metadata \\ %{}) do
    measurements = %{
      duration: duration_ms,
      status_code: status_code,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:request_id, request_id)
      |> Map.put(:status_code, status_code)
      |> Map.put(:success, status_code >= 200 and status_code < 300)

    :telemetry.execute(
      [:indrajaal, :integration, :external_api, :request_stop],
      measurements,
      enriched_metadata
    )

    Logger.info("External API request completed",
      request_id: request_id,
      status_code: status_code,
      duration_ms: duration_ms,
      success: enriched_metadata.success,
      tenant_id: metadata[:tenant_id]
    )
  end

  @doc """
  Emits telemetry for external API error.

  ## Parameters
  - `request_id` - The request ID from emit_external_api_start
  - `error` - The error that occurred
  - `metadata` - Additional metadata
  """
  def emit_external_api_error(request_id, error, metadata \\ %{}) do
    measurements = %{
      system_time: System.system_time(:millisecond),
      error_count: 1
    }

    enriched_metadata =
      metadata
      |> Map.put(:request_id, request_id)
      |> Map.put(:error, inspect(error))
      |> Map.put(:error_type, error_type(error))

    :telemetry.execute(
      [:indrajaal, :integration, :external_api, :error],
      measurements,
      enriched_metadata
    )

    Logger.error("External API request failed",
      request_id: request_id,
      error: inspect(error),
      error_type: enriched_metadata.error_type,
      tenant_id: metadata[:tenant_id]
    )
  end

  # =============================================================================
  # Webhook Instrumentation
  # =============================================================================

  @doc """
  Emits telemetry for webhook receipt.

  ## Parameters
  - `source` - The webhook source/provider
  - `event_type` - The type of webhook event
  - `metadata` - Additional metadata (tenant_id, payload_size, etc.)
  """
  def emit_webhook_received(source, event_type, metadata \\ %{}) do
    measurements = %{
      system_time: System.system_time(:millisecond),
      payload_size: metadata[:payload_size] || 0
    }

    webhook_id = generate_request_id()

    enriched_metadata =
      metadata
      |> Map.put(:webhook_id, webhook_id)
      |> Map.put(:source, source)
      |> Map.put(:event_type, event_type)

    :telemetry.execute(
      [:indrajaal, :integration, :webhook, :received],
      measurements,
      enriched_metadata
    )

    Logger.info("Webhook received",
      webhook_id: webhook_id,
      source: source,
      event_type: event_type,
      payload_size: measurements.payload_size,
      tenant_id: metadata[:tenant_id]
    )

    webhook_id
  end

  @doc """
  Emits telemetry for webhook processing completion.

  ## Parameters
  - `webhook_id` - The webhook ID from emit_webhook_received
  - `result` - Processing result (:success, :failure, :partial)
  - `duration_ms` - Processing duration in milliseconds
  - `metadata` - Additional metadata
  """
  def emit_webhook_processed(webhook_id, result, duration_ms, metadata \\ %{}) do
    measurements = %{
      duration: duration_ms,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:webhook_id, webhook_id)
      |> Map.put(:result, result)
      |> Map.put(:success, result == :success)

    :telemetry.execute(
      [:indrajaal, :integration, :webhook, :processed],
      measurements,
      enriched_metadata
    )

    Logger.info("Webhook processed",
      webhook_id: webhook_id,
      result: result,
      duration_ms: duration_ms,
      tenant_id: metadata[:tenant_id]
    )
  end

  # =============================================================================
  # Data Sync Instrumentation
  # =============================================================================

  @doc """
  Emits telemetry for data synchronization start.

  ## Parameters
  - `sync_type` - Type of sync (full, incremental, delta)
  - `source` - Data source identifier
  - `metadata` - Additional metadata
  """
  def emit_data_sync_start(sync_type, source, metadata \\ %{}) do
    measurements = %{
      system_time: System.system_time(:millisecond)
    }

    sync_id = generate_request_id()

    enriched_metadata =
      metadata
      |> Map.put(:sync_id, sync_id)
      |> Map.put(:sync_type, sync_type)
      |> Map.put(:source, source)

    :telemetry.execute(
      [:indrajaal, :integration, :data_sync, :start],
      measurements,
      enriched_metadata
    )

    Logger.info("Data sync started",
      sync_id: sync_id,
      sync_type: sync_type,
      source: source,
      tenant_id: metadata[:tenant_id]
    )

    sync_id
  end

  @doc """
  Emits telemetry for data synchronization completion.

  ## Parameters
  - `sync_id` - The sync ID from emit_data_sync_start
  - `result` - Sync result (:success, :failure, :partial)
  - `records_synced` - Number of records synchronized
  - `duration_ms` - Sync duration in milliseconds
  - `metadata` - Additional metadata
  """
  def emit_data_sync_stop(sync_id, result, records_synced, duration_ms, metadata \\ %{}) do
    measurements = %{
      duration: duration_ms,
      records_synced: records_synced,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:sync_id, sync_id)
      |> Map.put(:result, result)
      |> Map.put(:records_synced, records_synced)
      |> Map.put(:success, result == :success)

    :telemetry.execute(
      [:indrajaal, :integration, :data_sync, :stop],
      measurements,
      enriched_metadata
    )

    Logger.info("Data sync completed",
      sync_id: sync_id,
      result: result,
      records_synced: records_synced,
      duration_ms: duration_ms,
      tenant_id: metadata[:tenant_id]
    )
  end

  # =============================================================================
  # Rate Limit Instrumentation
  # =============================================================================

  @doc """
  Emits telemetry for rate limit exceeded event.

  ## Parameters
  - `endpoint` - The endpoint that hit rate limit
  - `limit` - The rate limit value
  - `window_ms` - Rate limit window in milliseconds
  - `metadata` - Additional metadata
  """
  def emit_rate_limit_exceeded(endpoint, limit, window_ms, metadata \\ %{}) do
    measurements = %{
      limit: limit,
      window_ms: window_ms,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:endpoint, endpoint)
      |> Map.put(:limit, limit)
      |> Map.put(:window_ms, window_ms)
      |> Map.put(:severity, :warning)

    :telemetry.execute(
      [:indrajaal, :integration, :rate_limit, :exceeded],
      measurements,
      enriched_metadata
    )

    Logger.warning("Rate limit exceeded",
      endpoint: endpoint,
      limit: limit,
      window_ms: window_ms,
      tenant_id: metadata[:tenant_id]
    )
  end

  @doc """
  Emits telemetry for retry attempt.

  ## Parameters
  - `request_id` - The original request ID
  - `attempt` - Current retry attempt number
  - `max_attempts` - Maximum retry attempts
  - `delay_ms` - Delay before retry in milliseconds
  - `metadata` - Additional metadata
  """
  def emit_retry_attempt(request_id, attempt, max_attempts, delay_ms, metadata \\ %{}) do
    measurements = %{
      attempt: attempt,
      max_attempts: max_attempts,
      delay_ms: delay_ms,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:request_id, request_id)
      |> Map.put(:attempt, attempt)
      |> Map.put(:max_attempts, max_attempts)
      |> Map.put(:delay_ms, delay_ms)
      |> Map.put(:final_attempt, attempt >= max_attempts)

    :telemetry.execute(
      [:indrajaal, :integration, :retry, :attempt],
      measurements,
      enriched_metadata
    )

    Logger.info("Retry attempt scheduled",
      request_id: request_id,
      attempt: attempt,
      max_attempts: max_attempts,
      delay_ms: delay_ms,
      tenant_id: metadata[:tenant_id]
    )
  end

  # =============================================================================
  # OpenTelemetry Tracing
  # =============================================================================

  @doc """
  Wraps an external request with OpenTelemetry tracing span.

  ## Parameters
  - `endpoint` - The external API endpoint
  - `method` - HTTP method
  - `metadata` - Additional metadata
  - `fun` - The function to execute within the span
  """
  def with_external_request_span(endpoint, method, metadata \\ %{}, fun) do
    attributes = %{
      "integration.endpoint" => endpoint,
      "integration.method" => to_string(method),
      "integration.tenant_id" => metadata[:tenant_id] || "unknown"
    }

    Tracing.with_span("integration.external_request", attributes, fn ->
      with_request_preparation_span(fn ->
        with_request_execution_span(endpoint, method, fun)
      end)
    end)
  end

  defp with_request_preparation_span(fun) do
    Tracing.with_span("integration.request_preparation", %{}, fun)
  end

  defp with_request_execution_span(endpoint, method, fun) do
    attributes = %{
      "http.url" => endpoint,
      "http.method" => to_string(method)
    }

    Tracing.with_span("integration.request_execution", attributes, fn ->
      result = fun.()

      case result do
        {:ok, response} ->
          with_response_parsing_span(fn -> {:ok, response} end)

        {:error, error} ->
          with_error_handling_span(error, fn -> {:error, error} end)
      end
    end)
  end

  defp with_response_parsing_span(fun) do
    Tracing.with_span("integration.response_parsing", %{}, fun)
  end

  defp with_error_handling_span(error, fun) do
    attributes = %{
      "error" => true,
      "error.type" => error_type(error)
    }

    Tracing.with_span("integration.error_handling", attributes, fun)
  end

  # =============================================================================
  # Event Handlers
  # =============================================================================

  defp handle_external_api_event(event, measurements, metadata, _config) do
    phase = List.last(event)

    case phase do
      :request_start ->
        Logger.debug("External API request started",
          endpoint: metadata[:endpoint],
          method: metadata[:method]
        )

      :request_stop ->
        Logger.debug("External API request completed",
          status_code: metadata[:status_code],
          duration_ms: measurements[:duration]
        )

      :error ->
        Logger.error("External API error",
          error: metadata[:error],
          error_type: metadata[:error_type]
        )
    end
  end

  defp handle_webhook_event(event, measurements, metadata, _config) do
    phase = List.last(event)

    case phase do
      :received ->
        Logger.debug("Webhook received",
          source: metadata[:source],
          event_type: metadata[:event_type]
        )

      :processed ->
        Logger.debug("Webhook processed",
          result: metadata[:result],
          duration_ms: measurements[:duration]
        )
    end
  end

  defp handle_data_sync_event(event, measurements, metadata, _config) do
    phase = List.last(event)

    case phase do
      :start ->
        Logger.debug("Data sync started",
          sync_type: metadata[:sync_type],
          source: metadata[:source]
        )

      :stop ->
        Logger.debug("Data sync completed",
          result: metadata[:result],
          records_synced: measurements[:records_synced],
          duration_ms: measurements[:duration]
        )
    end
  end

  defp handle_rate_limit_event(event, measurements, metadata, _config) do
    phase = List.last(event)

    case phase do
      :exceeded ->
        Logger.warning("Rate limit exceeded",
          endpoint: metadata[:endpoint],
          limit: measurements[:limit]
        )

      :attempt ->
        Logger.debug("Retry attempt",
          attempt: measurements[:attempt],
          max_attempts: measurements[:max_attempts]
        )
    end
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp generate_request_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  defp error_type(%{__struct__: struct}), do: struct |> Module.split() |> List.last()
  defp error_type(%{reason: _}), do: "connection_error"
  defp error_type(:timeout), do: "timeout"
  defp error_type(:closed), do: "connection_closed"
  defp error_type(_), do: "unknown"
end
