defmodule Indrajaal.Cockpit.Prajna.Persistence.DuckdbBackend do
  @moduledoc """
  Alias for Indrajaal.Cockpit.Prajna.Persistence.DuckDBBackend (mixed-case compatibility).

  WHAT: Provides the `DuckdbBackend` namespace alias for tests that reference this casing.
  WHY: Tests reference `DuckdbBackend` while canonical module is `DuckDBBackend`.
  CONSTRAINTS: SC-HOLON-001 (state persists to SQLite/DuckDB), SC-LED-001 (entries immutable).
  """

  @doc "Appends a record to the DuckDB store. Returns :ok."
  @spec append(term()) :: :ok
  defdelegate append(record), to: Indrajaal.Cockpit.Prajna.Persistence.DuckDBBackend

  @doc "Reads all records from the DuckDB store. Returns a list."
  @spec read_all() :: list()
  defdelegate read_all(), to: Indrajaal.Cockpit.Prajna.Persistence.DuckDBBackend
end
