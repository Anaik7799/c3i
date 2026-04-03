defmodule Indrajaal.Notifications.Backends.Behaviour do
  @moduledoc """
  Behaviour definition for notification backends.

  All notification backends must implement this behaviour to ensure
  consistent interface across different notification channels.

  STAMP Compliance:
  - SC-OBS-067: Standardized notification interface
  - SC-AGT-022: Message integrity validation

  Reference: CLAUDE.md §6 (Agent Operating Rules)
  """

  @type delivery_result :: {:ok, map()} | {:error, term()}

  @doc """
  Delivers a notification through the backend.

  ## Parameters
    - params: Backend-specific parameters (varies by implementation)
    - opts: Optional configuration (timeout, retry settings, etc.)

  ## Returns
    - {:ok, %{status: :delivered, ...}} on success
    - {:error, reason} on failure
  """
  @callback deliver(params :: map() | String.t(), opts :: keyword()) :: delivery_result()
end
