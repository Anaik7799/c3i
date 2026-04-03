#!/usr/bin/env elixir

# 🚀 TimescaleDB Hypertables Creation Script - SOPv5.1 Cybernetic Execution
# ===========================================================================
# Date: 2025-08-09 09:53:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only
# Purpose: Create and manage TimescaleDB hypertables for time-series __data
# Agent: Database Schema Creator

defmodule TimescaleDBHypertables do
  @moduledoc """
  Comprehensive TimescaleDB hypertables creation and management
  with SOPv5.1 cybernetic execution framework compliance.
  """

  __require Logger

  @spec main(term()) :: any()
  def main(args \\ []) do
    IO.puts("🚀 TIMESCALEDB HYPERTABLES CREATION - SOPv5.1 CYBERNETIC EXECUTION")
    IO.puts("===================================================================")
    IO.puts("Date: #{DateTime.utc_now() |> DateTime.to_string()}")
    IO.puts("Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only")
    IO.puts("")

    case args do
      ["--create-all"] ->
        create_all_hypertables()

      ["--validate"] ->
        validate_hypertables()

      ["--recreate"] ->
        recreate_hypertables()

      ["--drop-all"] ->
        drop_all_hypertables()

      ["--info"] ->
        show_hypertables_info()

      ["--help"] ->
        show_help()

      [] ->
        create_all_hypertables()

      _ ->
        IO.puts("❌ Unknown arguments: #{inspect(args)}")
        show_help()
    end
  rescue
    error ->
      IO.puts("🚨 CRITICAL ERROR during hypertables operation:")
      IO.puts("Error: #{inspect(error)}")
      IO.puts("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
      System.halt(1)
  end

  defp create_all_hypertables do
    IO.puts("🎯 CREATING ALL TIMESCALEDB HYPERTABLES")
    IO.puts("======================================")

    hypertables = [
      {"__event_logs", "1 day", "Main __event logging hypertable"},
      {"alarm_events", "1 hour", "Alarm __event tracking hypertable"},
      {"performance_metrics", "1 hour", "Performance metrics hypertable"},
      {"audit_logs", "1 day", "Audit trail hypertable"},
      {"__user_activities", "1 day", "User activity tracking hypertable"}
    ]

    results =
      hypertables
      |> Enum.map(fn {table, interval, description} ->
        create_hypertable(table, interval, description)
      end)

    summarize_creation_results(results)
  end

  defp create_hypertable(table_name, chunk_interval, description) do
    IO.write("🔧 Creating hypertable #{table_name} (#{chunk_interval})... ")

    try do
      # First, create the table if it doesn't exist
      create_table_sql = get_table_creation_sql(table_name)

      if create_table_sql do
        {_result, _} =
          System.cmd(
            "psql",
            [
              "-h",
              "localhost",
              "-p",
              "5433",
              "-U",
              "postgres",
              "-d",
              "indrajaal_demo",
              "-c",
              create_table_sql
            ],
            env: [{"PGPASSWORD", "postgres"}]
          )
      end

      # Create hypertable
      hypertable_sql = """
      SELECT create_hypertable('#{table_name}', 'timestamp',
        chunk_time_interval => INTERVAL '#{chunk_interval}',
        create_default_indexes => false,
        if_not_exists => true
      );
      """

      {result, _} =
        System.cmd(
          "psql",
          [
            "-h",
            "localhost",
            "-p",
            "5433",
            "-U",
            "postgres",
            "-d",
            "indrajaal_demo",
            "-c",
            hypertable_sql
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      if String.contains?(result, "created") or String.contains?(result, "already") do
        IO.puts("✅ Success")
        {table_name, :success, description}
      else
        IO.puts("❌ Failed: #{result}")
        {table_name, :error, result}
      end
    rescue
      error ->
        IO.puts("❌ Error: #{inspect(error)}")
        {table_name, :error, inspect(error)}
    end
  end

  defp get_table_creation_sql("__event_logs") do
    """
    CREATE TABLE IF NOT EXISTS __event_logs (
      id BIGSERIAL,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      __event_type VARCHAR(100) NOT NULL,
      __event_source VARCHAR(100) NOT NULL,
      __tenant_id UUID NOT NULL,
      __user_id UUID,
      resource_type VARCHAR(100),
      resource_id UUID,
      action VARCHAR(100),
      status VARCHAR(50),
      metadata JSONB DEFAULT '{}',
      duration_ms INTEGER,
      ip_address INET,
      __user_agent TEXT,
      correlation_id UUID,
      trace_id VARCHAR(64),
      span_id VARCHAR(16),
      severity VARCHAR(20) DEFAULT 'info',
      message TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    """
  end

  defp get_table_creation_sql("alarm_events") do
    """
    CREATE TABLE IF NOT EXISTS alarm_events (
      id BIGSERIAL,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      __tenant_id UUID NOT NULL,
      alarm_id UUID NOT NULL,
      device_id UUID,
      site_id UUID,
      alarm_type VARCHAR(100) NOT NULL,
      severity VARCHAR(20) NOT NULL,
      status VARCHAR(50) NOT NULL,
      acknowledged BOOLEAN DEFAULT false,
      acknowledged_by UUID,
      acknowledged_at TIMESTAMPTZ,
      resolved BOOLEAN DEFAULT false,
      resolved_by UUID,
      resolved_at TIMESTAMPTZ,
      escalated BOOLEAN DEFAULT false,
      escalation_level INTEGER DEFAULT 0,
      message TEXT,
      metadata JSONB DEFAULT '{}',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    """
  end

  defp get_table_creation_sql("performance_metrics") do
    """
    CREATE TABLE IF NOT EXISTS performance_metrics (
      id BIGSERIAL,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      __tenant_id UUID NOT NULL,
      metric_name VARCHAR(100) NOT NULL,
      metric_type VARCHAR(50) NOT NULL,
      value DOUBLE PRECISION NOT NULL,
      unit VARCHAR(20),
      labels JSONB DEFAULT '{}',
      source VARCHAR(100),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    """
  end

  defp get_table_creation_sql("audit_logs") do
    """
    CREATE TABLE IF NOT EXISTS audit_logs (
      id BIGSERIAL,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      __tenant_id UUID NOT NULL,
      __user_id UUID,
      session_id UUID,
      action VARCHAR(100) NOT NULL,
      resource_type VARCHAR(100),
      resource_id UUID,
      old_values JSONB,
      new_values JSONB,
      ip_address INET,
      __user_agent TEXT,
      result VARCHAR(50),
      error_message TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    """
  end

  defp get_table_creation_sql("user_activities") do
    """
    CREATE TABLE IF NOT EXISTS __user_activities (
      id BIGSERIAL,
      timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      __tenant_id UUID NOT NULL,
      __user_id UUID NOT NULL,
      session_id UUID,
      activity_type VARCHAR(100) NOT NULL,
      page_path VARCHAR(500),
      duration_ms INTEGER,
      metadata JSONB DEFAULT '{}',
      ip_address INET,
      __user_agent TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    """
  end

  defp get_table_creation_sql(_), do: nil

  defp validate_hypertables do
    IO.puts("🎯 VALIDATING TIMESCALEDB HYPERTABLES")
    IO.puts("====================================")

    try do
      {result, _} =
        System.cmd(
          "psql",
          [
            "-h",
            "localhost",
            "-p",
            "5433",
            "-U",
            "postgres",
            "-d",
            "indrajaal_demo",
            "-c",
            """
            SELECT
              hypertable_name,
              num_chunks,
              compression_enabled,
              replication_factor,
              __data_nodes
            FROM timescaledb_information.hypertables
            ORDER BY hypertable_name;
            """
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      IO.puts("📋 HYPERTABLES STATUS:")
      IO.puts("=====================")
      IO.puts(result)

      # Count hypertables
      hypertable_count =
        result
        |> String.split("\n")
        |> Enum.filter(fn line -> String.contains?(line, "_") end)
        |> length()

      IO.puts("📊 SUMMARY: #{hypertable_count} hypertables found")

      if hypertable_count >= 3 do
        IO.puts("✅ Hypertables validation successful")
      else
        IO.puts("⚠️ Expected at least 3 hypertables, found #{hypertable_count}")
      end
    rescue
      error ->
        IO.puts("❌ Validation failed: #{inspect(error)}")
    end
  end

  defp recreate_hypertables do
    IO.puts("🎯 RECREATING ALL TIMESCALEDB HYPERTABLES")
    IO.puts("========================================")
    IO.puts("⚠️  WARNING: This will drop all existing hypertables and __data!")
    IO.puts("Press Ctrl+C to cancel or wait 5 seconds to continue...")
    Process.sleep(5000)

    drop_all_hypertables()
    create_all_hypertables()
  end

  defp drop_all_hypertables do
    IO.puts("🎯 DROPPING ALL TIMESCALEDB HYPERTABLES")
    IO.puts("======================================")

    hypertables = [
      "__event_logs",
      "alarm_events",
      "performance_metrics",
      "audit_logs",
      "__user_activities"
    ]

    results =
      hypertables
      |> Enum.map(fn table ->
        drop_hypertable(table)
      end)

    summarize_drop_results(results)
  end

  defp drop_hypertable(table_name) do
    IO.write("🗑️  Dropping hypertable #{table_name}... ")

    try do
      {result, _} =
        System.cmd(
          "psql",
          [
            "-h",
            "localhost",
            "-p",
            "5433",
            "-U",
            "postgres",
            "-d",
            "indrajaal_demo",
            "-c",
            "DROP TABLE IF EXISTS #{table_name} CASCADE;"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      if String.contains?(result, "DROP TABLE") do
        IO.puts("✅ Success")
        {table_name, :success, "Dropped successfully"}
      else
        IO.puts("⚠️  Not found or already dropped")
        {table_name, :skipped, "Table not found"}
      end
    rescue
      error ->
        IO.puts("❌ Error: #{inspect(error)}")
        {table_name, :error, inspect(error)}
    end
  end

  defp show_hypertables_info do
    IO.puts("🎯 TIMESCALEDB HYPERTABLES INFORMATION")
    IO.puts("=====================================")

    try do
      {result, _} =
        System.cmd(
          "psql",
          [
            "-h",
            "localhost",
            "-p",
            "5433",
            "-U",
            "postgres",
            "-d",
            "indrajaal_demo",
            "-c",
            """
            SELECT
              h.hypertable_name,
              h.num_chunks,
              h.compression_enabled,
              h.replication_factor,
              pg_size_pretty(pg_total_relation_size(h.hypertable_name::regclass)) as size,
              c.chunk_time_interval
            FROM timescaledb_information.hypertables h
            LEFT JOIN timescaledb_information.dimensions c ON h.hypertable_name = c.hypertable_name
            ORDER BY h.hypertable_name;
            """
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      IO.puts(result)

      # Also show chunk information
      IO.puts("")
      IO.puts("📊 CHUNK INFORMATION:")
      IO.puts("====================")

      {chunk_result, _} =
        System.cmd(
          "psql",
          [
            "-h",
            "localhost",
            "-p",
            "5433",
            "-U",
            "postgres",
            "-d",
            "indrajaal_demo",
            "-c",
            """
            SELECT
              hypertable_name,
              COUNT(*) as chunk_count,
              pg_size_pretty(SUM(pg_total_relation_size(chunk_schema||'.'||chunk_name))) as total_size
            FROM timescaledb_information.chunks
            GROUP BY hypertable_name
            ORDER BY hypertable_name;
            """
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      IO.puts(chunk_result)
    rescue
      error ->
        IO.puts("❌ Information retrieval failed: #{inspect(error)}")
    end
  end

  defp summarize_creation_results(results) do
    IO.puts("")
    IO.puts("📊 HYPERTABLE CREATION SUMMARY")
    IO.puts("=============================")

    successful = Enum.count(results, fn {_, status, _} -> status == :success end)
    total = length(results)

    IO.puts("Created: #{successful}/#{total}")

    failed = Enum.filter(results, fn {_, status, _} -> status == :error end)

    if failed != [] do
      IO.puts("")
      IO.puts("❌ FAILED OPERATIONS:")

      Enum.each(failed, fn {name, _, message} ->
        IO.puts("  • #{name}: #{message}")
      end)
    end

    IO.puts("")

    if successful == total do
      IO.puts("🏆 ALL HYPERTABLES CREATED SUCCESSFULLY")
    else
      IO.puts("⚠️ SOME OPERATIONS FAILED - REVIEW ERRORS ABOVE")
    end

    # Save results
    save_results(results, "creation")
  end

  defp summarize_drop_results(results) do
    IO.puts("")
    IO.puts("📊 HYPERTABLE DROP SUMMARY")
    IO.puts("=========================")

    successful = Enum.count(results, fn {_, status, _} -> status == :success end)
    skipped = Enum.count(results, fn {_, status, _} -> status == :skipped end)
    total = length(results)

    IO.puts("Dropped: #{successful}/#{total}")
    IO.puts("Skipped: #{skipped}/#{total}")

    # Save results
    save_results(results, "drop")
  end

  defp save_results(results, operation) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/claude_timescaledb_hypertables_#{operation}_#{timestamp}.log"

    content = """
    🚀 TIMESCALEDB HYPERTABLES #{String.upcase(operation)} - SOPv5.1 CYBERNETIC EXECUTION
    ================================================================
    Date: #{DateTime.utc_now() |> DateTime.to_string()}
    Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only
    Operation: #{String.upcase(operation)}

    📊 OPERATION SUMMARY:
    ====================
    Total Operations: #{length(results)}
    Successful: #{Enum.count(results, fn {_, status, _} -> status == :success end)}
    Failed: #{Enum.count(results, fn {_, status, _} -> status == :error end)}
    Skipped: #{Enum.count(results, fn {_, status, _} -> status == :skipped end)}

    📋 DETAILED RESULTS:
    ===================
    #{Enum.map_join(results, "\n", fn {name, status, message} ->
      status_icon = case status do
        :success -> "✅"
        :error -> "❌"
        :skipped -> "⚠️"
      end
      "#{status_icon} #{name}: #{message}"
    end)}

    Agent: Database Schema Creator
    Task: 4.2.2.1 Event Logs Hypertable Precise Schema
    Next: Index Strategy & Performance Optimization (4.2.2.2)
    """

    File.write!(filename, content)
    IO.puts("📁 Results saved to: #{filename}")
  end

  defp show_help do
    IO.puts("""
    🚀 TIMESCALEDB HYPERTABLES SCRIPT - SOPv5.1 CYBERNETIC EXECUTION
    ===============================================================

    Usage: elixir scripts/timescale/create_hypertables.exs [options]

    Options:
      (no args)      Create all hypertables
      --create-all   Create all hypertables
      --validate     Validate existing hypertables
      --recreate     Drop and recreate all hypertables (WARNING: DATA LOSS)
      --drop-all     Drop all hypertables (WARNING: DATA LOSS)
      --info         Show detailed hypertables information
      --help         Show this help message

    Examples:
      elixir scripts/timescale/create_hypertables.exs
      elixir scripts/timescale/create_hypertables.exs --validate
      elixir scripts/timescale/create_hypertables.exs --info

    Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only
    Agent: Database Schema Creator
    """)
  end
end

# Execute if called directly
if __ENV__.file == :stdio do
  TimescaleDBHypertables.main(System.argv())
else
  TimescaleDBHypertables.main(System.argv())
end
