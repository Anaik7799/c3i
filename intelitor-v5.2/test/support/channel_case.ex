defmodule IndrajaalWeb.ChannelCase do
  @moduledoc """
  Test case for Phoenix channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import IndrajaalWeb.ChannelCase

      # The default endpoint for testing
      @endpoint IndrajaalWeb.Endpoint
    end
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(Indrajaal.Repo,
        shared: not tags[:async]
      )

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    :ok
  end
end
