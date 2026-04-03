defmodule IndrajaalWeb.Guardian do
  @moduledoc """
  WHAT: Guardian JWT implementation for the IndrajaalWeb application.
  WHY: Provides token-based authentication by encoding/decoding user identity
       into JWT claims, satisfying Phoenix Guardian integration requirements.
  CONSTRAINTS: SC-SEC-047 (encryption/auth tokens)
  """
  use Guardian, otp_app: :indrajaal

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(claims) do
    # Stub implementation to satisfy compilation.
    # Real implementation should fetch user from Accounts.
    {:ok, %{id: claims["sub"]}}
  end
end
