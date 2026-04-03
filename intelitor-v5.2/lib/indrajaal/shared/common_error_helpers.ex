defmodule Indrajaal.Shared.CommonErrorHelpers do
  @moduledoc """
  Shared error handling utilities to eliminate code duplication
  """

  require Logger

  @spec log_structured_error(term(), term(), map()) :: term()
  def log_structured_error(error_type, message, meta_data \\ %{}) do
    Logger.error("Error: #{error_type} - #{message}", Map.to_list(meta_data))

    # Add telemetry for error tracking
    :telemetry.execute([:indrajaal, :error], %{count: 1}, %{
      error_type: error_type,
      message: message,
      meta_data: meta_data
    })
  end

  @spec format_error_response(term(), map()) :: term()
  def format_error_response(error, context \\ %{}) do
    %{
      error: true,
      type: Map.get(error, :type, "unknown"),
      message: Map.get(error, :message, "Unknown error"),
      __context: context,
      timestamp: DateTime.utc_now()
    }
  end
end
