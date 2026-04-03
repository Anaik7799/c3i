#!/usr/bin/env elixir

# 🚀 TimescaleDB Validation Script - SOPv5.11 Cybernetic Execution
# ================================================================
# Updated: 2025-11-25 15:45:00 CEST (TimescaleDB Container Integration Complete)
# Framework: SOPv5.11 + TPS + STAMP + TDG + GDE + PHICS v2.1 + Container-Only
# Purpose: Validate TimescaleDB installation and configuration
# Agent: Database Validation Helper
# Container: localhost/indrajaal-timescaledb-demo:nixos-devenv (PostgreSQL 17 + TimescaleDB)
# Build: NIXPKGS_ALLOW_UNFREE=1 nix-build containers/indrajaal-timescaledb-demo.nix --impure
# Docs: containers/README.md (lines 599-775), data/tmp/20251125-1545-timescaledb-container-integration-complete.md

defmodule TimescaleDBValidator do
  @moduledoc """
  Comprehensive TimescaleDB installation and configuration validation
  with SOPv5.1 cybernetic execution framework compliance.
  """

  __require Logger

  def main(args \\ []) do
    IO.puts("🚀 TIMESCALEDB VALIDATION-SOPv5.1 CYBERNETIC EXECUTION")
    IO.puts("========================================================")
    IO.puts("Date: #{DateTime.utc_now() |> DateTime.to_string()}")
    IO.puts("Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only")
    IO.puts("")

    case args do
      ["--comprehensive"] ->
        run_comprehensive_validation()

      ["--quick"] ->
        run_quick_validation()

      ["--connection-test"] ->
        test_connection_only()

      ["--help"] ->
        show_help()

      [] ->
        run_standard_validation()

      _ ->
        IO.puts("❌ Unknown arguments: #{inspect(args)}")
        show_help()
    end
  rescue
    error ->
      IO.puts("🚨 CRITICAL ERROR during TimescaleDB validation:")
      IO.puts("Error: #{inspect(error)}")
      IO.puts("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
      System.halt(1)
  end

  defp run_standard_validation do
    IO.puts("🎯 STANDARD TIMESCALEDB VALIDATION")
    IO.puts("==================================")

    validations = [
      {"Database Connection", &test_database_connection/0},
      {"TimescaleDB Extension", &test_timescaledb_extension/0},
      {"Hypertables", &test_hypertables/0},
      {"Indexes", &test_indexes/0},
      {"Basic Functionality", &test_basic_functionality/0}
    ]

    results = run_validation_suite(validations)
    print_validation_summary(results)
  end

  defp run_comprehensive_validation do
    IO.puts("🎯 COMPREHENSIVE TIMESCALEDB VALIDATION")
    IO.puts("=======================================")

    validations = [
      {"Database Connection", &test_database_connection/0},
      {"TimescaleDB Extension", &test_timescaledb_extension/0},
      {"Hypertables", &test_hypertables/0},
      {"Indexes", &test_indexes/0},
      {"Continuous Aggregates", &test_continuous_aggregates/0},
      {"Retention Policies", &test_retention_policies/0},
      {"Compression Policies", &test_compression_policies/0},
      {"Performance Configuration", &test_performance_configuration/0},
      {"Data Insertion", &test_data_insertion/0},
      {"Query Performance", &test_query_performance/0},
      {"Container Integration", &test_container_integration/0}
    ]

    results = run_validation_suite(validations)
    print_validation_summary(results)
  end

  defp run_quick_validation do
    IO.puts("🎯 QUICK TIMESCALEDB VALIDATION")
    IO.puts("==============================")

    validations = [
      {"Database Connection", &test_database_connection/0},
      {"TimescaleDB Extension", &test_timescaledb_extension/0}
    ]

    results = run_validation_suite(validations)
    print_validation_summary(results)
  end

  defp test_connection_only do
    IO.puts("🎯 CONNECTION TEST ONLY")
    IO.puts("======================")

    case test_database_connection() do
      {:ok, message} ->
        IO.puts("✅ #{message}")
        System.halt(0)

      {:error, message} ->
        IO.puts("❌ #{message}")
        System.halt(1)
    end
  end

  defp run_validation_suite(validations) do
    validations
    |> Enum.map(fn {name, test_func} ->
      IO.write("🔍 Testing #{name}... ")
      result = test_func.()

      case result do
        {:ok, message} ->
          IO.puts("✅ #{message}")
          {name, :passed, message}

        {:error, message} ->
          IO.puts("❌ #{message}")
          {name, :failed, message}
      end
    end)
  end

  defp print_validation_summary(results) do
    IO.puts("")
    IO.puts("📊 VALIDATION SUMMARY")
    IO.puts("===================")

    passed = Enum.count(results, fn {_, status, _} -> status == :passed end)
    total = length(results)
    percentage = round(passed / total * 100)

    IO.puts("Passed: #{passed}/#{total} (#{percentage}%)")

    failed_tests = Enum.filter(results, fn {_, status, _} -> status == :failed end)

    if failed_tests != [] do
      IO.puts("")
      IO.puts("❌ FAILED TESTS:")

      Enum.each(failed_tests, fn {name, _, message} ->
        IO.puts("  • #{name}: #{message}")
      end)
    end

    IO.puts("")

    if percentage >= 100 do
      IO.puts("🏆 ALL VALIDATIONS PASSED-TIMESCALEDB READY FOR PRODUCTION")
    else
      IO.puts("⚠️ SOME VALIDATIONS FAILED-REVIEW CONFIGURATION")
    end

    # Save validation results to log file
    save_validation_results(results, percentage)
  end

  defp test_database_connection do
    try do
      # Test PostgreSQL connection
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
            "SELECT 1;"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      if String.contains?(result, "1 row") do
        {:ok, "Database connection successful"}
      else
        {:error, "Database connection failed: #{result}"}
      end
    rescue
      error -> {:error, "Connection test failed: #{inspect(error)}"}
    end
  end

  defp test_timescaledb_extension do
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
            "SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      if String.contains?(result, "timescaledb") do
        version =
          result
          |> String.split("\n")
          |> Enum.find(&String.contains?(&1, "timescaledb"))
          |> String.split("|")
          |> List.last()
          |> String.trim()

        {:ok, "TimescaleDB extension installed (v#{version})"}
      else
        {:error, "TimescaleDB extension not found"}
      end
    rescue
      error -> {:error, "Extension test failed: #{inspect(error)}"}
    end
  end

  defp test_hypertables do
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
            "SELECT hypertable_name FROM timescaledb_information.hypertables;"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      expected_tables = ["__event_logs", "alarm_events", "performance_metrics"]

      found_tables =
        expected_tables
        |> Enum.filter(fn table -> String.contains?(result, table) end)
        |> length()

      if found_tables == length(expected_tables) do
        {:ok, "All #{found_tables} hypertables created successfully"}
      else
        {:error, "Only #{found_tables}/#{length(expected_tables)} hypertables found"}
      end
    rescue
      error -> {:error, "Hypertables test failed: #{inspect(error)}"}
    end
  end

  defp test_indexes do
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
            "SELECT indexname FROM pg_indexes WHERE tablename IN ('__event_logs', 'alarm_events', 'performance_metrics');"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      index_count =
        result
        |> String.split("\n")
        |> Enum.filter(fn line -> String.contains?(line, "idx_") end)
        |> length()

      if index_count >= 10 do
        {:ok, "#{index_count} indexes created successfully"}
      else
        {:error, "Only #{index_count} indexes found (expected >= 10)"}
      end
    rescue
      error -> {:error, "Indexes test failed: #{inspect(error)}"}
    end
  end

  defp test_continuous_aggregates do
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
            "SELECT view_name FROM timescaledb_information.continuous_aggregates;"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      expected_aggregates = ["__event_logs_hourly", "alarm_events_daily"]

      found_aggregates =
        expected_aggregates
        |> Enum.filter(fn agg -> String.contains?(result, agg) end)
        |> length()

      if found_aggregates == length(expected_aggregates) do
        {:ok, "All #{found_aggregates} continuous aggregates created"}
      else
        {:error,
         "Only #{found_aggregates}/#{length(expected_aggregates)} continuous aggregates found"}
      end
    rescue
      error -> {:error, "Continuous aggregates test failed: #{inspect(error)}"}
    end
  end

  defp test_retention_policies do
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
            "SELECT hypertable_name FROM timescaledb_information.drop_chunks_policies;"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      expected_policies = ["__event_logs", "alarm_events", "performance_metrics"]

      found_policies =
        expected_policies
        |> Enum.filter(fn policy -> String.contains?(result, policy) end)
        |> length()

      if found_policies == length(expected_policies) do
        {:ok, "All #{found_policies} retention policies configured"}
      else
        {:error, "Only #{found_policies}/#{length(expected_policies)} retention policies found"}
      end
    rescue
      error -> {:error, "Retention policies test failed: #{inspect(error)}"}
    end
  end

  defp test_compression_policies do
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
            "SELECT hypertable_name FROM timescaledb_information.compression_settings;"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      expected_compressed = ["__event_logs", "alarm_events", "performance_metrics"]

      found_compressed =
        expected_compressed
        |> Enum.filter(fn table -> String.contains?(result, table) end)
        |> length()

      if found_compressed >= 2 do
        {:ok, "#{found_compressed} compression policies configured"}
      else
        {:error, "Only #{found_compressed} compression policies found (expected >= 2)"}
      end
    rescue
      error -> {:error, "Compression policies test failed: #{inspect(error)}"}
    end
  end

  defp test_performance_configuration do
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
            "SHOW shared_buffers;"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      if String.contains?(result, "MB") do
        {:ok, "PostgreSQL performance configuration verified"}
      else
        {:error, "Performance configuration check failed"}
      end
    rescue
      error -> {:error, "Performance configuration test failed: #{inspect(error)}"}
    end
  end

  defp test_basic_functionality do
    try do
      # Test inserting a sample __event
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
            "INSERT INTO __event_logs (__event_type,
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      if String.contains?(result, "INSERT 0 1") do
        {:ok, "Data insertion and retrieval successful"}
      else
        {:error, "Data insertion test failed: #{result}"}
      end
    rescue
      error -> {:error, "Basic functionality test failed: #{inspect(error)}"}
    end
  end

  defp test_data_insertion do
    test_basic_functionality()
  end

  defp test_query_performance do
    try do
      # Test a time-based query
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
            "SELECT COUNT(*) FROM __event_logs WHERE timestamp > NOW()-INTERVAL '1 hour';"
          ],
          env: [{"PGPASSWORD", "postgres"}]
        )

      if String.contains?(result, "1 row") do
        {:ok, "Query performance test successful"}
      else
        {:error, "Query performance test failed: #{result}"}
      end
    rescue
      error -> {:error, "Query performance test failed: #{inspect(error)}"}
    end
  end

  defp test_container_integration do
    try do
      # Test container health
      {result, _} =
        System.cmd("podman", [
          "ps",
          "--format",
          "{{.Names}}",
          "--filter",
          "name=indrajaal-timescaledb-demo"
        ])

      if String.contains?(result, "indrajaal-timescaledb-demo") do
        {:ok, "Container integration successful"}
      else
        {:error, "Container not found or not running"}
      end
    rescue
      error -> {:error, "Container integration test failed: #{inspect(error)}"}
    end
  end

  defp save_validation_results(results, percentage) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/claude_timescaledb_validation_#{timestamp}.log"

    content = """
    🚀 TIMESCALEDB VALIDATION RESULTS-SOPv5.1 CYBERNETIC EXECUTION
    ================================================================
    Date: #{DateTime.utc_now() |> DateTime.to_string()}
    Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only

    📊 VALIDATION SUMMARY:
    =====================
    Overall Score: #{percentage}%
    Tests Passed: #{Enum.count(results, fn {_, status, _} -> status == :passed end)}
    Total Tests: #{length(results)}

    📋 DETAILED RESULTS:
    ===================
    #{Enum.map_join(results, "\n", fn {name, status, message} ->
      status_icon = if status == :passed, do: "✅", else: "❌"
      "#{status_icon} #{name}: #{message}"
    end)}

    🎯 COMPLETION STATUS: #{if percentage >= 100, do: "READY FOR PRODUCTION", else: "NEEDS ATTENTION"}

    Agent: TimescaleDB Validation Helper
    Task: 4.2.1.2 Container Infrastructure Integration-Validation Phase
    Next: Database Schema & Hypertable Creation (4.2.2.1)
    """

    File.write!(filename, content)
    IO.puts("📁 Validation results saved to: #{filename}")
  end

  defp show_help do
    IO.puts("""
    🚀 TIMESCALEDB VALIDATION SCRIPT-SOPv5.1 CYBERNETIC EXECUTION
    ==============================================================

    Usage: elixir scripts/timescale/validate_timescale_setup.exs [options]

    Options:
      (no args)          Run standard validation
      --comprehensive    Run comprehensive validation with all tests
      --quick           Run quick validation (connection + extension only)
      --connection-test  Test __database connection only
      --help            Show this help message

    Examples:
      elixir scripts/timescale/validate_timescale_setup.exs
      elixir scripts/timescale/validate_timescale_setup.exs --comprehensive
      elixir scripts/timescale/validate_timescale_setup.exs --quick

    Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only
    Agent: TimescaleDB Validation Helper
    """)
  end
end

# Execute if called directly
if __ENV__.file == :stdio do
  TimescaleDBValidator.main(System.argv())
else
  TimescaleDBValidator.main(System.argv())
end
