defmodule Indrajaal.Economy.Treasury do
  @moduledoc """
  Fractal Treasury System.
  STAMP: SC-SEC-047
  """
  require Logger

  defstruct [:balance, :assets]

  def init do
    %__MODULE__{balance: 0, assets: %{}}
  end

  def deposit(treasury, asset, amount) do
    current = Map.get(treasury.assets, asset, 0)
    %{treasury | assets: Map.put(treasury.assets, asset, current + amount)}
  end
end
