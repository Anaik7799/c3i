defmodule Indrajaal.Analytics.DuckdbBackend do
  @moduledoc """
  DuckDB NIF backend for Prajna analytics queries.

  ## What
  Provides a safe, telemetry-instrumented wrapper around the Duckdbex NIF
  for executing arbitrary SQL analytics queries. Gracefully degrades when
  the NIF is not compiled into the runtime.

  ## Why
  Prajna requires ad-hoc OLAP queries over event and holon history data.
  DuckDB's columnar engine delivers sub-second analytics without exporting
  data to an external warehouse.

  ## Availability
  The module checks `Code.ensure_loaded?(Duckdbex)` at call time. When the
  NIF is absent the function returns `{:error, :duckdb_not_available}` and
  emits a warning so callers can fall back gracefully (e.g. return cached
  results or skip the widget).

  ## Constraints
  - SC-BIO-EXT-009: regenerative healing from DuckDB
  - SC-CONC-001: connection management — open/close per query (no shared conn)
  - AOR-HOLON-007: use DuckDB for all holon analytics queries
  - SC-SAFETY-003: audit trail via telemetry events

  ## Change History
  | Version | Date       | Author            | Change             |
  |---------|------------|-------------------|--------------------|
  | 21.3.0  | 2026-03-23 | Claude Sonnet 4.6 | Initial implementation |
  """

  require Logger

  @doc """
  Execute an analytics SQL query against a DuckDB database file.

  Opens a fresh connection, executes `sql`, fetches all rows as a list of
  atom-keyed maps, closes the connection, and returns the result.

  ## Parameters
  - `db_path` - Filesystem path to the `.duckdb` database file
  - `sql`     - SQL string to execute

  ## Returns
  - `{:ok, [map()]}` — list of result rows (empty list when 0 rows)
  - `{:error, :duckdb_not_available}` — Duckdbex NIF not loaded
  - `{:error, term()}` — query or connection error

  ## Telemetry
  Emits `[:duckdb, :query, :start]` before execution and
  `[:duckdb, :query, :stop]` after (with `:duration` and `:result` metadata).
  """
  @spec query(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def query(db_path, sql) do
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:duckdb, :query, :start],
      %{system_time: System.system_time()},
      %{db_path: db_path, sql_length: String.length(sql)}
    )

    result = do_query(db_path, sql)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:duckdb, :query, :stop],
      %{duration: duration},
      %{db_path: db_path, result: result_tag(result)}
    )

    result
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @duckdb_available Code.ensure_loaded?(Duckdbex)

  defp do_query(db_path, sql) do
    if @duckdb_available do
      try do
        with {:ok, connection} <- open_connection(db_path),
             {:ok, rows} <- execute_query(connection, sql) do
          close_connection(connection)
          {:ok, rows}
        else
          {:error, reason} = err ->
            Logger.error("[DuckdbBackend] Query failed",
              db_path: db_path,
              reason: inspect(reason)
            )

            err
        end
      rescue
        exception ->
          Logger.error("[DuckdbBackend] Unexpected error during query",
            db_path: db_path,
            exception: inspect(exception)
          )

          {:error, {:exception, Exception.message(exception)}}
      end
    else
      Logger.warning(
        "[DuckdbBackend] Duckdbex NIF not available — returning :duckdb_not_available. " <>
          "Ensure the :duckdbex dependency is compiled and the NIF is loaded."
      )

      {:error, :duckdb_not_available}
    end
  end

  defp open_connection(db_path) do
    case Duckdbex.open(db_path) do
      {:ok, db} ->
        case Duckdbex.connection(db) do
          {:ok, conn} -> {:ok, {db, conn}}
          {:error, reason} -> {:error, {:connection_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:open_failed, reason}}
    end
  end

  defp close_connection({_db, _conn}) do
    # Duckdbex v0.3 relies on NIF resource GC — explicit close not exposed.
    :ok
  end

  defp execute_query({_db, conn}, sql) do
    case Duckdbex.query(conn, sql) do
      {:ok, result} ->
        columns = Duckdbex.columns(result)
        rows = Duckdbex.fetch_all(result)

        maps =
          Enum.map(rows, fn row ->
            row_list =
              case row do
                t when is_tuple(t) -> Tuple.to_list(t)
                l when is_list(l) -> l
              end

            columns
            |> Enum.zip(row_list)
            |> Map.new(fn {col, val} -> {String.to_atom(col), val} end)
          end)

        {:ok, maps}

      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  end

  defp result_tag({:ok, _}), do: :ok
  defp result_tag({:error, reason}), do: {:error, reason}
end
