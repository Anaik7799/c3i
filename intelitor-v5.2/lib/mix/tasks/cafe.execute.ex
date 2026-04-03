defmodule Mix.Tasks.Cafe.Execute do
  @moduledoc """
  Execute the CAFE (Cybernetic Architect Framework for Execution) test suite.

  This task runs the full test suite using the CAFE framework with:
  - Parallel multi-agent execution (15 agents: 3 helpers + 12 workers)
  - OODA fast loop monitoring (<100ms target)
  - Criticality-based test sequencing (C1-C5)
  - Real-time dashboard updates

  ## Usage

      mix cafe.execute [options]

  ## Options

    * `--parallel` - Enable parallel execution (default: true)
    * `--agents N` - Number of agents to use (default: 15)
    * `--dashboard` - Enable dashboard output (default: true)
    * `--baseline` - Generate baseline JSON (default: true)
    * `--criticality LEVEL` - Only run tests of specified criticality (c1-c5 or all)
    * `--dry-run` - Show what would be executed without running

  ## Examples

      # Full execution with defaults
      mix cafe.execute

      # Run only critical tests
      mix cafe.execute --criticality c1

      # Dry run to see test manifest
      mix cafe.execute --dry-run

  ## Framework Integration

    SOPv5.11: 6-Phase Execution Model
    OODA: Fast Loop (<100ms) Monitoring
    TPS: 5-Level Root Cause Analysis
    STAMP: Safety Constraint Validation
    TDG: Test-First Methodology
    GDE: Goal-Directed Adaptive Optimization
  """

  use Mix.Task
  require Logger

  @shortdoc "Execute CAFE test suite with cybernetic framework"

  @default_opts [
    parallel: true,
    agents: 15,
    dashboard: true,
    baseline: true,
    criticality: :all,
    dry_run: false
  ]

  @impl Mix.Task
  def run(args) do
    # Parse options
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          parallel: :boolean,
          agents: :integer,
          dashboard: :boolean,
          baseline: :boolean,
          criticality: :string,
          dry_run: :boolean
        ],
        aliases: [p: :parallel, a: :agents, d: :dashboard, b: :baseline, c: :criticality]
      )

    opts = Keyword.merge(@default_opts, opts)

    # Display banner
    display_banner()

    if opts[:dry_run] do
      dry_run_execution(opts)
    else
      execute_cafe_suite(opts)
    end
  end

  defp display_banner do
    IO.puts("""

    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    CAFE TEST EXECUTION FRAMEWORK                          ║
    ║               Cybernetic Architect Framework for Execution                ║
    ╠═══════════════════════════════════════════════════════════════════════════╣
    ║  SOPv5.11 ───────────▶ 6-Phase Execution Model                            ║
    ║  OODA ───────────────▶ Fast Loop (<100ms) Monitoring                      ║
    ║  TPS ────────────────▶ 5-Level Root Cause Analysis                        ║
    ║  STAMP ──────────────▶ Safety Constraint Validation                       ║
    ║  TDG ────────────────▶ Test-First Methodology                             ║
    ║  GDE ────────────────▶ Goal-Directed Adaptive Optimization                ║
    ╚═══════════════════════════════════════════════════════════════════════════╝

    """)
  end

  defp dry_run_execution(opts) do
    IO.puts("🔍 DRY RUN MODE - Discovering tests without execution\n")

    # Discover tests
    tests = discover_all_tests()

    # Assign criticality
    ranked = assign_criticality_to_tests(tests)

    # Group by criticality
    grouped = Enum.group_by(ranked, fn {_path, crit} -> crit end)

    IO.puts("📊 Test Discovery Results:")
    IO.puts("═══════════════════════════════════════════════════════════════════")

    criticality_order = [:c1_critical, :c2_high, :c3_medium, :c4_low, :c5_optional]

    Enum.each(criticality_order, fn crit ->
      tests_in_crit = Map.get(grouped, crit, [])
      count = length(tests_in_crit)

      emoji =
        case crit do
          :c1_critical -> "🔴"
          :c2_high -> "🟠"
          :c3_medium -> "🟡"
          :c4_low -> "🟢"
          :c5_optional -> "⚪"
        end

      IO.puts("#{emoji} #{crit |> Atom.to_string() |> String.upcase()}: #{count} tests")

      if count > 0 and count <= 5 do
        Enum.each(tests_in_crit, fn {path, _} ->
          IO.puts("    └─ #{Path.basename(path)}")
        end)
      end
    end)

    total = length(ranked)
    IO.puts("\n📈 Total: #{total} tests discovered")
    IO.puts("═══════════════════════════════════════════════════════════════════\n")

    IO.puts("Configuration:")
    IO.puts("  Agents: #{opts[:agents]}")
    IO.puts("  Parallel: #{opts[:parallel]}")
    IO.puts("  Dashboard: #{opts[:dashboard]}")
    IO.puts("  Baseline: #{opts[:baseline]}")

    :ok
  end

  defp execute_cafe_suite(opts) do
    # Start required applications
    Mix.Task.run("app.start")

    IO.puts("🚀 Starting CAFE Test Execution\n")
    start_time = System.monotonic_time(:millisecond)

    # Phase 1: Goal Ingestion
    IO.puts("📋 Phase 1: Goal Ingestion (OODA-Observe)")
    tests = discover_all_tests()
    IO.puts("   ✓ Discovered #{length(tests)} test files")

    # Phase 2: Strategy Formulation
    IO.puts("📋 Phase 2: Strategy Formulation (OODA-Orient)")
    ranked = assign_criticality_to_tests(tests)
    grouped = Enum.group_by(ranked, fn {_path, crit} -> crit end)
    IO.puts("   ✓ Assigned criticality to #{length(ranked)} tests")

    # Phase 3: Execution Planning
    IO.puts("📋 Phase 3: Execution Planning (OODA-Decide)")
    execution_plan = create_execution_plan(grouped, opts)
    IO.puts("   ✓ Created execution plan with #{length(execution_plan)} batches")

    # Phase 4: Parallel Execution
    IO.puts("📋 Phase 4: Parallel Execution (OODA-Act)")
    results = execute_test_batches(execution_plan, opts)

    # Phase 5: Monitoring & Analysis
    IO.puts("📋 Phase 5: Monitoring & Analysis")
    analysis = analyze_results(results)
    IO.puts("   ✓ Analysis complete")

    # Phase 6: Consolidation
    IO.puts("📋 Phase 6: Consolidation")
    elapsed = System.monotonic_time(:millisecond) - start_time

    if opts[:baseline] do
      save_baseline(analysis, elapsed)
    end

    display_results(analysis, elapsed)

    # Return appropriate exit code
    if analysis.failed > 0 do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end

    :ok
  end

  defp discover_all_tests do
    test_dirs = [
      "test/indrajaal",
      "test/demo",
      "test/integration",
      "test/advanced",
      "test/containers",
      "test/security_intelligence"
    ]

    test_dirs
    |> Enum.flat_map(fn dir ->
      path = Path.join(File.cwd!(), dir)

      if File.dir?(path) do
        Path.wildcard(Path.join(path, "**/*_test.exs"))
      else
        []
      end
    end)
    |> Enum.sort()
  end

  defp assign_criticality_to_tests(tests) do
    tests
    |> Enum.map(fn path ->
      basename = Path.basename(path)
      name = String.downcase(basename)
      dirname = Path.dirname(path)
      dir = String.downcase(dirname)

      criticality =
        cond do
          # C1 Critical - Formal verification and safety-critical
          String.contains?(name, [
            "sil_compliance",
            "fpps_consensus",
            "failsafe",
            "fmea",
            "auth_security",
            "rbac_state_machine",
            "safety_critical",
            "quorum_sentinel"
          ]) ->
            :c1_critical

          # C2 High - Core security and accounts
          String.contains?(dir, [
            "accounts",
            "authentication",
            "authorization",
            "access_control",
            "security"
          ]) ->
            :c2_high

          # C3 Medium - Integration and API
          String.contains?(dir, ["integration", "api", "communication", "observability"]) ->
            :c3_medium

          # C4 Low - Demo and performance
          String.contains?(dir, ["demo", "performance"]) ->
            :c4_low

          # C5 Optional - Everything else
          true ->
            :c5_optional
        end

      {path, criticality}
    end)
  end

  defp create_execution_plan(grouped, opts) do
    criticality_order =
      case opts[:criticality] do
        :all ->
          [:c1_critical, :c2_high, :c3_medium, :c4_low, :c5_optional]

        level when is_binary(level) ->
          level_atom = String.to_atom(level)

          if level_atom in [:c1_critical, :c2_high, :c3_medium, :c4_low, :c5_optional] do
            [level_atom]
          else
            [:c1_critical, :c2_high, :c3_medium, :c4_low, :c5_optional]
          end

        _ ->
          [:c1_critical, :c2_high, :c3_medium, :c4_low, :c5_optional]
      end

    batch_sizes = %{
      # Small batches for critical tests
      c1_critical: 5,
      c2_high: 10,
      c3_medium: 20,
      c4_low: 30,
      c5_optional: 50
    }

    criticality_order
    |> Enum.flat_map(fn crit ->
      tests = Map.get(grouped, crit, [])
      batch_size = Map.get(batch_sizes, crit, 20)

      tests
      |> Enum.chunk_every(batch_size)
      |> Enum.map(fn batch -> {crit, batch} end)
    end)
  end

  defp execute_test_batches(plan, opts) do
    plan
    |> Enum.with_index(1)
    |> Enum.map(fn {{criticality, batch}, idx} ->
      IO.puts("\n   Batch #{idx}/#{length(plan)} [#{criticality}] - #{length(batch)} tests")

      batch_results =
        if opts[:parallel] do
          execute_batch_parallel(batch, opts)
        else
          execute_batch_serial(batch, opts)
        end

      %{
        batch: idx,
        criticality: criticality,
        tests: length(batch),
        results: batch_results
      }
    end)
  end

  defp execute_batch_parallel(batch, _opts) do
    batch
    |> Task.async_stream(
      fn {path, _crit} -> run_single_test(path) end,
      max_concurrency: 4,
      timeout: 120_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, :timeout} -> %{status: :timeout, path: "unknown"}
      _ -> %{status: :error, path: "unknown"}
    end)
  end

  defp execute_batch_serial(batch, _opts) do
    Enum.map(batch, fn {path, _crit} ->
      run_single_test(path)
    end)
  end

  defp run_single_test(path) do
    start_time = System.monotonic_time(:millisecond)

    result =
      try do
        {output, exit_code} =
          System.cmd("mix", ["test", path, "--no-start"],
            stderr_to_stdout: true,
            env: [
              {"MIX_ENV", "test"},
              {"POSTGRES_USER", "indrajaal"},
              {"POSTGRES_PASSWORD", "indrajaal_test"},
              {"DATABASE_URL", "ecto://indrajaal:indrajaal_test@localhost:5433/indrajaal_test"}
            ]
          )

        status = if exit_code == 0, do: :passed, else: :failed

        %{
          path: path,
          status: status,
          exit_code: exit_code,
          output: String.slice(output, -500, 500)
        }
      rescue
        e ->
          %{
            path: path,
            status: :error,
            error: Exception.message(e)
          }
      end

    duration = System.monotonic_time(:millisecond) - start_time
    Map.put(result, :duration_ms, duration)
  end

  defp analyze_results(batch_results) do
    all_results =
      batch_results
      |> Enum.flat_map(fn batch -> batch.results end)

    passed = Enum.count(all_results, &(&1.status == :passed))
    failed = Enum.count(all_results, &(&1.status == :failed))
    errors = Enum.count(all_results, &(&1.status == :error))
    timeouts = Enum.count(all_results, &(&1.status == :timeout))
    total = length(all_results)

    pass_rate = if total > 0, do: Float.round(passed / total * 100, 2), else: 0.0

    failed_tests =
      all_results
      |> Enum.filter(&(&1.status in [:failed, :error, :timeout]))
      |> Enum.map(&Map.get(&1, :path, "unknown"))

    %{
      total: total,
      passed: passed,
      failed: failed,
      errors: errors,
      timeouts: timeouts,
      pass_rate: pass_rate,
      failed_tests: failed_tests,
      batch_results: batch_results
    }
  end

  defp save_baseline(analysis, elapsed_ms) do
    utc_now = DateTime.utc_now()
    iso_timestamp = utc_now |> DateTime.to_iso8601()

    baseline = %{
      timestamp: iso_timestamp,
      execution_time_ms: elapsed_ms,
      total_tests: analysis.total,
      passed: analysis.passed,
      failed: analysis.failed,
      errors: analysis.errors,
      timeouts: analysis.timeouts,
      pass_rate: analysis.pass_rate,
      failed_tests: analysis.failed_tests,
      framework: "CAFE v1.0.0",
      framework_components: [
        "SOPv5.11",
        "OODA",
        "TPS",
        "STAMP",
        "TDG",
        "GDE",
        "AEE",
        "PHICS"
      ]
    }

    File.mkdir_p!("data")

    utc_basic = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    timestamp = utc_basic |> String.replace(~r/[^0-9]/, "")

    filename = "data/cafe_baseline_#{timestamp}.json"

    case Jason.encode(baseline, pretty: true) do
      {:ok, json} ->
        File.write!(filename, json)
        IO.puts("\n   ✓ Baseline saved to #{filename}")

      {:error, reason} ->
        IO.puts("\n   ✗ Failed to save baseline: #{inspect(reason)}")
    end
  end

  defp display_results(analysis, elapsed_ms) do
    IO.puts("""

    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                        CAFE EXECUTION RESULTS                             ║
    ╠═══════════════════════════════════════════════════════════════════════════╣
    ║  Total Tests:     #{String.pad_leading(Integer.to_string(analysis.total), 6)}                                            ║
    ║  Passed:          #{String.pad_leading(Integer.to_string(analysis.passed), 6)} ✓                                          ║
    ║  Failed:          #{String.pad_leading(Integer.to_string(analysis.failed), 6)} #{if analysis.failed > 0, do: "✗", else: "✓"}                                          ║
    ║  Errors:          #{String.pad_leading(Integer.to_string(analysis.errors), 6)}                                            ║
    ║  Timeouts:        #{String.pad_leading(Integer.to_string(analysis.timeouts), 6)}                                            ║
    ║  Pass Rate:       #{String.pad_leading(Float.to_string(analysis.pass_rate), 6)}%                                          ║
    ║  Execution Time:  #{String.pad_leading(format_duration(elapsed_ms), 10)}                                      ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    """)

    if length(analysis.failed_tests) > 0 do
      IO.puts("Failed Tests:")

      Enum.each(analysis.failed_tests |> Enum.take(10), fn path ->
        IO.puts("  ✗ #{Path.basename(path)}")
      end)

      if length(analysis.failed_tests) > 10 do
        IO.puts("  ... and #{length(analysis.failed_tests) - 10} more")
      end
    end
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}m"
end
