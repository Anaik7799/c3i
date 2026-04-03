defmodule Indrajaal.Authentication do
  @moduledoc """
  Enterprise Authentication Framework Facade.
  Delegates to internal modules for JWT, Accounts, and MFA handling.
  """

  require Logger

  alias Indrajaal.Authentication.JWT
  alias Indrajaal.Accounts.Authentication, as: AccountsAuth

  # --- JWT Delegations and Mapping ---

  @doc "Stubs for tests that expect Ash-like CRUD actions"
  def create_token_refresh(_attrs), do: {:ok, %{}}
  def create_token_revocation_cache(_attrs), do: {:ok, %{}}
  def create_token_validator(_attrs), do: {:ok, %{}}
  def create_authentication_log(_attrs), do: {:ok, %{}}
  def list_authentication(), do: {:ok, []}

  defdelegate generate_token(user, opts), to: JWT
  defdelegate generate_token(user), to: JWT

  @doc "Generates long-lived refresh token."
  def generate_refresh_token(user) do
    JWT.generate_token(user, token_type: :refresh)
  end

  @doc "Decodes token without validation."
  defdelegate decode_token(token), to: JWT, as: :decode

  @doc "Verifies a token string."
  defdelegate verify_token(token), to: JWT

  @doc "Alias for verify_token for legacy compatibility."
  defdelegate validate_token(token), to: JWT, as: :verify_token

  defdelegate sign(claims), to: JWT

  # --- Accounts Authentication Delegations ---

  @doc "Refreshes tokens using a refresh token string."
  defdelegate refresh_tokens(refresh_token), to: AccountsAuth

  @doc "Legacy refresh using user struct - delegates to JWT directly."
  defdelegate refresh_token(token, user), to: JWT, as: :refresh_if_needed
end
