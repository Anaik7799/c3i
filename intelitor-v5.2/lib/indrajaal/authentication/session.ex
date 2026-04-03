defmodule Indrajaal.Authentication.Session do
  @moduledoc """
  Facade for Session management.
  Delegates to Indrajaal.Accounts.Session.
  """

  alias Indrajaal.Accounts.Session

  defdelegate create(user, params), to: Session

  @doc false
  @spec create(map()) :: {:ok, map()} | {:error, term()}
  def create(user), do: Session.create(user, %{})

  @doc """
  Get session info. Maps to Session.get/1.
  """
  @spec get_info(String.t()) :: {:ok, map()} | {:error, term()}
  def get_info(id) do
    # Ash.get returns {:ok, result} or {:error, error}
    Session.get(id)
  end

  defdelegate revoke(id), to: Session
end
