defmodule Indrajaal.Testing.UTLTSCargoParser do
  @moduledoc """
  Parses `cargo test --format json` output and writes results to the UTLTS SQLite database.

  Handles both Rust NIF crates: `zenoh_nif` and `lineage_auth`.

  ## What
  Cargo test JSON parser that transforms Rust test output into UTLTS records,
  enabling cross-runtime test lifecycle tracking.

  ## Why
  - Rust NIFs are critical infrastructure (SC-NIF-001 to SC-NIF-003)
  - NIF test failures must be tracked with the same fidelity as Elixir tests
  - Cross-runtime flaky detection requires unified data

  ## Constraints
  - SC-UTLTS-002: All test runs recorded regardless of runtime
  - SC-UTLTS-006: Cargo test JSON format parsing
  - SC-NIF-001: NIF functions must not block BEAM scheduler

  ## Usage
  ```elixir
  # Parse and record a cargo test run
  {:ok, run_id} = UTLTSCargoParser.run("native/zenoh_nif")

  # Parse existing JSON output
  {:ok, run_id} = UTLTSCargoParser.parse_file("cargo_test_output.json", "proj-rust-zenoh")
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

  @crate_projects %{
    "native/zenoh_nif" => "proj-rust-zenoh",
    "native/lineage_auth" => "proj-rust-lineage"
  }

  @doc """
  Run cargo test for a crate and record results to UTLTS.

  ## Options
  - `:features` - Cargo features to enable
  - `:release` - Run in release mode (default: false)
  - `:test_threads` - Number of test threads (default: 1 for NIF safety)
  """
  @spec run(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def run(crate_path, opts \\ []) do
    project_id = Map.get(@crate_projects, crate_path, "proj-rust-unknown")

    args = build_cargo_args(opts)

    case System.cmd(
           "cargo",
           ["test" | args] ++ ["--", "--format", "json", "-Z", "unstable-options"],
           cd: crate_path,
           stderr_to_stdout: true,
           env: [{"RUST_BACKTRACE", "1"}]
         ) do
      {output, _exit_code} ->
        parse_output(output, project_id, crate_path)

      error ->
        {:error, {:cargo_failed, error}}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  @doc """
  Parse a cargo test JSON output file and record to UTLTS.
  """
  @spec parse_file(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def parse_file(json_path, project_id) do
    case File.read(json_path) do
      {:ok, content} -> parse_output(content, project_id, Path.dirname(json_path))
      error -> error
    end
  end

  @doc """
  Parse raw cargo test JSON output string.
  """
  @spec parse_output(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def parse_output(output, project_id, crate_path) do
    case open_db() do
      {:ok, db} ->
        run_id = generate_uuid()
        env_id = capture_environment(db)
        now = utc_now()

        # Insert run record
        insert_run(db, run_id, project_id, env_id, now, crate_path)

        # Parse each JSON line
        events = parse_json_lines(output)

        # Process events into suites, definitions, and results
        {suite_map, results} = process_events(db, project_id, crate_path, events)
        _ = suite_map

        # Batch insert results
        insert_results(db, run_id, results)

        # Finalize run
        stats = compute_stats(results)
        finalize_run(db, run_id, stats)

        Exqlite.Sqlite3.close(db)

        Logger.info(
          "[UTLTS-Cargo] Run #{run_id}: #{stats.passed}P/#{stats.failed}F/#{stats.skipped}S (#{length(results)} tests)"
        )

        {:ok, run_id}

      {:error, reason} ->
        {:error, {:db_open_failed, reason}}
    end
  end

  # ============================================================
  # CARGO JSON PARSING
  # ============================================================

  defp parse_json_lines(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "{"))
    |> Enum.flat_map(fn line ->
      case Jason.decode(line) do
        {:ok, event} -> [event]
        _ -> []
      end
    end)
  end

  defp process_events(db, project_id, crate_path, events) do
    suite_map = %{}
    results = []

    {suite_map, results} =
      Enum.reduce(events, {suite_map, results}, fn event, {suites, results} ->
        case event do
          %{"type" => "test", "event" => status, "name" => name} = ev ->
            # Extract module from test name (e.g., "tests::zenoh::test_connect" -> "tests::zenoh")
            {module, test_name} = split_test_name(name)

            # Ensure suite exists
            suite_id = ensure_rust_suite(db, suites, project_id, module, crate_path)
            suites = Map.put(suites, module, suite_id)

            # Ensure definition
            definition_id = ensure_rust_definition(db, suite_id, name, test_name)

            # Build result
            result = %{
              id: generate_uuid(),
              definition_id: definition_id,
              status: map_cargo_status(status),
              duration_us: parse_exec_time(ev),
              failure_message: Map.get(ev, "stdout"),
              started_at: utc_now(),
              finished_at: utc_now()
            }

            {suites, [result | results]}

          _ ->
            {suites, results}
        end
      end)

    {suite_map, Enum.reverse(results)}
  end

  defp split_test_name(name) do
    parts = String.split(name, "::")

    case parts do
      [single] -> {"default", single}
      _ -> {Enum.slice(parts, 0..-2//1) |> Enum.join("::"), List.last(parts)}
    end
  end

  defp map_cargo_status("ok"), do: "passed"
  defp map_cargo_status("failed"), do: "failed"
  defp map_cargo_status("ignored"), do: "skipped"
  defp map_cargo_status(other), do: other

  defp parse_exec_time(%{"exec_time" => t}) when is_number(t), do: round(t * 1_000_000)
  defp parse_exec_time(_), do: nil

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

  defp insert_run(db, run_id, project_id, env_id, now, crate_path) do
    {git_commit, git_branch} = git_context()

    sql = """
    INSERT INTO test_runs (id, project_id, environment_id, run_type, status, trigger,
      git_commit, git_branch, started_at, tags)
    VALUES (?1, ?2, ?3, 'unit', 'running', 'manual', ?4, ?5, ?6, ?7)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Exqlite.Sqlite3.bind(stmt, [
      run_id,
      project_id,
      env_id,
      git_commit,
      git_branch,
      now,
      Jason.encode!(["rust", "cargo", Path.basename(crate_path)])
    ])

    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
  end

  defp ensure_rust_suite(db, suites, project_id, module_name, crate_path) do
    case Map.get(suites, module_name) do
      nil ->
        id = generate_uuid()
        rel_path = "#{crate_path}/src/#{String.replace(module_name, "::", "/")}.rs"

        sql = """
        INSERT OR IGNORE INTO test_suites (id, project_id, name, file_path, runtime, domain, category)
        VALUES (?1, ?2, ?3, ?4, 'rust', 'nif', 'unit')
        """

        {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
        Exqlite.Sqlite3.bind(stmt, [id, project_id, module_name, rel_path])
        Exqlite.Sqlite3.step(db, stmt)
        Exqlite.Sqlite3.release(db, stmt)
        id

      existing ->
        existing
    end
  end

  defp ensure_rust_definition(db, suite_id, full_name, test_name) do
    id = generate_uuid()

    sql = """
    INSERT OR IGNORE INTO test_definitions (id, suite_id, name, full_name, test_type, framework)
    VALUES (?1, ?2, ?3, ?4, 'test', 'cargo_test')
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
    Exqlite.Sqlite3.bind(stmt, [id, suite_id, test_name, full_name])
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

  defp compute_stats(results) do
    total = length(results)
    passed = Enum.count(results, &(&1.status == "passed"))
    failed = Enum.count(results, &(&1.status == "failed"))
    skipped = Enum.count(results, &(&1.status == "skipped"))

    total_us =
      results
      |> Enum.map(& &1.duration_us)
      |> Enum.filter(&is_integer/1)
      |> Enum.sum()

    %{
      total: total,
      passed: passed,
      failed: failed,
      skipped: skipped,
      duration_ms: div(total_us, 1000),
      status: if(failed == 0, do: "passed", else: "failed")
    }
  end

  defp capture_environment(db) do
    hostname = to_string(:net_adm.localhost())

    rust_version =
      System.cmd("rustc", ["--version"], stderr_to_stdout: true) |> elem(0) |> String.trim()

    fingerprint = :crypto.hash(:sha256, "#{hostname}|rust|#{rust_version}")
    env_id = Base.encode16(fingerprint, case: :lower) |> binary_part(0, 32)

    sql = """
    INSERT OR IGNORE INTO test_environments (id, hostname, os_name, rust_version)
    VALUES (?1, ?2, 'Linux', ?3)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
    Exqlite.Sqlite3.bind(stmt, [env_id, hostname, rust_version])
    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
    env_id
  rescue
    _ -> "env-rust-unknown"
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

  defp build_cargo_args(opts) do
    args = []
    args = if opts[:release], do: ["--release" | args], else: args

    args =
      case opts[:features] do
        nil -> args
        features -> ["--features", Enum.join(List.wrap(features), ",") | args]
      end

    args =
      case opts[:test_threads] do
        nil -> args
        n -> args ++ ["--", "--test-threads", to_string(n)]
      end

    args
  end

  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    "#{hex(a, 8)}-#{hex(b, 4)}-#{hex(c, 4)}-#{hex(d, 4)}-#{hex(e, 12)}"
  end

  defp hex(value, width) do
    value
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(width, "0")
  end

  defp utc_now, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
