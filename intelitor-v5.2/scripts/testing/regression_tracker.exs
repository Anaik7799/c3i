#!/usr/bin/env elixir
# Regression Tracker - SQLite-backed test regression tracking
# Usage: elixir scripts/testing/regression_tracker.exs [init|record_compile|record_tests|record_quality|report]

defmodule RegressionTracker do
  @db_path "data/regression/regression_tracker.db"

  def db_path, do: @db_path

  def init do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)

    statements = [
      """
      CREATE TABLE IF NOT EXISTS regression_runs (
        run_id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        git_sha TEXT,
        git_branch TEXT,
        elixir_version TEXT,
        otp_version TEXT,
        mix_env TEXT DEFAULT 'test',
        hostname TEXT,
        trigger TEXT DEFAULT 'manual'
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS compile_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL REFERENCES regression_runs(run_id),
        status TEXT NOT NULL,
        file_count INTEGER DEFAULT 0,
        warning_count INTEGER DEFAULT 0,
        error_count INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        output_excerpt TEXT,
        warnings_as_errors INTEGER DEFAULT 0,
        recorded_at TEXT NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS test_suites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL REFERENCES regression_runs(run_id),
        suite_name TEXT NOT NULL,
        suite_path TEXT,
        total_tests INTEGER DEFAULT 0,
        passed INTEGER DEFAULT 0,
        failed INTEGER DEFAULT 0,
        skipped INTEGER DEFAULT 0,
        excluded INTEGER DEFAULT 0,
        properties INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        recorded_at TEXT NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS test_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL REFERENCES regression_runs(run_id),
        suite_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        test_count INTEGER DEFAULT 0,
        property_count INTEGER DEFAULT 0,
        passed INTEGER DEFAULT 0,
        failed INTEGER DEFAULT 0,
        skipped INTEGER DEFAULT 0,
        fmea_count INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        recorded_at TEXT NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS test_failures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL REFERENCES regression_runs(run_id),
        suite_name TEXT NOT NULL,
        file_path TEXT,
        test_name TEXT,
        module TEXT,
        failure_type TEXT,
        message TEXT,
        recorded_at TEXT NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS quality_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL REFERENCES regression_runs(run_id),
        gate_name TEXT NOT NULL,
        status TEXT NOT NULL,
        issue_count INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        output_excerpt TEXT,
        recorded_at TEXT NOT NULL
      )
      """,
      """
      CREATE TABLE IF NOT EXISTS run_summary (
        run_id TEXT PRIMARY KEY REFERENCES regression_runs(run_id),
        overall_status TEXT NOT NULL,
        compile_status TEXT,
        test_status TEXT,
        quality_status TEXT,
        total_tests INTEGER DEFAULT 0,
        total_passed INTEGER DEFAULT 0,
        total_failed INTEGER DEFAULT 0,
        total_skipped INTEGER DEFAULT 0,
        total_excluded INTEGER DEFAULT 0,
        total_properties INTEGER DEFAULT 0,
        total_duration_ms INTEGER DEFAULT 0,
        sil6_tests INTEGER DEFAULT 0,
        sil6_passed INTEGER DEFAULT 0,
        sil6_properties INTEGER DEFAULT 0,
        fmea_tests INTEGER DEFAULT 0,
        warning_count INTEGER DEFAULT 0,
        credo_issues INTEGER DEFAULT 0,
        format_status TEXT,
        recorded_at TEXT NOT NULL
      )
      """,
      "CREATE INDEX IF NOT EXISTS idx_test_suites_run ON test_suites(run_id)",
      "CREATE INDEX IF NOT EXISTS idx_test_files_run ON test_files(run_id)",
      "CREATE INDEX IF NOT EXISTS idx_test_failures_run ON test_failures(run_id)",
      "CREATE INDEX IF NOT EXISTS idx_compile_run ON compile_results(run_id)",
      "CREATE INDEX IF NOT EXISTS idx_quality_run ON quality_results(run_id)"
    ]

    Enum.each(statements, fn sql ->
      :ok = Exqlite.Sqlite3.execute(db, sql)
    end)

    Exqlite.Sqlite3.close(db)
    IO.puts("✓ Regression tracker database initialized at #{@db_path}")
  end

  def create_run do
    {git_sha, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true)
    {git_branch, 0} = System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true)
    {hostname, 0} = System.cmd("hostname", [], stderr_to_stdout: true)

    run_id = "REG-#{Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")}-#{String.trim(git_sha)}"
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    elixir_version = System.version()
    otp_version = :erlang.system_info(:otp_release) |> List.to_string()

    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db,
      "INSERT INTO regression_runs (run_id, timestamp, git_sha, git_branch, elixir_version, otp_version, hostname) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)"
    )
    :ok = Exqlite.Sqlite3.bind(db, stmt, [
      run_id, timestamp, String.trim(git_sha), String.trim(git_branch),
      elixir_version, otp_version, String.trim(hostname)
    ])
    :done = Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.close(db)

    IO.puts("✓ Created regression run: #{run_id}")
    run_id
  end

  def record_compile(run_id, status, file_count, warning_count, error_count, duration_ms, output_excerpt, wae) do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db,
      "INSERT INTO compile_results (run_id, status, file_count, warning_count, error_count, duration_ms, output_excerpt, warnings_as_errors, recorded_at) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9)"
    )
    :ok = Exqlite.Sqlite3.bind(db, stmt, [
      run_id, status, file_count, warning_count, error_count, duration_ms,
      String.slice(output_excerpt || "", 0..2000),
      if(wae, do: 1, else: 0),
      DateTime.utc_now() |> DateTime.to_iso8601()
    ])
    :done = Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.close(db)
  end

  def record_test_suite(run_id, suite_name, suite_path, stats) do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db,
      "INSERT INTO test_suites (run_id, suite_name, suite_path, total_tests, passed, failed, skipped, excluded, properties, duration_ms, status, recorded_at) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12)"
    )
    status = if stats.failed == 0, do: "PASS", else: "FAIL"
    :ok = Exqlite.Sqlite3.bind(db, stmt, [
      run_id, suite_name, suite_path,
      stats.total, stats.passed, stats.failed, stats.skipped, stats.excluded, stats.properties,
      stats.duration_ms, status,
      DateTime.utc_now() |> DateTime.to_iso8601()
    ])
    :done = Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.close(db)
  end

  def record_quality(run_id, gate_name, status, issue_count, duration_ms, output_excerpt) do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db,
      "INSERT INTO quality_results (run_id, gate_name, status, issue_count, duration_ms, output_excerpt, recorded_at) VALUES (?1,?2,?3,?4,?5,?6,?7)"
    )
    :ok = Exqlite.Sqlite3.bind(db, stmt, [
      run_id, gate_name, status, issue_count, duration_ms,
      String.slice(output_excerpt || "", 0..2000),
      DateTime.utc_now() |> DateTime.to_iso8601()
    ])
    :done = Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.close(db)
  end

  def record_summary(run_id, summary) do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db,
      """
      INSERT OR REPLACE INTO run_summary (
        run_id, overall_status, compile_status, test_status, quality_status,
        total_tests, total_passed, total_failed, total_skipped, total_excluded,
        total_properties, total_duration_ms, sil6_tests, sil6_passed, sil6_properties,
        fmea_tests, warning_count, credo_issues, format_status, recorded_at
      ) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19,?20)
      """
    )
    :ok = Exqlite.Sqlite3.bind(db, stmt, [
      run_id, summary.overall, summary.compile, summary.test, summary.quality,
      summary.total_tests, summary.total_passed, summary.total_failed,
      summary.total_skipped, summary.total_excluded, summary.total_properties,
      summary.total_duration_ms, summary.sil6_tests, summary.sil6_passed,
      summary.sil6_properties, summary.fmea_tests, summary.warning_count,
      summary.credo_issues, summary.format_status,
      DateTime.utc_now() |> DateTime.to_iso8601()
    ])
    :done = Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.close(db)
  end

  def report(run_id) do
    {:ok, db} = Exqlite.Sqlite3.open(@db_path)

    # Run info
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, "SELECT * FROM regression_runs WHERE run_id = ?1")
    :ok = Exqlite.Sqlite3.bind(db, stmt, [run_id])
    {:row, run_row} = Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)

    # Summary
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, "SELECT * FROM run_summary WHERE run_id = ?1")
    :ok = Exqlite.Sqlite3.bind(db, stmt, [run_id])
    summary_row = case Exqlite.Sqlite3.step(db, stmt) do
      {:row, row} -> row
      :done -> nil
    end
    Exqlite.Sqlite3.release(db, stmt)

    # Compile results
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, "SELECT status, file_count, warning_count, error_count, duration_ms, warnings_as_errors FROM compile_results WHERE run_id = ?1")
    :ok = Exqlite.Sqlite3.bind(db, stmt, [run_id])
    compile_rows = collect_rows(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)

    # Test suites
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, "SELECT suite_name, total_tests, passed, failed, skipped, excluded, properties, duration_ms, status FROM test_suites WHERE run_id = ?1")
    :ok = Exqlite.Sqlite3.bind(db, stmt, [run_id])
    suite_rows = collect_rows(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)

    # Quality gates
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, "SELECT gate_name, status, issue_count, duration_ms FROM quality_results WHERE run_id = ?1")
    :ok = Exqlite.Sqlite3.bind(db, stmt, [run_id])
    quality_rows = collect_rows(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)

    # Failures
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, "SELECT suite_name, file_path, test_name, message FROM test_failures WHERE run_id = ?1")
    :ok = Exqlite.Sqlite3.bind(db, stmt, [run_id])
    failure_rows = collect_rows(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)

    Exqlite.Sqlite3.close(db)

    {run_row, summary_row, compile_rows, suite_rows, quality_rows, failure_rows}
  end

  defp collect_rows(db, stmt) do
    collect_rows(db, stmt, [])
  end

  defp collect_rows(db, stmt, acc) do
    case Exqlite.Sqlite3.step(db, stmt) do
      {:row, row} -> collect_rows(db, stmt, [row | acc])
      :done -> Enum.reverse(acc)
    end
  end
