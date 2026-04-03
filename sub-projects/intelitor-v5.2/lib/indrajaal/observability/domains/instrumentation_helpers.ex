defmodule Indrajaal.Observability.Domains.InstrumentationHelpers do
  @moduledoc """
  Shared helper functions for domain instrumentation modules.

  WHAT: Provides common result-handling patterns for telemetry operations.
  WHY: Eliminates duplicate code across domain instrumentation modules per SC-DOC-001.
  CONSTRAINTS: Must be used consistently across all domain instrumentation modules.

  ## Usage

  ```elixir
  defp handle_operation_stop(operation, measurements, metadata) do
    InstrumentationHelpers.handle_stop_result(
      metadata,
      operation,
      fn enriched, op, result -> add_domain_metrics(enriched, op, result) end,
      fn -> enrich_metadata(metadata, operation) end,
      fn op, phase, meas, enriched -> emit_domain_event(op, phase, meas, enriched) end
    )
  end
  ```
  """

  # Private helper to enrich metadata with result status
  # DRY: Extracted from duplicate patterns in handle_stop_result and handle_stop_with_measurements
  @spec enrich_with_result(map(), map(), atom(), (map(), atom(), term() -> map())) :: map()
  defp enrich_with_result(enriched, metadata, operation, add_metrics_fn) do
    case metadata do
      %{result: {:ok, result}} ->
        enriched
        |> Map.put(:_result, :ok)
        |> add_metrics_fn.(operation, result)

      %{result: {:error, error}} ->
        enriched
        |> Map.put(:_result, :error)
        |> Map.put(:error, inspect(error))

      _ ->
        enriched
    end
  end

  @doc """
  Handles the common result pattern for operation stop events.

  This function extracts the common pattern of:
  1. Enriching metadata
  2. Pattern matching on result (:ok/:error)
  3. Adding domain-specific metrics for successful operations
  4. Emitting the domain event

  ## Parameters

  - `metadata` - The telemetry metadata map
  - `operation` - The operation type (:create, :update, :read, :destroy)
  - `add_metrics_fn` - A function (enriched, operation, result) -> enriched to add domain-specific metrics
  - `enrich_fn` - A function () -> enriched_metadata to generate enriched metadata
  - `emit_fn` - A function (operation, phase, measurements, enriched) -> :ok to emit events

  ## Returns

  The enriched metadata map after processing.
  """
  @spec handle_stop_result(
          metadata :: map(),
          operation :: atom(),
          add_metrics_fn :: (map(), atom(), term() -> map()),
          enrich_fn :: (-> map()),
          emit_fn :: (atom(), atom(), map(), map() -> any())
        ) :: map()
  def handle_stop_result(metadata, operation, add_metrics_fn, enrich_fn, emit_fn) do
    enriched = enrich_fn.() |> enrich_with_result(metadata, operation, add_metrics_fn)
    emit_fn.(operation, :stop, metadata, enriched)
    enriched
  end

  @doc """
  Simplified version that accepts measurements separately.

  This variant allows passing measurements explicitly for cases where
  the emit function needs them directly.

  ## Parameters

  - `metadata` - The telemetry metadata map
  - `measurements` - The telemetry measurements map
  - `operation` - The operation type (:create, :update, :read, :destroy)
  - `add_metrics_fn` - A function (enriched, operation, result) -> enriched to add domain-specific metrics
  - `enrich_fn` - A function () -> enriched_metadata to generate enriched metadata
  - `emit_fn` - A function (operation, phase, measurements, enriched) -> :ok to emit events

  ## Returns

  The enriched metadata map after processing.
  """
  @spec handle_stop_with_measurements(
          metadata :: map(),
          measurements :: map(),
          operation :: atom(),
          add_metrics_fn :: (map(), atom(), term() -> map()),
          enrich_fn :: (-> map()),
          emit_fn :: (atom(), atom(), map(), map() -> any())
        ) :: map()
  def handle_stop_with_measurements(
        metadata,
        measurements,
        operation,
        add_metrics_fn,
        enrich_fn,
        emit_fn
      ) do
    enriched = enrich_fn.() |> enrich_with_result(metadata, operation, add_metrics_fn)
    emit_fn.(operation, :stop, measurements, enriched)
    enriched
  end

  @doc """
  Extended version with post-processing callback.

  This variant allows executing domain-specific logic after the main
  stop event is emitted.

  ## Parameters

  - `metadata` - The telemetry metadata map
  - `measurements` - The telemetry measurements map
  - `operation` - The operation type (:create, :update, :read, :destroy)
  - `add_metrics_fn` - A function (enriched, operation, result) -> enriched to add domain-specific metrics
  - `enrich_fn` - A function () -> enriched_metadata to generate enriched metadata
  - `emit_fn` - A function (operation, phase, measurements, enriched) -> :ok to emit events
  - `post_process_fn` - A function (operation, measurements, enriched, metadata) -> :ok for post-processing

  ## Returns

  The enriched metadata map after processing.
  """
  @spec handle_stop_with_post_process(
          metadata :: map(),
          measurements :: map(),
          operation :: atom(),
          add_metrics_fn :: (map(), atom(), term() -> map()),
          enrich_fn :: (-> map()),
          emit_fn :: (atom(), atom(), map(), map() -> any()),
          post_process_fn :: (atom(), map(), map(), map() -> any())
        ) :: map()
  def handle_stop_with_post_process(
        metadata,
        measurements,
        operation,
        add_metrics_fn,
        enrich_fn,
        emit_fn,
        post_process_fn
      ) do
    enriched =
      handle_stop_with_measurements(
        metadata,
        measurements,
        operation,
        add_metrics_fn,
        enrich_fn,
        emit_fn
      )

    post_process_fn.(operation, measurements, enriched, metadata)

    enriched
  end
end
