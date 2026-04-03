defmodule Indrajaal.Vault do
  @moduledoc """
  Vault for data encryption using Cloak.
  Enforces Layer 5 security standards.
  """
  use Cloak.Vault, otp_app: :indrajaal

  @impl true
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "GCM", key: get_key(), iv_length: 12}
      )

    {:ok, config}
  end

  defp get_key do
    # In production, this MUST be a 32-byte binary from environment
    System.get_env("CLOAK_KEY") || "z" |> String.duplicate(32)
  end
end
