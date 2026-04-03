defmodule Indrajaal.SMRITI.Federation.Provenance do
  @moduledoc """
  L7: Federation Provenance.
  Ensures the authenticity of Holons entering the mesh via cryptographic signing.
  """
  require Logger

  # In prod, fetch from Vault/Env
  @secret_key "indrajaal_federation_secret_v1"

  @doc """
  Signs a Holon payload.
  Returns the signature string.
  """
  def sign(payload) when is_binary(payload) do
    :crypto.mac(:hmac, :sha256, @secret_key, payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies a Holon's signature.
  """
  def verify(payload, signature) do
    expected = sign(payload)

    if Plug.Crypto.secure_compare(expected, signature) do
      {:ok, :valid}
    else
      Logger.warning("[SMRITI.Provenance] 🛡️  Signature Mismatch! Possible tampering.")
      {:error, :invalid_signature}
    end
  end

  @doc """
  Checks if a source is trusted in the Federation.
  """
  def trusted_source?(source_id) do
    # Placeholder for Federation Registry check
    # Would query D7 (Legal) dimension
    source_id != "unknown"
  end
end
