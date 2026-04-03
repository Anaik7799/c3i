# Load TDG Container Compliance Tests helper
tdg_helper = "scripts/containers/tdg_container_compliance_tests.exs"

if File.exists?(tdg_helper) do
  Code.require_file("../#{tdg_helper}", __DIR__)
end

# Set test environment explicitly
Application.put_env(:indrajaal, :environment, :test)

# ========================================================================
# DuckDB Test Isolation Fix (SC-HOLON-008)
# ========================================================================
# DuckDB only supports single-writer access. Multiple beam.smp processes
# fighting for the same .duckdb file causes locking errors.
# Solution: Use unique file paths per test run.
test_run_id = System.system_time(:millisecond)
test_duckdb_path = "/tmp/indrajaal_test_#{test_run_id}.duckdb"

# Configure Prajna ImmutableState to use unique DuckDB path
# This is the key used by Indrajaal.Cockpit.Prajna.Config.get(:immutable_state_duckdb_path)
existing_prajna_config = Application.get_env(:indrajaal, Indrajaal.Cockpit.Prajna.Config, [])

updated_prajna_config =
  Keyword.put(existing_prajna_config, :immutable_state_duckdb_path, test_duckdb_path)

Application.put_env(:indrajaal, Indrajaal.Cockpit.Prajna.Config, updated_prajna_config)

# Also configure generic duckdb_path for other modules that may use it
Application.put_env(:indrajaal, :duckdb_path, test_duckdb_path)
Application.put_env(:indrajaal, :prajna_register_path, test_duckdb_path)

# Set unique HOSTNAME for KMS.Service node isolation (it uses HOSTNAME in data_dir/0)
# This ensures each test run gets its own KMS databases
System.put_env("HOSTNAME", "test_#{test_run_id}")

# Cleanup stale test DuckDB files older than 1 hour
one_hour_ago = System.os_time(:second) - 3600

for file <- Path.wildcard("/tmp/indrajaal_test_*.duckdb*") do
  case File.stat(file, time: :posix) do
    {:ok, %{mtime: mtime}} when mtime < one_hour_ago ->
      File.rm(file)

    _ ->
      :ok
  end
end

# Cleanup stale KMS test directories older than 1 hour
for dir <- Path.wildcard("data/kms/test_*") do
  case File.stat(dir, time: :posix) do
    {:ok, %{mtime: mtime}} when mtime < one_hour_ago ->
      File.rm_rf(dir)

    _ ->
      :ok
  end
end

# ========================================================================
# ZENOH REAL-TIME TEST FEEDBACK (SC-ZTEST-*)
# ========================================================================
# Configure ZenohTestFormatter for real-time test feedback via Zenoh pub/sub.
# This enables <100ms feedback to orchestration dashboards.
zenoh_formatter_enabled =
  System.get_env("SKIP_ZENOH_NIF", "1") == "0" or
    Application.get_env(:indrajaal, :zenoh_enabled, false)

# UTLTS formatter is always enabled for persistent test lifecycle tracking (SC-UTLTS-001)
utlts_formatter_enabled =
  File.exists?("data/holons/test/utlts.db") or File.exists?("data/holons/test/utlts_schema.sql")

formatters =
  cond do
    zenoh_formatter_enabled and utlts_formatter_enabled ->
      [
        ExUnit.CLIFormatter,
        Indrajaal.Testing.ZenohTestFormatter,
        Indrajaal.Testing.UTLTSFormatter
      ]

    zenoh_formatter_enabled ->
      [ExUnit.CLIFormatter, Indrajaal.Testing.ZenohTestFormatter]

    utlts_formatter_enabled ->
      [ExUnit.CLIFormatter, Indrajaal.Testing.UTLTSFormatter]

    true ->
      [ExUnit.CLIFormatter]
  end

# Wallaby E2E detection — used for conditional ExUnit exclude and app lifecycle
wallaby_enabled? =
  System.get_env("WALLABY_ENABLED") == "true" or
    System.get_env("TEST_TYPE") == "e2e"

