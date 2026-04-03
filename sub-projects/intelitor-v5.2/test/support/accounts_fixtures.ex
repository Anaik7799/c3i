defmodule Indrajaal.AccountsFixtures do
  @moduledoc """
  Compatibility shim for Indrajaal.AccountsFixtures.
  Delegates to Indrajaal.Factory for actual data creation.
  """
  import Indrajaal.Factory

  def tenant_fixture(attrs \\ %{}) do
    insert(:tenant, attrs)
  end

  def user_fixture(attrs \\ %{}) do
    insert(:user, attrs)
  end

  def __user_fixture(attrs \\ %{}) do
    insert(:user, attrs)
  end
end
