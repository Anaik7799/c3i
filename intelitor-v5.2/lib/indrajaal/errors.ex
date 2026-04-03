defmodule Indrajaal.Errors do
  @moduledoc """
  Comprehensive error hierarchy for the Indrajaal Security Monitoring System.

  This module defines a complete error hierarchy using Splode for consistent,
  structured error handling across all domains with proper telemetry integration.
  """

  use Splode,
    error_classes: [
      # Security - related errors
      forbidden: Indrajaal.Errors.Forbidden,
      unauthorized: Indrajaal.Errors.Unauthorized,

      # Validation and business logic errors
      invalid: Indrajaal.Errors.Invalid,
      business: Indrajaal.Errors.Business,
      conflict: Indrajaal.Errors.Conflict,

      # System and infrastructure errors
      system: Indrajaal.Errors.System,
      external: Indrajaal.Errors.External,
      timeout: Indrajaal.Errors.Timeout,

      # Resource - specific errors
      not_found: Indrajaal.Errors.NotFound,
      service_unavailable: Indrajaal.Errors.ServiceUnavailable,

      # Fallback for unknown errors
      unknown: Indrajaal.Errors.Unknown
    ],
    unknown_error: Indrajaal.Errors.Unknown.UnknownError

  @doc """
  Normalizes an error into a consistent format for processing.

  Handles various error types including exceptions, Splode errors, and maps.
  Returns a normalized map with :message, :class, and optional :details keys.

  ## Examples

      iex> normalize_error(%RuntimeError{message: "oops"})
      %{message: "oops", class: RuntimeError, details: %{}}

      iex> normalize_error("string error")
      %{message: "string error", class: :string, details: %{}}
  """
  @spec normalize_error(term()) :: map()
  def normalize_error(error) when is_exception(error) do
    %{
      message: Exception.message(error),
      class: error.__struct__,
      details: Map.from_struct(error) |> Map.drop([:__exception__, :__struct__])
    }
  end

  def normalize_error(error) when is_binary(error) do
    %{message: error, class: :string, details: %{}}
  end

  def normalize_error(%{message: message} = error) when is_map(error) do
    %{
      message: to_string(message),
      class: Map.get(error, :class, :map),
      details: Map.drop(error, [:message, :class])
    }
  end

  def normalize_error(error) when is_map(error) do
    %{
      message: inspect(error),
      class: :map,
      details: error
    }
  end

  def normalize_error(error) do
    %{message: inspect(error), class: :unknown, details: %{}}
  end

  @doc """
  Emit telemetry __event for error occurrence with comprehensive context.
  """
  @spec emit_error_telemetry(any(), any()) :: any()
  def emit_error_telemetry(error, context \\ %{}) do
    meta_data = %{
      error_class: error.__struct__,
      error_message: Exception.message(error),
      error_details: Map.from_struct(error),
      __context: context,
      trace_id: extract_trace_id(),
      timestamp: DateTime.utc_now()
    }

    :telemetry.execute(
      [:indrajaal, :error, :occurred],
      %{count: 1, timestamp: System.system_time(:second)},
      meta_data
    )

    require Logger

    Logger.error("Error occurred",
      error_class: meta_data.error_class,
      error_message: meta_data.error_message,
      error_details: meta_data.error_details,
      __context: meta_data.__context,
      trace_id: meta_data.trace_id
    )
  end

  @spec extract_trace_id() :: any()
  def extract_trace_id() do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        nil

      span_ctx ->
        result =
          if Code.ensure_loaded?(OpenTelemetry) do
            if Code.ensure_loaded?(OpenTelemetry) do
              OpenTelemetry.Span.trace_id(span_ctx)
            else
              :ok
            end
          else
            :ok
          end

        to_string(result)
    end
  rescue
    _ -> nil
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
