defmodule Indrajaal.Compilation.Registry do
  @moduledoc """
  Registry for managing compilation progress tracking sessions.
  """

  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end
end
