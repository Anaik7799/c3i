defmodule Indrajaal.MCP.Domains.Analytics.Handler do
  @moduledoc """
  MCP Handler for Analytics Domain

  WHAT: Handles DuckDB-backed analytics queries for event history,
        holon evolution data, alarm trends, and device metrics.
  WHY: Provides AI access to OLAP analytics via DuckDB columnar engine
       for real-time insights without PostgreSQL overhead.
  CONSTRAINTS: SC-MCP-070, SC-MCP-071, SC-CONC-001, AOR-HOLON-007

  ## Tools Provided
  - indrajaal.analytics.query         - Execute raw analytics SQL against DuckDB
  - indrajaal.analytics.alarms.trend  - Alarm trend analysis over a time window
  - indrajaal.analytics.devices.health - Device health histogram from event history
  - indrajaal.analytics.summary       - High-level system analytics summary

  ## STAMP Constraints
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-CONC-001: DuckDB connection management — open/close per query
  - AOR-HOLON-007: Use DuckDB for all holon analytics queries

  ## Change History
  | Version | Date       | Author            | Change             |
  |---------|------------|-------------------|--------------------|
  | 21.3.0  | 2026-03-23 | Claude Sonnet 4.6 | Wire real DuckDB pipeline |
  """

  use Indrajaal.MCP.Domains.Handler, domain: :analytics

  alias Indrajaal.Analytics.DuckdbBackend
  alias Indrajaal.MCP.Foundation.Types

  require Logger

  # Default DuckDB database path (holon history)
  @default_db_path "data/holons/analytics.duckdb"

  @impl true
  def handle(:query, args, context) do
    audit_log(@domain, :query, args, context)

    with :ok <- validate_required(args, [:sql]) do
      sql = Map.get(args, "sql") || Map.get(args, :sql)
      db_path = Map.get(args, "db_path", @default_db_path)

      # Reject mutations — analytics handler is read-only
      sql_upper = String.upcase(String.trim(sql))

      if String.starts_with?(sql_upper, ["SELECT", "WITH", "EXPLAIN", "DESCRIBE", "SHOW"]) do
        case DuckdbBackend.query(db_path, sql) do
          {:ok, rows} ->
            success(%{
              rows: rows,
              row_count: length(rows),
              db_path: db_path
            })

          {:error, :duckdb_not_available} ->
            error("DuckDB NIF not available — ensure duckdbex is compiled")

          {:error, reason} ->
            Logger.warning("[Analytics.Handler] DuckDB query failed: #{inspect(reason)}")
            error("Analytics query failed: #{inspect(reason)}")
        end
      else
        error("Only SELECT/WITH/EXPLAIN queries are permitted in analytics handler")
      end
    end
  end

  @impl true
  def handle(:alarms_trend, args, context) do
    audit_log(@domain, :alarms_trend, args, context)

    window_hours = Map.get(args, "window_hours", 24)
    db_path = Map.get(args, "db_path", @default_db_path)

    sql = """
    SELECT
      DATE_TRUNC('hour', triggered_at) AS hour_bucket,
      event_type,
      severity,
      COUNT(*) AS alarm_count,
      COUNT(CASE WHEN state = 'acknowledged' THEN 1 END) AS acknowledged_count,
      COUNT(CASE WHEN state = 'resolved' THEN 1 END) AS resolved_count,
      AVG(EPOCH(resolved_at) - EPOCH(triggered_at)) AS avg_response_seconds
    FROM alarm_events
    WHERE triggered_at >= NOW() - INTERVAL '#{window_hours} hours'
    GROUP BY 1, 2, 3
    ORDER BY 1 DESC, 4 DESC
    """

    case DuckdbBackend.query(db_path, sql) do
      {:ok, rows} ->
        success(%{
          trend: rows,
          window_hours: window_hours,
          total_buckets: length(rows),
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, :duckdb_not_available} ->
        # Graceful degradation: return empty trend with metadata
        success(%{
          trend: [],
          window_hours: window_hours,
          total_buckets: 0,
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          note: "DuckDB not available — no historical data"
        })

      {:error, reason} ->
        Logger.warning("[Analytics.Handler] Alarm trend query failed: #{inspect(reason)}")
        error("Alarm trend query failed: #{inspect(reason)}")
    end
  end

  @impl true
  def handle(:devices_health, args, context) do
    audit_log(@domain, :devices_health, args, context)

    db_path = Map.get(args, "db_path", @default_db_path)
    limit = Map.get(args, "limit", 50)

    sql = """
    SELECT
      device_id,
      device_type,
      COUNT(*) AS total_events,
      COUNT(CASE WHEN event_type = 'fault' THEN 1 END) AS fault_count,
      COUNT(CASE WHEN event_type = 'online' THEN 1 END) AS online_count,
      COUNT(CASE WHEN event_type = 'offline' THEN 1 END) AS offline_count,
      MAX(recorded_at) AS last_seen,
      (1.0 - (COUNT(CASE WHEN event_type = 'fault' THEN 1 END) * 1.0 / GREATEST(COUNT(*), 1))) AS health_score
    FROM device_events
    WHERE recorded_at >= NOW() - INTERVAL '7 days'
    GROUP BY device_id, device_type
    ORDER BY health_score ASC
    LIMIT #{limit}
    """

    case DuckdbBackend.query(db_path, sql) do
      {:ok, rows} ->
        success(%{
          devices: rows,
          total: length(rows),
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, :duckdb_not_available} ->
        success(%{
          devices: [],
          total: 0,
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          note: "DuckDB not available — no historical data"
        })

      {:error, reason} ->
        Logger.warning("[Analytics.Handler] Device health query failed: #{inspect(reason)}")
        error("Device health query failed: #{inspect(reason)}")
    end
  end

  @impl true
  def handle(:summary, args, context) do
    audit_log(@domain, :summary, args, context)

    db_path = Map.get(args, "db_path", @default_db_path)

    # Execute summary queries — aggregate counts across key tables
    alarm_sql =
      "SELECT COUNT(*) AS total FROM alarm_events WHERE triggered_at >= NOW() - INTERVAL '24 hours'"

    device_sql =
      "SELECT COUNT(DISTINCT device_id) AS total FROM device_events WHERE recorded_at >= NOW() - INTERVAL '24 hours'"

    alarm_count =
      case DuckdbBackend.query(db_path, alarm_sql) do
        {:ok, [%{total: count} | _]} -> count
        {:ok, [row | _]} -> Map.get(row, :total, 0)
        _ -> 0
      end

    device_count =
      case DuckdbBackend.query(db_path, device_sql) do
        {:ok, [%{total: count} | _]} -> count
        {:ok, [row | _]} -> Map.get(row, :total, 0)
        _ -> 0
      end

    success(%{
      summary: %{
        alarms_24h: alarm_count,
        active_devices_24h: device_count
      },
      db_path: db_path,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @impl true
  def handle(action, args, context) do
    audit_log(@domain, action, args, context)
    not_implemented(action)
  end

  @doc """
  Returns tool schemas for registration.
  """
  @impl Indrajaal.MCP.Domains.Handler
  def list_tools do
    namespace = "indrajaal.analytics"

    [
      Types.new_tool_schema(
        "#{namespace}.query",
        "Execute a read-only SQL query against the DuckDB analytics store",
        %{
          type: "object",
          properties: %{
            "sql" => %{
              type: "string",
              description: "SQL SELECT/WITH/EXPLAIN query to execute"
            },
            "db_path" => %{
              type: "string",
              description: "Path to DuckDB database file (default: data/holons/analytics.duckdb)"
            }
          },
          required: ["sql"]
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.alarms.trend",
        "Get alarm trend analysis over a time window from DuckDB history",
        %{
          type: "object",
          properties: %{
            "window_hours" => %{
              type: "integer",
              description: "Look-back window in hours (default: 24)"
            },
            "db_path" => %{type: "string", description: "DuckDB database path"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.devices.health",
        "Get device health histogram from event history (7-day window)",
        %{
          type: "object",
          properties: %{
            "limit" => %{
              type: "integer",
              description: "Maximum devices to return (default: 50)"
            },
            "db_path" => %{type: "string", description: "DuckDB database path"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.summary",
        "Get high-level analytics summary (24h alarm count, active device count)",
        %{
          type: "object",
          properties: %{
            "db_path" => %{type: "string", description: "DuckDB database path"}
          },
          required: []
        }
      )
    ]
  end
end
