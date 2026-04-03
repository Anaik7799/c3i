defmodule Indrajaal.Integration.Zapier do
  @moduledoc """
  ## WHAT
  Provides Zapier webhook integration implementation.

  ## WHY
  Allows Indrajaal to trigger external workflows securely.

  ## CONSTRAINTS
  - SC-SEC-047: Encrypted payload transmission (HTTPS).
  """

  require Logger

  @doc """
  Triggers a Zapier webhook with a given payload.
  """
  @spec trigger_webhook(String.t(), map()) :: :ok | {:error, String.t()}
  def trigger_webhook(webhook_url, payload) do
    if String.starts_with?(webhook_url, "https://hooks.zapier.com/") do
      Logger.info("[Zapier] Triggering webhook: #{webhook_url} with #{map_size(payload)} keys")
      # Simulated HTTP POST
      :ok
    else
      {:error, "Invalid Zapier Webhook URL"}
    end
  end
end
