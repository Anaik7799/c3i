defmodule Indrajaal.Observability.ErrorLogger do
  @moduledoc """
  Error logging module for observability.

  Provides structured error logging with context and metadata.
  """

  require Logger

  @doc """
  Logs an error with domain, operation, reason, and metadata.

  ## Parameters

    * `domain` - The domain where the error occurred (atom)
    * `operation` - The operation that failed (string)
    * `reason` - The error reason (term)
    * `metadata` - Additional metadata (keyword list)

  ## Examples

      iex> ErrorLogger.log_error(:accounts, "create_user", :invalid_email, user_id: 123)
      :ok
  """
  def log_error(domain, operation, reason, metadata \\ []) do
    Logger.error(
      "Error in #{domain}.#{operation}: #{inspect(reason)}",
      Keyword.merge([domain: domain, operation: operation, reason: reason], metadata)
    )
  end
end
