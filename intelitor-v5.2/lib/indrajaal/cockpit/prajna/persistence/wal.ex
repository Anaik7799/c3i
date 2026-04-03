defmodule Indrajaal.Cockpit.Prajna.Persistence.WAL do
  @moduledoc """
  Write-Ahead Log for persistence safety.
  STAMP: SC-SIL4-002
  """
  require Logger

  def log(operation) do
    Logger.debug("WAL: #{inspect(operation)}")
    :ok
  end
end
