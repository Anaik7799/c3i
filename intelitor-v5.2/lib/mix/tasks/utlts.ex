defmodule Mix.Tasks.Utlts do
  @moduledoc """
  UTLTS (Unified Test Lifecycle Tracking System) query and reporting task.

  ## Usage

      mix utlts                          # Dashboard summary
      mix utlts dashboard                # Dashboard summary (explicit)
      mix utlts flaky                    # List flaky tests
      mix utlts failures                 # Recent failures
      mix utlts history [project_id]     # Run history for a project
      mix utlts coverage                 # Coverage trend
      mix utlts stamp                    # STAMP constraint coverage
      mix utlts runtimes                 # Cross-runtime summary
      mix utlts stats                    # Database statistics
      mix utlts export [format]          # Export to JSON/CSV

  ## Constraints
  - SC-UTLTS-010: Query interface for UTLTS data
  - AOR-HOLON-009: SQLite is authoritative source

  ## Change History
  | Version | Date       | Author      | Change                    |
  |---------|------------|-------------|---------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial implementation    |
  """

  use Mix.Task

  @shortdoc "Query and report on UTLTS test lifecycle data"

  @db_path "data/holons/test/utlts.db"

  @impl Mix.Task
  def run(args) do
    command = List.first(args, "dashboard")
    rest = Enum.drop(args, 1)

    unless File.exists?(@db_path) do
      Mix.shell().error("UTLTS database not found at #{@db_path}")
      Mix.shell().info("Run tests first to initialize the database.")
      System.halt(1)
    end

    case command do
      "dashboard" -> dashboard()
      "flaky" -> flaky()
      "failures" -> failures()
      "history" -> history(rest)
      "coverage" -> coverage()
      "stamp" -> stamp_coverage()
      "runtimes" -> runtimes()
      "stats" -> stats()
      "export" -> export(rest)
      _ -> Mix.shell().error("Unknown command: #{command}. Run `mix help utlts` for usage.")
    end
  end

  defp dashboard do
    with_db(fn db ->
      header("UTLTS Dashboard")

      # Recent runs
      rows =
        query(db, """
          SELECT tp.name, tp.runtime, tr.status, tr.started_at,
                 tr.duration_ms, tr.total_tests, tr.passed, tr.failed, tr.skipped,
                 tr.git_branch
          FROM test_runs tr
          JOIN test_projects tp ON tr.project_id = tp.id
          ORDER BY tr.started_at DESC
          LIMIT 15
        """)

      table(
        [
          "Project",
          "Runtime",
          "Status",
          "Started",
          "Duration",
          "Total",
          "Pass",
          "Fail",
          "Skip",
          "Branch"
        ],
        rows
      )

      # Summary stats
      [totals] =
        query(db, """
          SELECT COUNT(*) AS runs,
                 SUM(total_tests) AS tests,
                 SUM(passed) AS passed,
                 SUM(failed) AS failed,
                 ROUND(AVG(duration_ms)) AS avg_ms
          FROM test_runs
          WHERE started_at > datetime('now', '-7 days')
        """)

      Mix.shell().info(
        "\n  Last 7 days: #{Enum.at(totals, 0)} runs, #{Enum.at(totals, 1) || 0} tests, " <>
          "#{Enum.at(totals, 2) || 0} passed, #{Enum.at(totals, 3) || 0} failed, avg #{Enum.at(totals, 4) || 0}ms"
      )
    end)
  end

  defp flaky do
    with_db(fn db ->
      header("Flaky Tests")

      rows =
        query(db, """
          SELECT td.full_name, ts.runtime, fa.flaky_score, fa.flip_rate,
                 fa.total_runs, fa.pass_count, fa.fail_count,
                 ROUND(fa.avg_duration_ms, 1),
                 CASE WHEN fa.quarantined = 1 THEN 'YES' ELSE 'no' END
          FROM flaky_analysis fa
          JOIN test_definitions td ON fa.definition_id = td.id
          JOIN test_suites ts ON td.suite_id = ts.id
          WHERE fa.is_flaky = 1
          ORDER BY fa.flaky_score DESC
          LIMIT 30
        """)

      if rows == [] do
        Mix.shell().info("  No flaky tests detected (need >= 3 runs for analysis)")
      else
        table(
          ["Test", "Runtime", "Score", "FlipRate", "Runs", "Pass", "Fail", "AvgMs", "Quarantine"],
          rows
        )
      end
    end)
  end

  defp failures do
    with_db(fn db ->
      header("Recent Failures (last 50)")

      rows =
        query(db, """
          SELECT td.full_name, ts.runtime, tr.git_branch,
                 tres.failure_type, SUBSTR(tres.failure_message, 1, 80),
                 tres.duration_us, tres.started_at
          FROM test_results tres
          JOIN test_runs tr ON tres.run_id = tr.id
          JOIN test_definitions td ON tres.definition_id = td.id
          JOIN test_suites ts ON td.suite_id = ts.id
          WHERE tres.status = 'failed'
          ORDER BY tres.started_at DESC
          LIMIT 50
        """)

      if rows == [] do
        Mix.shell().info("  No failures recorded")
      else
        table(["Test", "Runtime", "Branch", "Type", "Message", "Duration(us)", "Time"], rows)
      end
    end)
  end

  defp history(args) do
    project = List.first(args, "proj-elixir-main")

    with_db(fn db ->
      header("Run History: #{project}")

      rows =
        query(db, """
          SELECT tr.id, tr.status, tr.started_at, tr.duration_ms,
                 tr.total_tests, tr.passed, tr.failed, tr.skipped,
                 tr.git_branch, SUBSTR(tr.git_commit, 1, 8)
          FROM test_runs tr
          WHERE tr.project_id = '#{project}'
          ORDER BY tr.started_at DESC
          LIMIT 25
        """)

      table(
        [
          "RunID",
          "Status",
          "Started",
          "Duration",
          "Total",
          "Pass",
          "Fail",
          "Skip",
          "Branch",
          "Commit"
        ],
        rows
      )
    end)
  end

  defp coverage do
    with_db(fn db ->
      header("Coverage Trend")

      rows =
        query(db, """
          SELECT tr.started_at, tp.runtime,
                 COUNT(DISTINCT cd.module_name) AS modules,
                 ROUND(AVG(CAST(cd.lines_covered AS REAL) / NULLIF(cd.lines_total, 0) * 100), 1) AS avg_coverage,
                 SUM(cd.lines_total) AS total_lines,
                 SUM(cd.lines_covered) AS covered_lines
          FROM coverage_data cd
          JOIN test_runs tr ON cd.run_id = tr.id
          JOIN test_projects tp ON tr.project_id = tp.id
          GROUP BY tr.id, tr.started_at, tp.runtime
          ORDER BY tr.started_at DESC
          LIMIT 20
        """)

      if rows == [] do
        Mix.shell().info("  No coverage data recorded yet")
        Mix.shell().info("  Run `mix test --cover` with UTLTSFormatter enabled to populate")
      else
        table(["Started", "Runtime", "Modules", "AvgCov%", "TotalLines", "CoveredLines"], rows)
      end
    end)
  end

  defp stamp_coverage do
    with_db(fn db ->
      header("STAMP Constraint → Test Coverage")

      rows =
        query(db, """
          SELECT tc.constraint_id, tc.constraint_type, tc.severity,
                 COUNT(DISTINCT tc.definition_id) AS test_count,
                 GROUP_CONCAT(DISTINCT ts.runtime) AS runtimes
          FROM test_constraints tc
          JOIN test_definitions td ON tc.definition_id = td.id
          JOIN test_suites ts ON td.suite_id = ts.id
          GROUP BY tc.constraint_id, tc.constraint_type, tc.severity
          ORDER BY tc.severity, tc.constraint_id
          LIMIT 50
        """)

      if rows == [] do
        Mix.shell().info("  No STAMP constraint mappings recorded yet")
        Mix.shell().info("  Add @tag stamp: \"SC-XXX-001\" to tests to populate")
      else
        table(["Constraint", "Type", "Severity", "Tests", "Runtimes"], rows)
      end
    end)
  end

  defp runtimes do
    with_db(fn db ->
      header("Cross-Runtime Summary")

      rows =
        query(db, """
          SELECT tp.name, tp.runtime, tp.framework,
                 COUNT(DISTINCT ts.id) AS suites,
                 COUNT(DISTINCT td.id) AS tests,
                 COUNT(DISTINCT CASE WHEN td.test_type = 'property' THEN td.id END) AS properties
          FROM test_projects tp
          LEFT JOIN test_suites ts ON tp.id = ts.project_id
          LEFT JOIN test_definitions td ON ts.id = td.suite_id
          GROUP BY tp.id, tp.name, tp.runtime, tp.framework
        """)

      table(["Project", "Runtime", "Framework", "Suites", "Tests", "Properties"], rows)
    end)
  end

  defp stats do
    with_db(fn db ->
      header("UTLTS Database Statistics")

      tables =
        ~w[test_projects test_environments test_runs test_suites test_definitions test_results test_metrics test_logs test_constraints run_metrics run_artifacts coverage_data flaky_analysis]

      Enum.each(tables, fn t ->
        [[count]] = query(db, "SELECT COUNT(*) FROM #{t}")
        Mix.shell().info("  #{String.pad_trailing(t, 25)} #{count}")
      end)

      # DB file size
      size = File.stat!(@db_path).size
      Mix.shell().info("\n  Database size: #{format_bytes(size)}")
      Mix.shell().info("  Database path: #{@db_path}")

      # Schema version
      [[version]] =
        query(db, "SELECT version FROM schema_versions ORDER BY applied_at DESC LIMIT 1")

      Mix.shell().info("  Schema version: #{version}")
    end)
  end

  defp export(args) do
    format = List.first(args, "json")

    with_db(fn db ->
      case format do
        "json" ->
          runs = query(db, "SELECT * FROM v_dashboard_summary LIMIT 100")
          json = Jason.encode!(runs, pretty: true)
          path = "data/tmp/utlts_export_#{date_stamp()}.json"
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, json)
          Mix.shell().info("Exported to #{path}")

        "csv" ->
          rows =
            query(db, """
              SELECT td.full_name, ts.runtime, ts.domain, ts.fractal_layer,
                     tres.status, tres.duration_us, tr.git_branch, tr.started_at
              FROM test_results tres
              JOIN test_definitions td ON tres.definition_id = td.id
              JOIN test_suites ts ON td.suite_id = ts.id
              JOIN test_runs tr ON tres.run_id = tr.id
              ORDER BY tr.started_at DESC
              LIMIT 10000
            """)

          csv =
            "test_name,runtime,domain,layer,status,duration_us,branch,started_at\n" <>
              Enum.map_join(rows, "\n", fn row ->
                Enum.map_join(row, ",", &csv_escape/1)
              end)

          path = "data/tmp/utlts_export_#{date_stamp()}.csv"
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, csv)
          Mix.shell().info("Exported #{length(rows)} results to #{path}")

        other ->
          Mix.shell().error("Unknown format: #{other}. Use 'json' or 'csv'.")
      end
    end)
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp with_db(fun) do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    Exqlite.Sqlite3.execute(db, "PRAGMA journal_mode = WAL")

    try do
      fun.(db)
    after
      Exqlite.Sqlite3.close(db)
    end
  end

  defp query(db, sql) do
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
    rows = collect_rows(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    rows
  end

  defp collect_rows(db, stmt) do
    case Exqlite.Sqlite3.step(db, stmt) do
      {:row, row} -> [row | collect_rows(db, stmt)]
      :done -> []
    end
  end

  defp header(title) do
    Mix.shell().info("")
    Mix.shell().info("  ╔═══════════════════════════════════════════════════╗")
    Mix.shell().info("  ║  #{String.pad_trailing(title, 47)} ║")
    Mix.shell().info("  ╚═══════════════════════════════════════════════════╝")
    Mix.shell().info("")
  end

  defp table(headers, rows) do
    # Calculate column widths
    all_rows = [headers | Enum.map(rows, fn row -> Enum.map(row, &to_string_safe/1) end)]

    widths =
      Enum.map(0..(length(headers) - 1), fn i ->
        all_rows
        |> Enum.map(fn row -> String.length(Enum.at(row, i, "") |> to_string_safe()) end)
        |> Enum.max()
        |> min(50)
      end)

    # Print header
    header_line =
      headers
      |> Enum.zip(widths)
      |> Enum.map_join(" │ ", fn {h, w} -> String.pad_trailing(h, w) end)

    separator =
      widths
      |> Enum.map_join("─┼─", fn w -> String.duplicate("─", w) end)

    Mix.shell().info("  #{header_line}")
    Mix.shell().info("  #{separator}")

    # Print rows
    Enum.each(rows, fn row ->
      line =
        row
        |> Enum.map(&to_string_safe/1)
        |> Enum.zip(widths)
        |> Enum.map_join(" │ ", fn {v, w} ->
          String.slice(v, 0, w) |> String.pad_trailing(w)
        end)

      Mix.shell().info("  #{line}")
    end)

    Mix.shell().info("  (#{length(rows)} rows)")
  end

  defp to_string_safe(nil), do: ""
  defp to_string_safe(val) when is_binary(val), do: val
  defp to_string_safe(val), do: to_string(val)

  defp csv_escape(nil), do: ""

  defp csv_escape(val) when is_binary(val) do
    if String.contains?(val, [",", "\"", "\n"]) do
      "\"#{String.replace(val, "\"", "\"\"")}\""
    else
      val
    end
  end

  defp csv_escape(val), do: to_string(val)

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp date_stamp, do: DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
end
