defmodule IndrajaalWeb.FeatureCase do
  @moduledoc """
  Case template for Wallaby E2E browser tests.
  Uses Chrome via NixOS chromedriver (SC-COV-008).

  ## Usage

      use IndrajaalWeb.FeatureCase

  Tests automatically get a `session` in the test context.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature
      import Wallaby.Query
      @endpoint IndrajaalWeb.Endpoint
    end
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(
        Indrajaal.Repo,
        shared: not tags[:async]
      )

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Indrajaal.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
