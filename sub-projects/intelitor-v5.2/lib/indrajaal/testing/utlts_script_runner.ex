defmodule Indrajaal.Testing.UTLTSScriptRunner do
  @moduledoc """
  Wraps script execution (Elixir .exs and F# .fsx) with UTLTS lifecycle tracking.

  Records script runs as test_runs with individual assertion/check results as test_results,
  capturing timing, exit codes, stdout/stderr, and log references.

  ## What
  Script execution wrapper that tracks 1,560+ scripts across 4 categories:
  - `scripts/testing/` — 100+ Elixir test scripts
  - `scripts/demo/` — 56 Elixir demo scripts
  - `scripts/ga-release/` — GA verification scripts
  - `lib/cepaf/scripts/` — 14 F# runtime scripts

  ## Why
  - Scripts produce validation results that must be tracked historically
  - Demo scripts verify business flows but have no persistent record
  - F# scripts orchestrate multi-stage tests without lifecycle tracking
  - CI/CD needs unified pass/fail status across all execution paths

  ## Constraints
  - SC-UTLTS-002: All test runs recorded regardless of runtime
  - SC-UTLTS-007: Script execution tracking
  - SC-BATCH-001: Max 10 changes/batch

  ## Usage
  ```elixir
  # Run a single Elixir script
  {:ok, run_id} = UTLTSScriptRunner.run_elixir("scripts/testing/tdg_validator.exs")

  # Run an F# script
  {:ok, run_id} = UTLTSScriptRunner.run_fsharp("lib/cepaf/scripts/SIL4Orchestrator.fsx")

  # Run all scripts in a directory
  results = UTLTSScriptRunner.run_directory("scripts/demo/")
  ```

  ## Change History
  | Version | Date       | Author      | Change                    |
  |---------|------------|-------------|---------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial implementation    |

  @version "1.0.0"
  @last_modified "2026-03-09T00:00:00Z"
  """

  require Logger

  @db_path "data/holons/test/utlts.db"

  @script_projects %{
    "scripts/testing/" => "proj-scripts-test",
    "scripts/demo/" => "proj-scripts-demo",
    "scripts/ga-release/" => "proj-scripts-ga",
    "lib/cepaf/scripts/" => "proj-scripts-fsharp"
  }

  @doc """
  Run an Elixir script (.exs) and record results.

  ## Options
  - `:timeout` - Execution timeout in milliseconds (default: 300_000 / 5 min)
  - `:args` - Arguments to pass to the script
  - `:env` - Additional environment variables as list of `{key, value}`
  """
  @spec run_elixir(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def run_elixir(script_path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 300_000)
    args = Keyword.get(opts, :args, [])
    env = Keyword.get(opts, :env, [])

    project_id = detect_project(script_path)
    run_script("elixir", ["elixir", script_path | args], project_id, script_path, timeout, env)
  end

  @doc """
  Run an F# script (.fsx) and record results.
  """
  @spec run_fsharp(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def run_fsharp(script_path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 300_000)
    args = Keyword.get(opts, :args, [])
    env = Keyword.get(opts, :env, [])

    project_id = detect_project(script_path)

    run_script(
      "fsharp",
      ["dotnet", "fsi", script_path | args],
      project_id,
      script_path,
      timeout,
      env
    )
  end

  @doc """
  Run all scripts in a directory and return aggregate results.

  ## Options
  - `:pattern` - Glob pattern (default: "*.exs" for Elixir dirs, "*.fsx" for F# dirs)
  - `:parallel` - Run in parallel (default: false)
  - `:max_concurrent` - Max parallel scripts (default: 4)
  """
  @spec run_directory(String.t(), keyword()) :: %{
          total: integer(),
          passed: integer(),
          failed: integer(),
          results: list()
        }
  def run_directory(dir_path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, detect_pattern(dir_path))
    parallel = Keyword.get(opts, :parallel, false)
    max_concurrent = Keyword.get(opts, :max_concurrent, 4)

    scripts =
      Path.join(dir_path, pattern)
      |> Path.wildcard()
      |> Enum.sort()

    results =
      if parallel do
        scripts
        |> Task.async_stream(
          fn script -> run_single(script, opts) end,
          max_concurrency: max_concurrent,
          timeout: :infinity
        )
        |> Enum.map(fn
          {:ok, result} -> result
          {:exit, reason} -> {:error, reason}
        end)
      else
        Enum.map(scripts, fn script -> run_single(script, opts) end)
      end

    passed = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    %{
      total: length(scripts),
      passed: passed,
      failed: failed,
      results: Enum.zip(scripts, results)
    }
  end

  @doc """
  Query UTLTS for script run history.
  """
  @spec history(String.t(), keyword()) :: {:ok, list()} | {:error, term()}
  def history(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    case open_db() do
      {:ok, db} ->
        sql = """
        SELECT r.id, r.status, r.started_at, r.duration_ms, r.total_tests, r.passed, r.failed
        FROM test_runs r
        WHERE r.project_id = ?1
        ORDER BY r.started_at DESC
        LIMIT ?2
        """

        {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
        Exqlite.Sqlite3.bind(stmt, [project_id, limit])
        rows = collect_rows(db, stmt)
        Exqlite.Sqlite3.release(db, stmt)
        Exqlite.Sqlite3.close(db)
        {:ok, rows}

      error ->
        error
    end
  end

  # ============================================================
  # INTERNAL
  # ============================================================

  defp run_single(script_path, opts) do
    cond do
      String.ends_with?(script_path, ".exs") -> run_elixir(script_path, opts)
      String.ends_with?(script_path, ".fsx") -> run_fsharp(script_path, opts)
      true -> {:error, :unsupported_script_type}
    end
  end

  defp run_script(runtime, cmd_args, project_id, script_path, timeout, extra_env) do
    case open_db() do
      {:ok, db} ->
        run_id = generate_uuid()
        env_id = capture_environment(db, runtime)
        start_time = System.monotonic_time(:microsecond)
        now = utc_now()

        # Insert run
        insert_run(db, run_id, project_id, env_id, now, script_path)

        # Ensure suite for this script
        suite_id = ensure_script_suite(db, project_id, script_path, runtime)

        # Execute script
        {output, exit_code, duration_us} = execute_cmd(cmd_args, timeout, extra_env)

        # Parse output for assertion-like patterns
        results = parse_script_output(output, suite_id, db)

        # If no assertions found, create a single pass/fail result based on exit code
        results =
          if results == [] do
            definition_id =
              ensure_script_definition(db, suite_id, Path.basename(script_path), script_path)

            [
              %{
                id: generate_uuid(),
                definition_id: definition_id,
                status: if(exit_code == 0, do: "passed", else: "failed"),
                duration_us: duration_us,
                failure_message: if(exit_code != 0, do: String.slice(output, -2000..-1//1)),
                started_at: now,
                finished_at: utc_now()
              }
            ]
          else
            results
          end

        # Insert results
        insert_results(db, run_id, results)

        # Store output as log artifact
        store_log_artifact(db, run_id, script_path, output)

        # Finalize
        passed = Enum.count(results, &(&1.status == "passed"))
        failed = Enum.count(results, &(&1.status == "failed"))
        duration_ms = div(System.monotonic_time(:microsecond) - start_time, 1000)

        finalize_run(db, run_id, %{
          status: if(exit_code == 0 and failed == 0, do: "passed", else: "failed"),
          duration_ms: duration_ms,
          total: length(results),
          passed: passed,
          failed: failed,
          skipped: 0
        })

        Exqlite.Sqlite3.close(db)

        Logger.info(
          "[UTLTS-Script] #{Path.basename(script_path)}: exit=#{exit_code} #{passed}P/#{failed}F (#{duration_ms}ms)"
        )

        {:ok, run_id}

      {:error, reason} ->
        {:error, {:db_open_failed, reason}}
    end
  end

  defp execute_cmd([cmd | args], timeout, extra_env) do
    env =
      [
        {"NO_TIMEOUT", "true"},
        {"PATIENT_MODE", "enabled"},
        {"MIX_ENV", "test"}
      ] ++ extra_env

    start = System.monotonic_time(:microsecond)

    task =
      Task.async(fn ->
        System.cmd(cmd, args, stderr_to_stdout: true, env: env)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {output, exit_code}} ->
        duration = System.monotonic_time(:microsecond) - start
        {output, exit_code, duration}

      nil ->
        duration = System.monotonic_time(:microsecond) - start
        {"TIMEOUT after #{div(timeout, 1000)}s", 124, duration}
    end
  end

  defp parse_script_output(output, suite_id, db) do
    # Look for common assertion patterns in script output
    patterns = [
      # "✓ Test Name" or "✅ Test Name" or "[PASS] Test Name"
      {~r/(?:✓|✅|\[PASS\])\s+(.+)/, "passed"},
      # "✗ Test Name" or "❌ Test Name" or "[FAIL] Test Name"
      {~r/(?:✗|❌|\[FAIL\])\s+(.+)/, "failed"},
      # "OK: description" or "PASS: description"
      {~r/(?:OK|PASS):\s+(.+)/, "passed"},
      # "FAIL: description" or "ERROR: description"
      {~r/(?:FAIL|ERROR):\s+(.+)/, "failed"},
      # Elixir script pattern: "  Test: name ... ok"
      {~r/\s+Test:\s+(.+?)\s*\.\.\.\s*ok/, "passed"},
      # Elixir script pattern: "  Test: name ... FAILED"
      {~r/\s+Test:\s+(.+?)\s*\.\.\.\s*(?:FAILED|FAIL)/, "failed"},
      # F# pattern: "  [PASSED] name"
      {~r/\[PASSED\]\s+(.+)/, "passed"},
      {~r/\[FAILED\]\s+(.+)/, "failed"}
    ]

    output
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      Enum.flat_map(patterns, fn {regex, status} ->
        case Regex.run(regex, line) do
          [_, name] ->
            definition_id =
              ensure_script_definition(db, suite_id, String.trim(name), String.trim(name))

            [
              %{
                id: generate_uuid(),
                definition_id: definition_id,
                status: status,
                duration_us: nil,
                failure_message: if(status == "failed", do: line),
                started_at: utc_now(),
                finished_at: utc_now()
              }
            ]

          _ ->
            []
        end
      end)
    end)
  end

  # ============================================================
  # DATABASE OPERATIONS
  # ============================================================

  defp open_db do
    File.mkdir_p!(Path.dirname(@db_path))

    case Exqlite.Sqlite3.open(@db_path) do
      {:ok, db} ->
        Exqlite.Sqlite3.execute(db, "PRAGMA journal_mode = WAL")
        Exqlite.Sqlite3.execute(db, "PRAGMA busy_timeout = 5000")
        Exqlite.Sqlite3.execute(db, "PRAGMA foreign_keys = ON")
        {:ok, db}

      error ->
        error
    end
  end

  defp insert_run(db, run_id, project_id, env_id, now, script_path) do
    {commit, branch} = git_context()

    sql = """
    INSERT INTO test_runs (id, project_id, environment_id, run_type, status, trigger,
      git_commit, git_branch, started_at, tags)
    VALUES (?1, ?2, ?3, 'script', 'running', 'manual', ?4, ?5, ?6, ?7)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Exqlite.Sqlite3.bind(stmt, [
      run_id,
      project_id,
      env_id,
      commit,
      branch,
      now,
      Jason.encode!(["script", Path.basename(script_path)])
    ])

    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
  end

  defp ensure_script_suite(db, project_id, script_path, runtime) do
    rel_path = Path.relative_to(script_path, File.cwd!())
    name = Path.basename(script_path, Path.extname(script_path))

    sql = "SELECT id FROM test_suites WHERE project_id = ?1 AND file_path = ?2"
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
    Exqlite.Sqlite3.bind(stmt, [project_id, rel_path])

    result =
      case Exqlite.Sqlite3.step(db, stmt) do
        {:row, [id]} -> id
        _ -> nil
      end

    Exqlite.Sqlite3.release(db, stmt)

    case result do
      nil ->
        id = generate_uuid()
        rt = if(runtime == "fsharp", do: "fsharp", else: "script")
        domain = detect_domain(rel_path)

        sql = """
        INSERT OR IGNORE INTO test_suites (id, project_id, name, file_path, runtime, domain, category)
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, 'smoke')
        """

        {:ok, stmt2} = Exqlite.Sqlite3.prepare(db, sql)
        Exqlite.Sqlite3.bind(stmt2, [id, project_id, name, rel_path, rt, domain])
        Exqlite.Sqlite3.step(db, stmt2)
        Exqlite.Sqlite3.release(db, stmt2)
        id

      existing ->
        existing
    end
  end

  defp ensure_script_definition(db, suite_id, name, full_name) do
    id = generate_uuid()

    sql = """
    INSERT OR IGNORE INTO test_definitions (id, suite_id, name, full_name, test_type, framework)
    VALUES (?1, ?2, ?3, ?4, 'test', 'script')
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
    Exqlite.Sqlite3.bind(stmt, [id, suite_id, name, full_name])
    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    id
  end

  defp insert_results(db, run_id, results) do
    sql = """
    INSERT INTO test_results (id, run_id, definition_id, status, duration_us,
      failure_message, started_at, finished_at)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
    """

    Exqlite.Sqlite3.execute(db, "BEGIN TRANSACTION")
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Enum.each(results, fn r ->
      Exqlite.Sqlite3.bind(stmt, [
        r.id,
        run_id,
        r.definition_id,
        r.status,
        r.duration_us,
        r.failure_message,
        r.started_at,
        r.finished_at
      ])

      Exqlite.Sqlite3.step(db, stmt)
      Exqlite.Sqlite3.reset(stmt)
    end)

    Exqlite.Sqlite3.release(db, stmt)
    Exqlite.Sqlite3.execute(db, "COMMIT")
  end

  defp store_log_artifact(db, run_id, script_path, output) do
    # Store last 10KB of output as a log artifact reference
    truncated =
      if byte_size(output) > 10_000,
        do: "...\n" <> String.slice(output, -10_000..-1//1),
        else: output

    log_path = "data/tmp/utlts_logs/#{run_id}_#{Path.basename(script_path)}.log"
    File.mkdir_p!(Path.dirname(log_path))
    File.write!(log_path, output)

    sql = """
    INSERT INTO run_artifacts (run_id, artifact_type, name, file_path, file_size_bytes)
    VALUES (?1, 'log', ?2, ?3, ?4)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Exqlite.Sqlite3.bind(stmt, [
      run_id,
      Path.basename(script_path) <> ".log",
      log_path,
      byte_size(truncated)
    ])

    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
  end

  defp finalize_run(db, run_id, stats) do
    sql = """
    UPDATE test_runs SET status = ?1, finished_at = ?2, duration_ms = ?3,
      total_tests = ?4, passed = ?5, failed = ?6, skipped = ?7
    WHERE id = ?8
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Exqlite.Sqlite3.bind(stmt, [
      stats.status,
      utc_now(),
      stats.duration_ms,
      stats.total,
      stats.passed,
      stats.failed,
      stats.skipped,
      run_id
    ])

    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
  end

  defp capture_environment(db, runtime) do
    hostname = to_string(:net_adm.localhost())
    fingerprint = :crypto.hash(:sha256, "#{hostname}|#{runtime}")
    env_id = Base.encode16(fingerprint, case: :lower) |> binary_part(0, 32)

    sql =
      "INSERT OR IGNORE INTO test_environments (id, hostname, os_name) VALUES (?1, ?2, 'Linux')"

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
    Exqlite.Sqlite3.bind(stmt, [env_id, hostname])
    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    env_id
  rescue
    _ -> "env-script-unknown"
  end

  defp collect_rows(db, stmt) do
    case Exqlite.Sqlite3.step(db, stmt) do
      {:row, row} -> [row | collect_rows(db, stmt)]
      :done -> []
    end
  end

  defp detect_project(path) do
    Enum.find_value(@script_projects, "proj-scripts-test", fn {prefix, id} ->
      if String.starts_with?(path, prefix), do: id
    end)
  end

  defp detect_pattern(dir_path) do
    if String.contains?(dir_path, "cepaf"), do: "*.fsx", else: "*.exs"
  end

  defp detect_domain(path) do
    cond do
      String.contains?(path, "testing") -> "testing"
      String.contains?(path, "demo") -> "demo"
      String.contains?(path, "ga-release") -> "ga_release"
      String.contains?(path, "infrastructure") -> "infrastructure"
      String.contains?(path, "diagnostics") -> "diagnostics"
      String.contains?(path, "dashboard") -> "dashboard"
      true -> "general"
    end
  end

  defp git_context do
    commit =
      System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) |> elem(0) |> String.trim()

    branch =
      System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], stderr_to_stdout: true)
      |> elem(0)
      |> String.trim()

    {commit, branch}
  rescue
    _ -> {nil, nil}
  end

  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    "#{hex(a, 8)}-#{hex(b, 4)}-#{hex(c, 4)}-#{hex(d, 4)}-#{hex(e, 12)}"
  end

  defp hex(value, width) do
    value |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(width, "0")
  end

  defp utc_now, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
