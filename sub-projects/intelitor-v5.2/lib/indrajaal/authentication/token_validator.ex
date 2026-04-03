defmodule Indrajaal.Authentication.TokenValidator do
  @moduledoc """
  Facade for validating authentication requests from headers and signing tokens.
  """

  alias Indrajaal.Authentication

  @spec validate_request(list()) :: {:ok, map()} | {:error, atom()}
  def validate_request(headers) do
    case Enum.find(headers, fn {k, _} -> String.downcase(k) == "authorization" end) do
      {_, "Bearer " <> token} ->
        Authentication.verify_token(token)

      _ ->
        {:error, :unauthorized}
    end
  end

  @spec generate_and_sign(map()) :: {:ok, String.t()} | {:error, term()}
  def generate_and_sign(claims) do
    Authentication.sign(claims)
  end

  @doc false
  @spec has_role?(map() | String.t(), atom() | String.t()) :: boolean()
  def has_role?(_token, _role), do: false

  @doc false
  @spec needs_refresh?(map() | String.t()) :: boolean()
  def needs_refresh?(_token), do: false
end
