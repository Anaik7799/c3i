defmodule Indrajaal.KMS.SmritiIntegration do
  @moduledoc """
  SMRITI Integration Module

  Provides integration between the F# SMRITI (Zettelkasten Knowledge Management System)
  and the Elixir/Phoenix application stack.

  ## Features

  - Prajna Cockpit knowledge metrics
  - Health monitoring integration
  - Devenv command support
  - Telemetry events

  ## Architecture Change (2026-01-17)
  All SQLite access is now routed through Zenoh pub/sub to CEPAF F# backend
  per SC-DBPROXY-001. Direct Exqlite calls are commented out and replaced
  with DatabaseProxy calls.

  ## STAMP Constraints

  - SC-HOLON-001: All holon state in SQLite
  - SC-HOLON-009: Single-file portability
  - SC-PRAJNA-004: Sentinel health integration
  - SC-DBPROXY-001: SQLite access via Zenoh proxy

  ## Usage

      # Get SMRITI metrics for dashboard
      {:ok, metrics} = SmritiIntegration.get_metrics()

      # Search knowledge base
      {:ok, results} = SmritiIntegration.search("architecture")

      # Health check
      {:ok, health} = SmritiIntegration.health_check()
  """

  require Logger

  alias Indrajaal.Zenoh.DatabaseProxy

  @smriti_db_path Application.compile_env(:indrajaal, :smriti_db_path, "data/kms/smriti.db")
  @cli_script "lib/cepaf/scripts/SmritiIngestorCLI.fsx"
  @verifier_script "lib/cepaf/scripts/SmritiIntegrationVerifier.fsx"

  # ============================================================================
  # Metrics API (for Prajna Dashboard)
  # ============================================================================

  @doc """
  Get SMRITI metrics for Prajna dashboard.

  Returns comprehensive metrics about the knowledge base including
  holon counts, cluster distribution, and health indicators.
  """
  @spec get_metrics() :: {:ok, map()} | {:error, term()}
  def get_metrics do
    with {:ok, conn} <- open_connection(),
         {:ok, total} <- query_total_holons(conn),
         {:ok, orphans} <- query_orphan_count(conn),
         {:ok, stale} <- query_stale_count(conn),
         {:ok, clusters} <- query_clusters(conn) do
      close_connection(conn)

      {:ok,
       %{
         total_holons: total,
         orphan_holons: orphans,
         stale_holons: stale,
         clusters: clusters,
         cluster_count: length(clusters),
         health_score: calculate_health_score(total, orphans, stale),
         database_path: @smriti_db_path,
         last_updated: DateTime.utc_now()
       }}
    else
      {:error, reason} = error ->
        Logger.warning("SMRITI metrics query failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Search the knowledge base using FTS5 full-text search.
  """
  @spec search(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    sql = """
    SELECT h.holon_uuid, h.title, h.entropy, h.level, h.cluster, h.tags
    FROM holons h
    JOIN holons_fts fts ON fts.rowid = h.rowid
    WHERE holons_fts MATCH ?1
    ORDER BY bm25(holons_fts)
    LIMIT ?2
    """

    case DatabaseProxy.sqlite_query(sql, [query, limit], db_path: @smriti_db_path) do
      {:ok, rows} when is_list(rows) ->
        results =
          Enum.map(rows, fn [uuid, title, entropy, level, cluster, tags] ->
            %{
              holon_uuid: uuid,
              title: title,
              entropy: entropy,
              level: level,
              cluster: cluster,
              tags: String.split(tags || "", ",", trim: true)
            }
          end)

        {:ok, results}

      {:ok, _} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Perform SMRITI health check for Sentinel integration.
  """
  @spec health_check() :: {:ok, map()} | {:error, term()}
  def health_check do
    start_time = System.monotonic_time(:millisecond)

    checks = [
      {:database_exists, File.exists?(@smriti_db_path)},
      {:database_readable, check_database_readable()},
      {:fts_functional, check_fts_functional()},
      {:cli_available, File.exists?(@cli_script)}
    ]

    elapsed = System.monotonic_time(:millisecond) - start_time
    passed = Enum.count(checks, fn {_, result} -> result end)
    total = length(checks)

    status = if passed == total, do: :healthy, else: :degraded

    # Emit telemetry
    :telemetry.execute(
      [:smriti, :health, :check],
      %{duration_ms: elapsed, passed: passed, total: total},
      %{status: status}
    )

    {:ok,
     %{
       status: status,
       checks: Map.new(checks),
       passed: passed,
       total: total,
       score: passed / total * 100,
       duration_ms: elapsed
     }}
  end

  # ============================================================================
  # CLI Wrappers
  # ============================================================================

  @doc """
  Get SMRITI status via CLI.
  """
  @spec status() :: {:ok, String.t()} | {:error, term()}
  def status do
    run_cli_command(["status"])
  end

  @doc """
  Ingest documents into SMRITI.
  """
  @spec ingest(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def ingest(path, opts \\ []) do
    max = Keyword.get(opts, :max, 10)
    cluster = Keyword.get(opts, :cluster, "docs")

    args = ["ingest", path, "--max", to_string(max), "--cluster", cluster]
    run_cli_command(args)
  end

  @doc """
  List orphan holons.
  """
  @spec orphans() :: {:ok, String.t()} | {:error, term()}
  def orphans do
    run_cli_command(["orphans"])
  end

  @doc """
  List stale holons.
  """
  @spec stale(float()) :: {:ok, String.t()} | {:error, term()}
  def stale(threshold \\ 0.6) do
    run_cli_command(["stale", "--threshold", to_string(threshold)])
  end

  @doc """
  Recalculate entropy for all holons.
  """
  @spec recalculate_entropy() :: {:ok, String.t()} | {:error, term()}
  def recalculate_entropy do
    run_cli_command(["entropy"])
  end

  @doc """
  Run 8-level fractal integration verification.
  """
  @spec verify() :: {:ok, String.t()} | {:error, term()}
  def verify do
    case System.cmd("dotnet", ["fsi", @verifier_script], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  # ============================================================================
  # Telemetry
  # ============================================================================

  @doc """
  Emit SMRITI metrics to telemetry for Prajna dashboard.
  """
  @spec emit_metrics() :: :ok
  def emit_metrics do
    case get_metrics() do
      {:ok, metrics} ->
        :telemetry.execute(
          [:smriti, :metrics],
          %{
            total_holons: metrics.total_holons,
            orphan_holons: metrics.orphan_holons,
            stale_holons: metrics.stale_holons,
            cluster_count: metrics.cluster_count,
            health_score: metrics.health_score
          },
          %{timestamp: DateTime.utc_now()}
        )

      {:error, _} ->
        :ok
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  # SC-DBPROXY-001: Connection management via Zenoh proxy
  # Note: With proxy mode, connections are managed by the F# backend
  defp open_connection do
    case DatabaseProxy.sqlite_open(@smriti_db_path) do
      {:ok, conn_ref} -> {:ok, {:proxy, conn_ref, @smriti_db_path}}
      {:error, reason} -> {:error, {:connection_failed, reason}}
    end
  end

  defp close_connection({:proxy, _conn_ref, _path}) do
    # SC-DBPROXY-001: Connection pooling managed by F# backend
    :ok
  end

  defp query_total_holons({:proxy, _conn_ref, db_path}) do
    case DatabaseProxy.sqlite_query("SELECT COUNT(*) FROM holons", [], db_path: db_path) do
      {:ok, [[count]]} -> {:ok, count}
      {:ok, []} -> {:ok, 0}
      {:error, reason} -> {:error, {:query_failed, reason}}
    end
  end

  defp query_orphan_count({:proxy, _conn_ref, db_path}) do
    sql = """
    SELECT COUNT(*) FROM holons h
    WHERE NOT EXISTS (
      SELECT 1 FROM holon_edges e
      WHERE e.source_id = h.holon_uuid OR e.target_id = h.holon_uuid
    )
    """

    case DatabaseProxy.sqlite_query(sql, [], db_path: db_path) do
      {:ok, [[count]]} -> {:ok, count}
      {:ok, []} -> {:ok, 0}
      {:error, reason} -> {:error, {:query_failed, reason}}
    end
  end

  defp query_stale_count({:proxy, _conn_ref, db_path}) do
    case DatabaseProxy.sqlite_query("SELECT COUNT(*) FROM holons WHERE entropy > 0.6", [],
           db_path: db_path
         ) do
      {:ok, [[count]]} -> {:ok, count}
      {:ok, []} -> {:ok, 0}
      {:error, reason} -> {:error, {:query_failed, reason}}
    end
  end

  defp query_clusters({:proxy, _conn_ref, db_path}) do
    sql = """
    SELECT cluster, COUNT(*) as cnt
    FROM holons
    WHERE cluster IS NOT NULL AND cluster != ''
    GROUP BY cluster
    ORDER BY cnt DESC
    """

    case DatabaseProxy.sqlite_query(sql, [], db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        clusters = Enum.map(rows, fn [cluster, cnt] -> %{name: cluster, count: cnt} end)
        {:ok, clusters}

      {:ok, _} ->
        {:ok, []}

      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  end

  defp calculate_health_score(total, orphans, stale) when total > 0 do
    orphan_ratio = orphans / total
    stale_ratio = stale / total

    # Health decreases with more orphans and stale holons
    base_score = 100
    # Max 30% penalty
    orphan_penalty = orphan_ratio * 30
    # Max 20% penalty
    stale_penalty = stale_ratio * 20

    max(0, base_score - orphan_penalty - stale_penalty)
    |> Float.round(1)
  end

  defp calculate_health_score(_, _, _), do: 0.0

  defp check_database_readable do
    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query("SELECT 1", [], db_path: @smriti_db_path) do
      {:ok, [[1]]} -> true
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp check_fts_functional do
    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query("SELECT COUNT(*) FROM holons_fts", [],
           db_path: @smriti_db_path
         ) do
      {:ok, [[_count]]} -> true
      {:ok, _} -> false
      {:error, _} -> false
    end
  end

  defp run_cli_command(args) do
    full_args = ["fsi", @cli_script | args]

    case System.cmd("dotnet", full_args, stderr_to_stdout: true, env: get_env()) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {:exit_code, code, output}}
    end
  end

  defp get_env do
    case System.get_env("OPENROUTER_API_KEY") do
      nil -> []
      key -> [{"OPENROUTER_API_KEY", key}]
    end
  end
end
