defmodule Indrajaal.Observability.AuditLogger do
  @moduledoc """
  Audit event logging module for observability.

  Provides structured logging for audit events with operation types and metadata.
  """

  require Logger

  @doc """
  Logs an audit event with operation type, subtype, details, and metadata.

  ## Parameters

    * `operation_type` - The type of operation (string, e.g., "user_action")
    * `operation_subtype` - The subtype of operation (string, e.g., "create", "update", "delete")
    * `details` - Details about the operation (map or keyword list)
    * `metadata` - Additional audit metadata (keyword list)

  ## Examples

      iex> AuditLogger.log_audit_event("user_action", "create_user", %{user_id: 123}, tenant_id: 1)
      :ok
  """
  def log_audit_event(operation_type, operation_subtype, details, metadata \\ []) do
    Logger.info(
      "Audit: #{operation_type}.#{operation_subtype}",
      Keyword.merge(
        [
          operation_type: operation_type,
          operation_subtype: operation_subtype,
          details: details
        ],
        metadata
      )
    )
  end
end
