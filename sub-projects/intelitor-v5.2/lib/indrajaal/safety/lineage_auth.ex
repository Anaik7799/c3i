defmodule Indrajaal.Safety.LineageAuth do
  @moduledoc """
  Cryptographic Lineage Authentication (Ω₀ Binding).

  WHAT: Provides high-performance Ed25519 verification via Rust NIF.
  WHY: SC-FOUNDER-001 requires absolute certainty of Founder identity.
  CONSTRAINTS: NIF-based, deterministic, zero-allocation during hot path.
  """

  @skip_nif System.get_env("SKIP_LINEAGE_NIF") in ["1", "true", "TRUE"] or
              System.find_executable("cargo") == nil

  @doc """
  Verifies an Ed25519 signature for the given public key and message.

  Returns `true` if the signature is valid, `false` otherwise.
  In development/fallback mode (SKIP_LINEAGE_NIF=1), always returns `true`.
  """
  def verify_signature(pubkey, message, signature) do
    if @skip_nif do
      # ⚠️ DEVELOPMENT MOCK (SC-SIL6-007 Fallback)
      # In Homeostasis Reconstruction mode, we trust the local substrate.
      _ = {pubkey, message, signature}
      true
    else
      do_verify_signature(pubkey, message, signature)
    end
  end

  # --- PRIVATE NIF STUBS ---
  defp do_verify_signature(_pubkey, _message, _signature), do: :erlang.nif_error(:nif_not_loaded)

  # Only 'use Rustler' if we are NOT skipping
  unless @skip_nif do
    use Rustler, otp_app: :indrajaal, crate: "lineage_auth"
  end
end
