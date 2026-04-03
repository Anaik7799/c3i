defmodule Indrajaal.Testing.UTLTSFormatter do
  @moduledoc """
  ExUnit formatter that writes test lifecycle events to the UTLTS SQLite database.

  Unified Test Lifecycle Tracking System (UTLTS) — records every test run, test case result,
  timing metric, failure detail, and log reference into a single portable SQLite database
  at `data/holons/test/utlts.db`.

  ## What
  Persistent SQLite-based test lifecycle tracking across all runs, with full failure context,
  performance metrics, log correlation, and flaky test detection.

  ## Why
  - Existing ZenohTestFormatter is ephemeral (in-memory GenServer state)
  - test_tracking.db and test_manager.db are fragmented and unused in CI path
  - Need unified, queryable, portable test history for trend analysis and flaky detection

  ## Constraints
  - SC-UTLTS-001: WAL mode for concurrent access
  - SC-UTLTS-002: All test runs recorded regardless of runtime
  - SC-UTLTS-003: Write latency < 1ms per result (async batched writes)
  - SC-UTLTS-012: Concurrent access from 16 parallel test threads
  - SC-ZTEST-004: Non-blocking formatter (async writes)

  ## Usage
  ```elixir
  # test/test_helper.exs
  ExUnit.configure(formatters: [
    ExUnit.CLIFormatter,
    Indrajaal.Testing.ZenohTestFormatter,
    Indrajaal.Testing.UTLTSFormatter
  ])
  ```

  ## Change History
  | Version | Date       | Author      | Change                    |
  |---------|------------|-------------|---------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial implementation    |

  @version "1.0.0"
  @last_modified "2026-03-09T00:00:00Z"
  """

  use GenServer

  require Logger

  @db_path "data/holons/test/utlts.db"
  @project_id "proj-elixir-main"
  @batch_size 50
  @flush_interval_ms 1000

  # ============================================================
  # STATE
  # ============================================================

  defstruct [
    :db,
    :run_id,
    :env_id,
    :suite_start_time,
    :flush_timer,
    test_count: 0,
    pass_count: 0,
    fail_count: 0,
    skip_count: 0,
    error_count: 0,
    result_buffer: [],
    module_map: %{},
    definition_cache: %{}
  ]

  # ============================================================
  # GENSERVER CALLBACKS (ExUnit Formatter Protocol)
  # ============================================================

  @impl true
  def init(opts) do
    case open_database() do
      {:ok, db} ->
        run_id = generate_uuid()
        env_id = capture_environment(db)
        suite_start = System.monotonic_time(:microsecond)

        # Insert test_run record
        insert_run(db, run_id, env_id, opts)

        # Schedule periodic flush
        timer = Process.send_after(self(), :flush_buffer, @flush_interval_ms)

        state = %__MODULE__{
          db: db,
          run_id: run_id,
          env_id: env_id,
          suite_start_time: suite_start,
          flush_timer: timer
        }

        {:ok, state}

      {:error, reason} ->
        Logger.warning("[UTLTS] Failed to open database: #{inspect(reason)}. Formatter disabled.")
        {:ok, %__MODULE__{db: nil}}
    end
  end

  @impl true
  def handle_cast({:suite_started, _opts}, state) do
    {:noreply, state}
  end

  @impl true
  # OTP 28+: ExUnit sends {:suite_finished, %{async: _, run: _, load: _}}
  def handle_cast({:suite_finished, %{} = _times_map}, %{db: nil} = state) do
    {:noreply, state}
  end

  # Legacy: {:suite_finished, run_us, load_us}
  def handle_cast({:suite_finished, times_us, _load_us}, %{db: nil} = state) do
    _ = times_us
    {:noreply, state}
  end

  def handle_cast({:suite_finished, %{} = _times_map}, state) do
    # Flush remaining buffer
    state = flush_buffer(state)

    # Update test_run with final stats
    duration_ms = div(System.monotonic_time(:microsecond) - state.suite_start_time, 1000)

    finalize_run(state.db, state.run_id, %{
      status: if(state.fail_count == 0 and state.error_count == 0, do: "passed", else: "failed"),
      duration_ms: duration_ms,
      total_tests: state.test_count,
      passed: state.pass_count,
      failed: state.fail_count,
      skipped: state.skip_count,
      errored: state.error_count
    })

    # Run flaky analysis update
    update_flaky_analysis(state.db)

    # Close database
    Exqlite.Sqlite3.close(state.db)

    Logger.info(
      "[UTLTS] Run #{state.run_id} complete: #{state.pass_count} passed, #{state.fail_count} failed, #{state.skip_count} skipped (#{duration_ms}ms)"
    )

    {:noreply, %{state | db: nil}}
  end

  # OTP 28+: ExUnit sends {:case_started, %ExUnit.TestCase{}} in addition to module_started
  @impl true
  def handle_cast({:case_started, _test_case}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:case_finished, _test_case}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:module_started, %ExUnit.TestModule{name: name, file: file}},
        %{db: nil} = state
      ) do
    _ = {name, file}
    {:noreply, state}
  end

  def handle_cast({:module_started, %ExUnit.TestModule{name: name, file: file}}, state) do
    suite_id = ensure_suite(state.db, name, file)

    module_map =
      Map.put(state.module_map, name, %{
        suite_id: suite_id,
        start_time: System.monotonic_time(:microsecond)
      })

    {:noreply, %{state | module_map: module_map}}
  end

  @impl true
  def handle_cast({:module_finished, %ExUnit.TestModule{name: name}}, state) do
    module_map = Map.delete(state.module_map, name)
    {:noreply, %{state | module_map: module_map}}
  end

  @impl true
  def handle_cast({:test_started, %ExUnit.Test{}}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:test_finished, %ExUnit.Test{} = test}, %{db: nil} = state) do
    _ = test
    {:noreply, state}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
    # Get or create test definition
    module_info = Map.get(state.module_map, test.module, %{suite_id: nil})
    suite_id = module_info[:suite_id]

    definition_id = ensure_definition(state, suite_id, test)

    # Build result record
    result = build_result(state.run_id, definition_id, test)

    # Update counters
    state = update_counters(state, test)

    # Buffer the result
    buffer = [result | state.result_buffer]

    state = %{
      state
      | result_buffer: buffer,
        definition_cache: Map.put(state.definition_cache, {test.module, test.name}, definition_id)
    }

    # Flush if buffer full
    state =
      if length(buffer) >= @batch_size do
        flush_buffer(state)
      else
        state
      end

    {:noreply, state}
  end

  # Catch-all for any unknown ExUnit formatter events (future OTP compatibility)
  def handle_cast(_unknown, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:flush_buffer, %{db: nil} = state) do
    {:noreply, state}
  end

  def handle_info(:flush_buffer, state) do
    state = flush_buffer(state)
    timer = Process.send_after(self(), :flush_buffer, @flush_interval_ms)
    {:noreply, %{state | flush_timer: timer}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # DATABASE OPERATIONS
  # ============================================================

  defp open_database do
    db_dir = Path.dirname(@db_path)
    File.mkdir_p!(db_dir)

    case Exqlite.Sqlite3.open(@db_path) do
      {:ok, db} ->
        # Ensure WAL mode and performance settings (SC-UTLTS-001)
        Exqlite.Sqlite3.execute(db, "PRAGMA journal_mode = WAL")
        Exqlite.Sqlite3.execute(db, "PRAGMA busy_timeout = 5000")
        Exqlite.Sqlite3.execute(db, "PRAGMA synchronous = NORMAL")
        Exqlite.Sqlite3.execute(db, "PRAGMA foreign_keys = ON")
        Exqlite.Sqlite3.execute(db, "PRAGMA cache_size = -32000")

        # Ensure schema exists
        ensure_schema(db)

        {:ok, db}

      error ->
        error
    end
  end

  defp ensure_schema(db) do
    # Check if tables exist
    case Exqlite.Sqlite3.execute(
           db,
           "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='test_runs'"
         ) do
      {:ok, _} ->
        :ok

      _ ->
        # Apply schema from file
        schema_path = "data/holons/test/utlts_schema.sql"

        if File.exists?(schema_path) do
          schema = File.read!(schema_path)

          schema
          |> String.split(";")
          |> Enum.each(fn stmt ->
            stmt = String.trim(stmt)

            if stmt != "" and not String.starts_with?(stmt, "--") do
              Exqlite.Sqlite3.execute(db, stmt)
            end
          end)
        else
          Logger.warning("[UTLTS] Schema file not found at #{schema_path}")
        end
    end
  end

  defp insert_run(db, run_id, env_id, _opts) do
    {git_commit, git_branch, git_message} = capture_git_context()
    now = utc_now()

    sql = """
    INSERT INTO test_runs (id, project_id, environment_id, run_type, status, trigger,
      git_commit, git_branch, git_message, started_at, state_vector, tags)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Exqlite.Sqlite3.bind(stmt, [
      run_id,
      @project_id,
      env_id,
      "unit",
      "running",
      "manual",
      git_commit,
      git_branch,
      git_message,
      now,
      "[0,0,0,0,0,0]",
      "[]"
    ])

    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
  end

  defp finalize_run(db, run_id, stats) do
    now = utc_now()

    sql = """
    UPDATE test_runs SET
      status = ?1, finished_at = ?2, duration_ms = ?3,
      total_tests = ?4, passed = ?5, failed = ?6, skipped = ?7, errored = ?8
    WHERE id = ?9
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Exqlite.Sqlite3.bind(stmt, [
      stats.status,
      now,
      stats.duration_ms,
      stats.total_tests,
      stats.passed,
      stats.failed,
      stats.skipped,
      stats.errored,
      run_id
    ])

    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)
  end

  defp ensure_suite(db, module_name, file_path) do
    name = inspect(module_name)
    rel_path = Path.relative_to(file_path, File.cwd!())

    # Check cache first
    case Exqlite.Sqlite3.execute(
           db,
           "SELECT id FROM test_suites WHERE name = '#{escape(name)}' AND project_id = '#{@project_id}'"
         ) do
      {:ok, [[id]]} ->
        id

      _ ->
        id = generate_uuid()
        domain = extract_domain(rel_path)
        layer = estimate_fractal_layer(rel_path)
        category = detect_category(rel_path)

        sql = """
        INSERT OR IGNORE INTO test_suites (id, project_id, name, file_path, runtime, fractal_layer, domain, category)
        VALUES (?1, ?2, ?3, ?4, 'elixir', ?5, ?6, ?7)
        """

        {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)
        Exqlite.Sqlite3.bind(stmt, [id, @project_id, name, rel_path, layer, domain, category])
        Exqlite.Sqlite3.step(db, stmt)
        Exqlite.Sqlite3.release(db, stmt)

        id
    end
  end

  defp ensure_definition(state, suite_id, %ExUnit.Test{} = test) do
    key = {test.module, test.name}

    case Map.get(state.definition_cache, key) do
      nil when suite_id != nil ->
        id = generate_uuid()
        full_name = "#{inspect(test.module)}.#{test.name}"
        test_type = detect_test_type(test)
        framework = detect_framework(test)

        sql = """
        INSERT OR IGNORE INTO test_definitions (id, suite_id, name, full_name, test_type, framework)
        VALUES (?1, ?2, ?3, ?4, ?5, ?6)
        """

        {:ok, stmt} = Exqlite.Sqlite3.prepare(state.db, sql)

        Exqlite.Sqlite3.bind(stmt, [
          id,
          suite_id,
          to_string(test.name),
          full_name,
          test_type,
          framework
        ])

        Exqlite.Sqlite3.step(state.db, stmt)
        Exqlite.Sqlite3.release(state.db, stmt)

        id

      nil ->
        generate_uuid()

      cached_id ->
        cached_id
    end
  end

  defp build_result(run_id, definition_id, %ExUnit.Test{} = test) do
    {status, failure_info} = extract_status(test)
    now = utc_now()

    %{
      id: generate_uuid(),
      run_id: run_id,
      definition_id: definition_id,
      status: status,
      duration_us: test.time,
      failure_type: failure_info[:type],
      failure_message: failure_info[:message],
      failure_left: failure_info[:left],
      failure_right: failure_info[:right],
      stacktrace: failure_info[:stacktrace],
      started_at: now,
      finished_at: now
    }
  end

  defp flush_buffer(%{result_buffer: []} = state), do: state

  defp flush_buffer(%{db: nil} = state), do: %{state | result_buffer: []}

  defp flush_buffer(state) do
    sql = """
    INSERT INTO test_results (id, run_id, definition_id, status, duration_us,
      failure_type, failure_message, failure_left, failure_right, stacktrace,
      started_at, finished_at)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
    """

    Exqlite.Sqlite3.execute(state.db, "BEGIN TRANSACTION")

    {:ok, stmt} = Exqlite.Sqlite3.prepare(state.db, sql)

    Enum.each(state.result_buffer, fn result ->
      Exqlite.Sqlite3.bind(stmt, [
        result.id,
        result.run_id,
        result.definition_id,
        result.status,
        result.duration_us,
        result.failure_type,
        result.failure_message,
        result.failure_left,
        result.failure_right,
        result.stacktrace,
        result.started_at,
        result.finished_at
      ])

      Exqlite.Sqlite3.step(state.db, stmt)
      Exqlite.Sqlite3.reset(stmt)
    end)

    Exqlite.Sqlite3.release(state.db, stmt)
    Exqlite.Sqlite3.execute(state.db, "COMMIT")

    %{state | result_buffer: []}
  end

  # ============================================================
  # ENVIRONMENT CAPTURE
  # ============================================================

  defp capture_environment(db) do
    hostname = to_string(:net_adm.localhost())
    {os_name, os_version} = os_info()
    elixir_version = System.version()
    otp_version = to_string(:erlang.system_info(:otp_release))

    # Create fingerprint hash for deduplication
    fingerprint = :crypto.hash(:sha256, "#{hostname}|#{os_name}|#{elixir_version}|#{otp_version}")
    env_id = Base.encode16(fingerprint, case: :lower) |> binary_part(0, 32)

    sql = """
    INSERT OR IGNORE INTO test_environments (id, hostname, os_name, os_version,
      elixir_version, otp_version, cpu_count, zenoh_enabled, patient_mode)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
    """

    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, sql)

    Exqlite.Sqlite3.bind(stmt, [
      env_id,
      hostname,
      os_name,
      os_version,
      elixir_version,
      otp_version,
      System.schedulers_online(),
      if(System.get_env("SKIP_ZENOH_NIF") == "0", do: 1, else: 0),
      if(System.get_env("PATIENT_MODE") == "enabled", do: 1, else: 0)
    ])

    Exqlite.Sqlite3.step(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)

    env_id
  end

  # ============================================================
  # FLAKY ANALYSIS (post-run, Atlassian Flakinator inspired)
  # ============================================================

  defp update_flaky_analysis(db) do
    # Update flaky analysis for all definitions that have >= 5 runs
    sql = """
    INSERT OR REPLACE INTO flaky_analysis (
      definition_id, window_size, window_start, window_end,
      total_runs, pass_count, fail_count, skip_count, error_count,
      flip_count, flip_rate, flip_rate_ewma, is_flaky, flaky_score, confidence,
      avg_duration_ms, updated_at
    )
    SELECT
      tr.definition_id,
      COUNT(*) AS window_size,
      MIN(runs.started_at) AS window_start,
      MAX(runs.started_at) AS window_end,
      COUNT(*) AS total_runs,
      SUM(CASE WHEN tr.status = 'passed' THEN 1 ELSE 0 END) AS pass_count,
      SUM(CASE WHEN tr.status = 'failed' THEN 1 ELSE 0 END) AS fail_count,
      SUM(CASE WHEN tr.status = 'skipped' THEN 1 ELSE 0 END) AS skip_count,
      SUM(CASE WHEN tr.status = 'errored' THEN 1 ELSE 0 END) AS error_count,
      0 AS flip_count,
      0.0 AS flip_rate,
      0.0 AS flip_rate_ewma,
      CASE WHEN SUM(CASE WHEN tr.status = 'passed' THEN 1 ELSE 0 END) > 0
        AND SUM(CASE WHEN tr.status = 'failed' THEN 1 ELSE 0 END) > 0
        THEN 1 ELSE 0 END AS is_flaky,
      CASE WHEN COUNT(*) > 1 THEN
        CAST(SUM(CASE WHEN tr.status = 'failed' THEN 1 ELSE 0 END) AS REAL) / COUNT(*)
      ELSE 0.0 END AS flaky_score,
      CASE WHEN COUNT(*) >= 10 THEN 0.9
           WHEN COUNT(*) >= 5 THEN 0.7
           ELSE 0.5 END AS confidence,
      AVG(CAST(tr.duration_us AS REAL) / 1000.0) AS avg_duration_ms,
      strftime('%Y-%m-%dT%H:%M:%fZ', 'now') AS updated_at
    FROM test_results tr
    JOIN test_runs runs ON tr.run_id = runs.id
    GROUP BY tr.definition_id
    HAVING COUNT(*) >= 3
    """

    Exqlite.Sqlite3.execute(db, sql)
  rescue
    _ -> :ok
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp extract_status(%ExUnit.Test{state: nil}), do: {"passed", %{}}

  defp extract_status(%ExUnit.Test{state: {:skipped, _msg}}), do: {"skipped", %{}}

  defp extract_status(%ExUnit.Test{state: {:excluded, _msg}}), do: {"skipped", %{}}

  defp extract_status(%ExUnit.Test{state: {:failed, failures}}) do
    failure_info =
      case failures do
        # Handle list of failures (standard ExUnit)
        [{:error, %ExUnit.AssertionError{} = err, stacktrace} | _] ->
          %{
            type: "assertion",
            message: err.message || "",
            left: inspect_safe(err.left),
            right: inspect_safe(err.right),
            stacktrace: Exception.format_stacktrace(stacktrace)
          }

        [{:error, exception, stacktrace} | _] ->
          %{
            type: "error",
            message: Exception.message(exception),
            left: nil,
            right: nil,
            stacktrace: Exception.format_stacktrace(stacktrace)
          }

        [{kind, reason, stacktrace} | _] when is_atom(kind) ->
          %{
            type: to_string(kind),
            message: inspect(reason),
            left: nil,
            right: nil,
            stacktrace: Exception.format_stacktrace(stacktrace)
          }

        # Handle single tuple failure (Pathogen 558e6118 fix)
        {:error, %ExUnit.AssertionError{} = err, stacktrace} ->
          %{
            type: "assertion",
            message: err.message || "",
            left: inspect_safe(err.left),
            right: inspect_safe(err.right),
            stacktrace: Exception.format_stacktrace(stacktrace)
          }

        {:error, exception, stacktrace} ->
          %{
            type: "error",
            message: Exception.message(exception),
            left: nil,
            right: nil,
            stacktrace: Exception.format_stacktrace(stacktrace)
          }

        {kind, reason, stacktrace} when is_atom(kind) ->
          %{
            type: to_string(kind),
            message: inspect(reason),
            left: nil,
            right: nil,
            stacktrace: Exception.format_stacktrace(stacktrace)
          }

        _ ->
          %{type: "unknown", message: inspect(failures, limit: 200)}
      end

    {"failed", failure_info}
  end

  defp extract_status(%ExUnit.Test{state: {:invalid, _module}}),
    do: {"errored", %{type: "invalid"}}

  # Catch-all for unexpected test states (OTP 28 compatibility)
  defp extract_status(%ExUnit.Test{state: state}),
    do: {"errored", %{type: "unknown", message: inspect(state, limit: 200)}}

  defp extract_status(_other),
    do: {"errored", %{type: "unknown", message: "non-ExUnit.Test struct"}}

  defp inspect_safe(nil), do: nil
  defp inspect_safe(value), do: inspect(value, limit: 200, printable_limit: 500)

  defp capture_git_context do
    commit =
      System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) |> elem(0) |> String.trim()

    branch =
      System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], stderr_to_stdout: true)
      |> elem(0)
      |> String.trim()

    message =
      System.cmd("git", ["log", "-1", "--format=%s"], stderr_to_stdout: true)
      |> elem(0)
      |> String.trim()

    {commit, branch, message}
  rescue
    _ -> {nil, nil, nil}
  end

  defp os_info do
    case :os.type() do
      {:unix, :linux} ->
        version = System.cmd("uname", ["-r"], stderr_to_stdout: true) |> elem(0) |> String.trim()
        {"Linux", version}

      {:unix, :darwin} ->
        {"macOS", nil}

      {_, name} ->
        {to_string(name), nil}
    end
  rescue
    _ -> {"unknown", nil}
  end

  defp extract_domain(file_path) do
    cond do
      String.contains?(file_path, "/analytics/") -> "analytics"
      String.contains?(file_path, "/mesh/") -> "mesh"
      String.contains?(file_path, "/observability/") -> "observability"
      String.contains?(file_path, "/security/") -> "security"
      String.contains?(file_path, "/deployment/") -> "deployment"
      String.contains?(file_path, "/holon/") -> "holon"
      String.contains?(file_path, "/cortex/") -> "cortex"
      String.contains?(file_path, "/ai/") -> "ai"
      String.contains?(file_path, "/container/") -> "container"
      String.contains?(file_path, "/validation/") -> "validation"
      String.contains?(file_path, "/testing/") -> "testing"
      String.contains?(file_path, "/demo/") -> "demo"
      String.contains?(file_path, "/stamp/") -> "stamp"
      String.contains?(file_path, "/indrajaal_web/") -> "web"
      true -> "general"
    end
  end

  defp estimate_fractal_layer(file_path) do
    cond do
      String.contains?(file_path, "/unit/") -> "L1"
      String.contains?(file_path, "/fractal/l1") -> "L1"
      String.contains?(file_path, "/fractal/l2") -> "L2"
      String.contains?(file_path, "/fractal/l3") -> "L3"
      String.contains?(file_path, "/fractal/l4") -> "L4"
      String.contains?(file_path, "/fractal/l5") -> "L5"
      String.contains?(file_path, "/e2e/") -> "L5"
      String.contains?(file_path, "/cluster/") -> "L6"
      String.contains?(file_path, "/integration/") -> "L3"
      String.contains?(file_path, "/property/") -> "L2"
      true -> "L2"
    end
  end

  defp detect_category(file_path) do
    cond do
      String.contains?(file_path, "/property/") -> "property"
      String.contains?(file_path, "/e2e/") -> "e2e"
      String.contains?(file_path, "/integration/") -> "integration"
      String.contains?(file_path, "/demo/") -> "demo"
      String.contains?(file_path, "/fmea/") -> "fmea"
      String.contains?(file_path, "/tdg/") -> "tdg"
      String.contains?(file_path, "/smoke/") -> "smoke"
      String.contains?(file_path, "/chaos/") -> "chaos"
      String.contains?(file_path, "/load/") -> "performance"
      true -> "unit"
    end
  end

  defp detect_test_type(%ExUnit.Test{tags: tags}) do
    cond do
      Map.get(tags, :property, false) -> "property"
      Map.get(tags, :describe, false) -> "describe"
      true -> "test"
    end
  end

  defp detect_framework(%ExUnit.Test{tags: tags}) do
    cond do
      Map.get(tags, :propcheck, false) -> "propcheck"
      Map.get(tags, :ex_unit_properties, false) -> "ex_unit_properties"
      true -> "exunit"
    end
  end

  defp update_counters(state, %ExUnit.Test{state: nil}) do
    %{state | test_count: state.test_count + 1, pass_count: state.pass_count + 1}
  end

  defp update_counters(state, %ExUnit.Test{state: {:skipped, _}}) do
    %{state | test_count: state.test_count + 1, skip_count: state.skip_count + 1}
  end

  defp update_counters(state, %ExUnit.Test{state: {:excluded, _}}) do
    %{state | test_count: state.test_count + 1, skip_count: state.skip_count + 1}
  end

  defp update_counters(state, %ExUnit.Test{state: {:failed, _}}) do
    %{state | test_count: state.test_count + 1, fail_count: state.fail_count + 1}
  end

  defp update_counters(state, %ExUnit.Test{state: {:invalid, _}}) do
    %{state | test_count: state.test_count + 1, error_count: state.error_count + 1}
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

  defp utc_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp escape(str) when is_binary(str) do
    String.replace(str, "'", "''")
  end

  defp escape(val), do: to_string(val) |> escape()
end