# Configure ExUnit for parallelization with no timeouts
# SOPv5.1 Compliant Configuration
#
# CRITICAL FIX: Use max_cases: 1 initially to prevent compilation timing issues
# where test modules are added after ExUnit starts running.
# The Elixir 1.19 parallel compiler can cause race conditions with large test suites.
ExUnit.configure(
  # Use parallel execution for performance. If "cannot add module after suite starts"
  # errors occur, reduce this value or revert to 1.
  max_cases: System.schedulers_online(),

  # 2-minute timeout per test. :infinity causes hung tests to block the suite forever.
  # Property tests and integration tests should complete well within this limit.
  timeout: 120_000,

  # Detailed reporting for agent analysis
  # SC-ZTEST-004: ZenohTestFormatter is non-blocking (async publish)
  formatters: formatters,

  # Color output for better readability
  colors: [enabled: true],

  # Include all test timing data
  include_test_timings: true,

  # Capture log for safety validation
  capture_log: true,

  # Seed for reproducible property tests
  seed: 0,

  # Exclude pending TDG tests and tests requiring live containers
  # :pending - TDG tests written before implementation
  # :requires_containers - tests needing live Podman containers (sa-up)
  # :wallaby - E2E browser tests excluded unless WALLABY_ENABLED=true
  exclude:
    if(wallaby_enabled?,
      do: [:pending, :requires_containers],
      else: [:pending, :requires_containers, :wallaby]
    )
)

# Start ExUnit with extended configuration
# Note: autorun: true is default, tests start after all modules compiled
ExUnit.start()

# Wallaby lifecycle: start for E2E, stop for unit/integration
if wallaby_enabled? do
  {:ok, _} = Application.ensure_all_started(:wallaby)
else
  Application.stop(:wallaby)
  Application.unload(:wallaby)
end

# Configure Ecto sandbox mode before starting application
# This must be done before the repository starts
if Code.ensure_loaded?(Ecto.Adapters.SQL.Sandbox) do
  # Only configure sandbox if repo not already started
  try do
    Ecto.Adapters.SQL.Sandbox.mode(Indrajaal.Repo, :auto)
  rescue
    RuntimeError ->
      # Repository not started yet, will configure after startup
      :ok
  end
end

# Initialize Wallaby for E2E testing
# Temporarily disabled due to Chrome path issue
# {:ok, _} = Application.ensure_all_started(:wallaby)

# Configure Wallaby base URL for Phoenix endpoint
# Application.put_env(:wallaby, :base_url, IndrajaalWeb.Endpoint.url())

# Configure Wallaby for test environment
# Application.put_env(:wallaby, :screenshot_on_failure, true)
# Application.put_env(:wallaby, :screenshot_dir, "test/screenshots")

# ========================================================================
# STAMP TEST HELPERS - SOPv5.1 COMPLIANT
# ========================================================================

