defmodule Indrajaal.Observability.DomainLogger do
  @moduledoc """
  Domain operation logging module for observability.

  Provides structured logging for successful domain operations.
  """

  require Logger

  @doc """
  Logs a successful domain operation with context and metadata.

  ## Parameters

    * `domain` - The domain where the operation succeeded (atom)
    * `operation` - The operation that succeeded (string)
    * `metadata` - Additional metadata (keyword list)

  ## Examples

      iex> DomainLogger.log_success(:accounts, "create_user", user_id: 123, email: "user@example.com")
      :ok
  """
  def log_success(domain, operation, metadata \\ []) do
    Logger.info(
      "Success in #{domain}.#{operation}",
      Keyword.merge([domain: domain, operation: operation], metadata)
    )
  end
end
