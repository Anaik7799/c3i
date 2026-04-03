defmodule Indrajaal.Shared.EnhancedErrorHelpers do
  # PHASE H.3: Error helpers unified with UnifiedErrorSystem

  @moduledoc """
  Enhanced Error Handling Utilities - Consolidated from 25+ duplicate patterns

  Eliminates duplicate log_structured_error patterns across all domain modules.
  Provides consistent error handling with structured logging and telemetry.
  """

  require Logger

  alias Indrajaal.Shared.UnifiedErrorSystem

  @doc """
  Log structured error with consistent format across all domains.
  Replaces 25+ duplicate implementations with single consolidated version.
  """
  # PHASE H.3: log_structured_error unified - using UnifiedErrorSystem.log_structured_error
  @spec log_structured_error(term(), term(), map()) :: term()
  def log_structured_error(error, domain, context \\ %{}) do
    # Add domain to context for UnifiedErrorSystem
    enhanced_context = Map.put(context, :domain, domain)
    UnifiedErrorSystem.log_structured_error(error, enhanced_context)
  end

  @doc """
  Log structured warning with domain context.
  """
  @spec log_structured_warning(term(), term(), map()) :: term()
  def log_structured_warning(domain, message, context \\ %{}) do
    warning_data = %{
      domain: domain,
      message: message,
      __context: context,
      timestamp: DateTime.utc_now(),
      trace_id: get_trace_id()
    }

    Logger.warning("Domain warning", warning_data)

    {:warning, warning_data}
  end

  @doc """
  Create consistent error response format.
  """
  @spec error_response(term(), any()) :: term()
  def error_response(error, message \\ nil) do
    %{
      success: false,
      error: format_error(error),
      message: message || default_error_message(error),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Analyze validation errors with domain context.
  """
  @spec analyze_validation_errors(atom(), term()) :: term()
  def analyze_validation_errors(domain, changeset) do
    error_data = %{
      domain: domain,
      changeset: changeset,
      errors: get_changeset_errors(changeset),
      timestamp: DateTime.utc_now(),
      trace_id: get_trace_id()
    }

    Logger.error("Validation errors in domain #{domain}", error_data)

    {:error, error_data}
  end

  # Private helpers

  # PHASE H.3: format_error unified - using UnifiedErrorSystem.format_error
  defp format_error(error), do: UnifiedErrorSystem.format_error(error)

  defp default_error_message(_error) do
    # AGENT STUB: error parameter reserved for __context-specific error message generation
    "An error occurred"
  end

  defp get_trace_id do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        nil

      span_ctx ->
        if Code.ensure_loaded?(OpenTelemetry) do
          span_ctx |> OpenTelemetry.Span.trace_id() |> Integer.to_string(16)
        else
          nil
        end
    end
  end

  defp get_changeset_errors(changeset) do
    case changeset do
      %Ecto.Changeset{errors: errors} -> errors
      _ -> []
    end
  end
end