end

# Parse ExUnit output to extract stats
defmodule OutputParser do
  def parse_test_summary(output) do
    # Match: "63 properties, 393 tests, 0 failures, 1 skipped (79 excluded)"
    # or: "62 tests, 0 failures"
    props = case Regex.run(~r/(\d+) propert(?:y|ies)/, output) do
      [_, n] -> String.to_integer(n)
      nil -> 0
    end
    tests = case Regex.run(~r/(\d+) tests?/, output) do
      [_, n] -> String.to_integer(n)
      nil -> 0
    end
    failed = case Regex.run(~r/(\d+) failures?/, output) do
      [_, n] -> String.to_integer(n)
      nil -> 0
    end
    skipped = case Regex.run(~r/(\d+) skipped/, output) do
      [_, n] -> String.to_integer(n)
      nil -> 0
    end
    excluded = case Regex.run(~r/(\d+) excluded/, output) do
      [_, n] -> String.to_integer(n)
      nil -> 0
    end
    duration = case Regex.run(~r/Finished in (\d+\.?\d*) seconds/, output) do
      [_, n] -> (String.to_float(n) * 1000) |> round()
      nil -> 0
    end
    warnings = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))

    passed = tests - failed - skipped

    %{
      total: tests + props,
      tests: tests,
      passed: passed + props,
      failed: failed,
      skipped: skipped,
      excluded: excluded,
      properties: props,
      duration_ms: duration,
      warnings: warnings
    }
  end

  def parse_compile_output(output) do
    file_count = case Regex.run(~r/Compiled (\d+) files?/, output) do
      [_, n] -> String.to_integer(n)
      nil -> 0
    end
    warnings = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))
    errors = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error:"))
    has_error = String.contains?(output, "** (CompileError)") or String.contains?(output, "== Compilation error")

    status = cond do
      has_error or errors > 0 -> "FAIL"
      warnings > 0 -> "WARN"
      true -> "PASS"
    end

    %{status: status, file_count: file_count, warnings: warnings, errors: errors}
  end

  def count_fmea_tests(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "FMEA"))
  end
end

# Main execution
case System.argv() do
  ["init"] ->
    RegressionTracker.init()

  _ ->
    IO.puts("Usage: elixir scripts/testing/regression_tracker.exs init")
end
