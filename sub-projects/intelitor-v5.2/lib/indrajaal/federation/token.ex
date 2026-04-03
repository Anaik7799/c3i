defmodule Indrajaal.Federation.Token do
  @moduledoc """
  ## FEDERATION TRUST TOKEN (L7-UNIVERSE)
  Provides cryptographic attestation for inter-mesh communication.

  **Mechanism**:
  - Uses `Phoenix.Token` (HS256) signed with the Mesh's Sovereign Key.
  - TTL: 60 seconds (Ephemeral Trust).
  - Payload: `{mesh_id, timestamp, health_score}`.

  **Compliance**: SC-SIL6-009 (Federation Consensus)
  """

  alias IndrajaalWeb.Endpoint

  @salt "federation_attestation"
  # 60 seconds
  @max_age 60

  @doc """
  Generates a signed attestation token asserting the Mesh's identity and health.
  """
  @spec sign(map()) :: binary()
  def sign(payload) do
    # Inject Galactic Identity & Species
    enriched_payload =
      payload
      |> Map.put(:galaxy_id, "milky_way")
      |> Map.put(:species, "silicon_carbon_hybrid")

    Phoenix.Token.sign(Endpoint, @salt, enriched_payload)
  end

  @doc """
  Verifies an incoming federation token.
  Returns `{:ok, payload}` or `{:error, reason}`.
  """
  @spec verify(binary()) :: {:ok, map()} | {:error, any()}
  def verify(token) do
    Phoenix.Token.verify(Endpoint, @salt, token, max_age: @max_age)
  end
end
