defmodule Indrajaal.Cockpit.Prajna.Persistence.Wal do
  @moduledoc """
  Alias for Indrajaal.Cockpit.Prajna.Persistence.WAL (mixed-case compatibility).

  WHAT: Provides the `Wal` namespace alias for tests that reference mixed-case module name.
  WHY: Tests reference `Wal` while canonical module is `WAL`. This delegates to the real impl.
  CONSTRAINTS: SC-HOLON-001 (WAL mode for SQLite), SC-LED-003 (entry order preserved).
  """

  @doc "Logs an entry to the write-ahead log. Returns :ok."
  @spec log(term()) :: :ok
  defdelegate log(entry), to: Indrajaal.Cockpit.Prajna.Persistence.WAL
end
