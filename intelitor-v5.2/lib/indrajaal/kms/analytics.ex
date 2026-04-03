defmodule Indrajaal.KMS.Analytics do
  @moduledoc """
  DuckDB OLAP Layer for Knowledge Management System

  WHAT: Analytical processing, metrics aggregation, and reporting.
  WHY: DuckDB provides columnar analytics without data export.
  CONSTRAINTS: SC-KMS-001 (DuckDB only), SC-KMS-002 (cross-runtime access)
  """

  require Logger

  @doc """
  Initialize DuckDB analytics database.
  """
  @spec init(String.t(), String.t()) :: :ok | {:error, term()}
  def init(duckdb_path, sqlite_path) do
    # Create DuckDB database and attach SQLite
    with {:ok, conn} <- open_connection(duckdb_path) do
      # Attach SQLite as external database
      attach_sql = "ATTACH '#{sqlite_path}' AS holons_db (TYPE SQLITE, READ_ONLY)"

      case execute(conn, attach_sql) do
        :ok ->
          Logger.info("[KMS.Analytics] DuckDB initialized, SQLite attached")
          close_connection(conn)
          :ok

        {:error, reason} ->
          close_connection(conn)
          Logger.warning("[KMS.Analytics] Could not attach SQLite: #{inspect(reason)}")
          :ok
      end
    end
  end

  @doc """
  Get health report aggregating vital signs across all holons.
  """
  @spec health_report(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def health_report(duckdb_path, sqlite_path) do
    query = """
    SELECT
      type,
      COUNT(*) as count,
      AVG(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as avg_health,
      AVG(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE)) as avg_stress,
      AVG(CAST(json_extract(vital_signs, '$.energy') AS DOUBLE)) as avg_energy,
      MIN(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as min_health,
      MAX(CAST(json_extract(vital_signs, '$.health') AS DOUBLE)) as max_health
    FROM holons_db.holons
    GROUP BY type
    ORDER BY type
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         :ok <- attach_sqlite(conn, sqlite_path),
         {:ok, results} <- execute_query(conn, query) do
      close_connection(conn)

      summary = %{
        by_type: results,
        total_holons: Enum.reduce(results, 0, fn r, acc -> acc + r.count end),
        overall_health:
          case results do
            [] ->
              1.0

            _ ->
              Enum.reduce(results, 0.0, fn r, acc -> acc + r.avg_health * r.count end) /
                Enum.reduce(results, 0, fn r, acc -> acc + r.count end)
          end,
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, summary}
    end
  end

  @doc """
  Get event statistics over a time period.
  """
  @spec event_stats(String.t(), String.t(), non_neg_integer()) ::
          {:ok, [map()]} | {:error, term()}
  def event_stats(duckdb_path, sqlite_path, days) do
    cutoff = System.system_time(:microsecond) - days * 86_400 * 1_000_000

    query = """
    SELECT
      strftime(datetime(hlc_physical/1_000_000, 'unixepoch'), '%Y-%m-%d') as day,
      event_type,
      COUNT(*) as event_count
    FROM holons_db.holon_events
    WHERE hlc_physical > #{cutoff}
    GROUP BY day, event_type
    ORDER BY day DESC, event_count DESC
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         :ok <- attach_sqlite(conn, sqlite_path),
         {:ok, results} <- execute_query(conn, query) do
      close_connection(conn)
      {:ok, results}
    end
  end

  @doc """
  Get holons with high entropy.
  """
  @spec entropy_report(String.t(), String.t(), float()) :: {:ok, [map()]} | {:error, term()}
  def entropy_report(duckdb_path, sqlite_path, threshold) do
    query = """
    WITH entropy_calc AS (
      SELECT
        id,
        fqun,
        name,
        type,
        CAST(json_extract(vital_signs, '$.health') AS DOUBLE) as health,
        CAST(json_extract(vital_signs, '$.stress') AS DOUBLE) as stress,
        updated_at,
        (1.0 - COALESCE(CAST(json_extract(vital_signs, '$.health') AS DOUBLE), 0.5)) +
        COALESCE(CAST(json_extract(vital_signs, '$.stress') AS DOUBLE), 0.0) +
        LEAST(1.0, (julianday('now') - julianday(updated_at)) / 30.0) as entropy
      FROM holons_db.holons
    )
    SELECT *
    FROM entropy_calc
    WHERE entropy >= #{threshold}
    ORDER BY entropy DESC
    LIMIT 100
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         :ok <- attach_sqlite(conn, sqlite_path),
         {:ok, results} <- execute_query(conn, query) do
      close_connection(conn)
      {:ok, results}
    end
  end

  @doc """
  Get top decaying holons for evolution engine.
  """
  @spec get_rotting_holons(String.t(), String.t(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_rotting_holons(duckdb_path, sqlite_path, limit) do
    query = """
    WITH decay_calc AS (
      SELECT
        id as holon_id,
        fqun,
        CAST(json_extract(vital_signs, '$.health') AS DOUBLE) as health,
        (julianday('now') - julianday(updated_at)) as drift,
        (1.0 - COALESCE(CAST(json_extract(vital_signs, '$.health') AS DOUBLE), 0.5)) +
        LEAST(1.0, (julianday('now') - julianday(updated_at)) / 30.0) as entropy
      FROM holons_db.holons
    )
    SELECT *
    FROM decay_calc
    WHERE entropy > 0.2
    ORDER BY entropy DESC
    LIMIT #{limit}
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         :ok <- attach_sqlite(conn, sqlite_path),
         {:ok, results} <- execute_query(conn, query) do
      close_connection(conn)
      {:ok, results}
    end
  end

  @doc """
  Get holon activity summary.
  """
  @spec activity_summary(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def activity_summary(duckdb_path, sqlite_path) do
    query = """
    SELECT
      COUNT(*) as total_holons,
      COUNT(CASE WHEN CAST(json_extract(vital_signs, '$.health') AS DOUBLE) >= 0.8 THEN 1 END) as healthy_count,
      COUNT(CASE WHEN CAST(json_extract(vital_signs, '$.health') AS DOUBLE) < 0.5 THEN 1 END) as degraded_count,
      COUNT(CASE WHEN julianday('now') - julianday(updated_at) <= 1 THEN 1 END) as updated_today,
      COUNT(CASE WHEN julianday('now') - julianday(updated_at) <= 7 THEN 1 END) as updated_this_week,
      MIN(updated_at) as oldest_update,
      MAX(updated_at) as newest_update
    FROM holons_db.holons
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         :ok <- attach_sqlite(conn, sqlite_path),
         {:ok, [result]} <- execute_query(conn, query) do
      close_connection(conn)
      {:ok, result}
    end
  end

  @doc """
  Archive old events to Parquet file.
  """
  @spec archive_events(String.t(), String.t(), String.t(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, term()}
  def archive_events(duckdb_path, sqlite_path, archive_dir, days_old) do
    cutoff = System.system_time(:microsecond) - days_old * 86_400 * 1_000_000
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:\-]/, "")
    parquet_file = Path.join(archive_dir, "events_#{timestamp}.parquet")

    export_query = """
    COPY (
      SELECT * FROM holons_db.holon_events
      WHERE hlc_physical < #{cutoff}
    ) TO '#{parquet_file}' (FORMAT PARQUET, COMPRESSION ZSTD)
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         :ok <- attach_sqlite(conn, sqlite_path),
         :ok <- execute(conn, export_query) do
      close_connection(conn)
      Logger.info("[KMS.Analytics] Archived events to #{parquet_file}")
      {:ok, parquet_file}
    end
  end

  @doc """
  Query across Parquet archives.
  """
  @spec query_archives(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def query_archives(duckdb_path, archive_pattern) do
    query = """
    SELECT
      event_type,
      COUNT(*) as count
    FROM read_parquet('#{archive_pattern}')
    GROUP BY event_type
    ORDER BY count DESC
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         {:ok, results} <- execute_query(conn, query) do
      close_connection(conn)
      {:ok, results}
    end
  end

  @doc """
  Get holon tree statistics.
  """
  @spec tree_stats(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def tree_stats(duckdb_path, sqlite_path) do
    query = """
    WITH RECURSIVE tree_depth AS (
      SELECT id, parent_id, 0 as depth
      FROM holons_db.holons
      WHERE parent_id IS NULL

      UNION ALL

      SELECT h.id, h.parent_id, t.depth + 1
      FROM holons_db.holons h
      JOIN tree_depth t ON h.parent_id = t.id
    )
    SELECT
      MAX(depth) as max_depth,
      COUNT(DISTINCT CASE WHEN parent_id IS NULL THEN id END) as root_count,
      COUNT(CASE WHEN depth = 0 THEN 1 END) as level_0,
      COUNT(CASE WHEN depth = 1 THEN 1 END) as level_1,
      COUNT(CASE WHEN depth = 2 THEN 1 END) as level_2,
      COUNT(CASE WHEN depth >= 3 THEN 1 END) as level_3_plus
    FROM tree_depth
    """

    with {:ok, conn} <- open_connection(duckdb_path),
         :ok <- attach_sqlite(conn, sqlite_path),
         {:ok, [result]} <- execute_query(conn, query) do
      close_connection(conn)
      {:ok, result}
    end
  end

  # Private Functions

  defp open_connection(duckdb_path) do
    case Duckdbex.open(duckdb_path) do
      {:ok, db} ->
        case Duckdbex.connection(db) do
          {:ok, conn} -> {:ok, {db, conn}}
          error -> error
        end

      error ->
        error
    end
  end

  defp close_connection({_db, _conn}) do
    # Duckdbex.disconnect(conn) # Undefined in v0.3?
    # Duckdbex.close(db) # Undefined in v0.3?
    # Relying on NIF resource cleanup for now
    :ok
  end

  defp attach_sqlite({_db, conn}, sqlite_path) do
    query = "ATTACH IF NOT EXISTS '#{sqlite_path}' AS holons_db (TYPE SQLITE, READ_ONLY)"

    case Duckdbex.query(conn, query) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute({_db, conn}, sql) do
    case Duckdbex.query(conn, sql) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_query({_db, conn}, sql) do
    case Duckdbex.query(conn, sql) do
      {:ok, result} ->
        columns = Duckdbex.columns(result)
        rows = Duckdbex.fetch_all(result)

        maps =
          Enum.map(rows, fn row ->
            columns
            |> Enum.zip(Tuple.to_list(row))
            |> Map.new(fn {col, val} -> {String.to_atom(col), val} end)
          end)

        {:ok, maps}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
