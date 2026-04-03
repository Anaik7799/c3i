defmodule Indrajaal.Shared.FactoryBase do
  @moduledoc """
  Factory base module eliminating duplicate _using__ patterns across 12+ factory files.
  """

  defmacro __using__(_opts) do
    quote do
      use ExMachina.Ecto, repo: Indrajaal.Repo
      alias Indrajaal.Factory
      import Indrajaal.Shared.TestSupport

      def process_request(attrs \\ %{}) do
        Factory.tenant_fixture(attrs)
      end
    end
  end
end