defmodule Indrajaal.STAMPTestHelpers do
  @moduledoc """
  Common helpers for STAMP safety testing with maximum parallelization

  🎯 SOPv5.1: Shared test utilities for parallel execution
  🤖 AGENT-FRIENDLY: Clear helper functions with documentation
  🚀 PARALLEL-READY: Thread-safe implementations
  ⏱️ NO-TIMEOUT: All helpers support unlimited execution time
  """

  @doc """
  Execute test with clean safety monitor __state
  Ensures parallel tests don't interfere with each other
  """
  def with_safety_monitors(fun) do
    # Ensure clean ETS __state for parallel tests
    cleanup_ets_tables()

    # Execute test
    result = fun.()

    # Cleanup after test
    cleanup_ets_tables()

    result
  end

  @doc """
  Cleanup ETS tables used by safety systems
  Thread-safe for parallel test execution
  """
  def cleanup_ets_tables do
    # Safely cleanup ETS tables that might exist
    tables = [
      :safety_metrics,
      :safety_violations,
      :safety_thresholds,
      :alert_config,
      :cast_incidents,
      :cast_templates,
      :cast_timelines,
      :cast_causal_factors,
      :cast_recommendations,
      :cast_workflows,
      :cast_reports,
      :causal_factors_library,
      :recommendation_patterns,
      :pipeline_runs,
      :safety_check_results,
      :deployment_history,
      :safety_gates,
      :rollback_config
    ]

    Enum.each(tables, fn table ->
      try do
        :ets.delete(table)
      rescue
        # Table doesn't exist
        ArgumentError -> :ok
      end
    end)
  end

  @doc """
  Assert condition __eventually becomes true
  Useful for async operations in parallel tests
  No timeout - will retry indefinitely
  """
  def assert_eventually(fun, options \\ []) do
    timeout = Keyword.get(options, :timeout, :infinity)
    interval = Keyword.get(options, :interval, 10)

    start_time = System.monotonic_time(:millisecond)

    result_stream =
      Stream.repeatedly(fn ->
        try do
          fun.()
          :ok
        rescue
          ExUnit.AssertionError ->
            case timeout do
              :infinity ->
                Process.sleep(interval)
                :retry

              timeout_ms when is_integer(timeout_ms) ->
                current_time = System.monotonic_time(:millisecond)

                if current_time - start_time > timeout_ms do
                  # Let it fail with proper error
                  fun.()
                else
                  Process.sleep(interval)
                  :retry
                end
            end
        end
      end)

    result_stream
    |> Stream.filter(&(&1 == :ok))
    |> Enum.take(1)
  end

  @doc """
  Run function in isolated process for parallel safety
  """
  def in_isolated_process(fun) do
    parent = self()

    spawn_link(fn ->
      result = fun.()
      send(parent, {:isolated_result, result})
    end)

    receive do
      {:isolated_result, result} -> result
    after
      # No timeout - wait indefinitely
      :infinity -> raise "Isolated process did not respond"
    end
  end

  @doc """
  Create unique test identifier for parallel execution
  """
  def unique_test_id(prefix \\ "test") do
    "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
  end

  @doc """
  Setup temporary ETS table for test isolation
  """
  def with_temp_ets(name, options \\ [], fun) do
    table_name = :"#{name}_#{unique_test_id()}"
    :ets.new(table_name, [:public, :named_table | options])

    try do
      fun.(table_name)
    after
      :ets.delete(table_name)
    end
  end

  @doc """
  Capture telemetry events in parallel-safe way
  """
  def capture_telemetry(event_name, fun) do
    test_pid = self()
    ref = make_ref()

    handler_id = "test_handler_#{unique_test_id()}"

    :telemetry.attach(
      handler_id,
      event_name,
      fn _event, measurements, metadata, _config ->
        send(test_pid, {ref, :telemetry, measurements, metadata})
      end,
      nil
    )

    try do
      result = fun.()

      # Collect all telemetry events
      events = collect_messages(ref, :telemetry)

      {result, events}
    after
      :telemetry.detach(handler_id)
    end
  end

  @doc """
  Collect messages matching a pattern
  """
  def collect_messages(ref, type) do
    message_stream =
      Stream.repeatedly(fn ->
        receive do
          {^ref, ^type, measurements, metadata} ->
            {measurements, metadata}
        after
          0 -> nil
        end
      end)

    message_stream
    |> Stream.take_while(&(&1 != nil))
    |> Enum.to_list()
  end

  @doc """
  Run parallel test scenarios
  """
  def run_parallel_scenarios(scenarios) do
    scenarios
    |> Task.async_stream(
      fn scenario -> scenario.() end,
      max_concurrency: System.schedulers_online() * 2,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> raise "Parallel scenario failed: #{inspect(reason)}"
    end)
  end

  @doc """
  Assert all parallel results match expectation
  """
  def assert_all_parallel(results, assertionfun) do
    results
    |> Enum.with_index()
    |> Enum.each(fn {result, index} ->
      try do
        assertionfun.(result)
      rescue
        error in ExUnit.AssertionError ->
          reraise ExUnit.AssertionError,
                  [message: "Parallel assertion failed at index #{index}: #{error.message}"],
                  __STACKTRACE__
      end
    end)
  end

  @doc """
  Assert that a function does not raise any exception.
  This is a replacement for Ruby/RSpec's assert_nothing_raised.

  ## Examples

      assert_nothing_raised fn -> SomeModule.safe_function() end

  """
  def assert_nothing_raised(fun) when is_function(fun, 0) do
    try do
      fun.()
      true
    rescue
      e ->
        reraise ExUnit.AssertionError,
                [message: "Expected no exception to be raised, but got: #{inspect(e)}"],
                __STACKTRACE__
    end
  end
end

# Helper functions available for import in test files
# Use: import Indrajaal.STAMPTestHelpers in individual test files

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
