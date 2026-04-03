#!/usr/bin/env elixir
# Coverage Dashboard & Test Partitioning Engine
# SC-COV-001: 100% runtime coverage tracking
# SC-METRICS-003: Parallelization MANDATORY

defmodule CoverageDashboard do
  @moduledoc """
  Real-time test coverage dashboard with partitioning and KPI tracking.
  Parses test output and coverage reports to show progress.
  """

  @test_log "/tmp/test_run_full.log"
  @coverage_dir "cover"

  def run(args \\ []) do
    mode = List.first(args) || "dashboard"

    case mode do
      "dashboard" -> show_dashboard()
      "partition" -> show_partitions()
      "failures" -> show_failures()
      "coverage" -> show_coverage()
      "kpi" -> show_kpis()
      "all" -> show_all()
      _ -> show_dashboard()
    end
  end

  def show_all do
    show_dashboard()
    IO.puts("")
    show_partitions()
    IO.puts("")
    show_failures()
    IO.puts("")
    show_coverage()
  end

  def show_dashboard do
    {total_files, test_files, support_files} = count_test_files()
    {pass, fail, skip, exclude, invalid} = parse_test_results()
    total_tests = pass + fail + skip + exclude + invalid
    coverage_pct = parse_coverage_percentage()
    {compile_errors, compile_warnings} = parse_compile_issues()
    run_time = parse_run_time()
    {tagged_skip, tagged_pending, tagged_containers} = count_tagged()

    pass_rate = if total_tests > 0, do: Float.round(pass / total_tests * 100, 1), else: 0.0
    runtime_coverage = if test_files > 0, do: Float.round((test_files - compile_errors) / test_files * 100, 1), else: 0.0

    IO.puts("""
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  INDRAJAAL TEST COVERAGE DASHBOARD           v21.3.0-SIL6          ║
    ╠══════════════════════════════════════════════════════════════════════╣
    ║                                                                      ║
    ║  ┌─ TEST FILES ─────────────────────────────────────────────────┐   ║
    ║  │  Total test files:     #{pad(test_files, 6)}                              │   ║
    ║  │  Support files:        #{pad(support_files, 6)}                              │   ║
    ║  │  Compile errors:       #{pad(compile_errors, 6)} #{status_icon(compile_errors == 0)}                         │   ║
    ║  │  Compile warnings:     #{pad(compile_warnings, 6)}                              │   ║
    ║  │  Runtime coverage:     #{pad_str("#{runtime_coverage}%", 7)} #{bar(runtime_coverage, 20)}   │   ║
    ║  └──────────────────────────────────────────────────────────────┘   ║
    ║                                                                      ║
    ║  ┌─ TEST EXECUTION ─────────────────────────────────────────────┐   ║
    ║  │  Total tests:          #{pad(total_tests, 6)}                              │   ║
    ║  │  Passed:               #{pad(pass, 6)} #{status_icon(true)}                          │   ║
    ║  │  Failed:               #{pad(fail, 6)} #{status_icon(fail == 0)}                          │   ║
    ║  │  Skipped:              #{pad(skip, 6)}                              │   ║
    ║  │  Excluded:             #{pad(exclude, 6)}                              │   ║
    ║  │  Invalid:              #{pad(invalid, 6)} #{status_icon(invalid == 0)}                          │   ║
    ║  │  Pass rate:            #{pad_str("#{pass_rate}%", 7)} #{bar(pass_rate, 20)}   │   ║
    ║  └──────────────────────────────────────────────────────────────┘   ║
    ║                                                                      ║
    ║  ┌─ COVERAGE & PERFORMANCE ─────────────────────────────────────┐   ║
    ║  │  Code coverage:        #{pad_str("#{coverage_pct}%", 7)} #{bar(coverage_pct, 20)}   │   ║
    ║  │  Run time:             #{pad_str(run_time, 10)}                           │   ║
    ║  │  Parallelization:      #{pad_str("#{System.schedulers_online()} cores", 10)}                           │   ║
    ║  │  Tagged skip:          #{pad(tagged_skip, 6)}                              │   ║
    ║  │  Tagged pending:       #{pad(tagged_pending, 6)}                              │   ║
    ║  │  Requires containers:  #{pad(tagged_containers, 6)}                              │   ║
    ║  └──────────────────────────────────────────────────────────────┘   ║
    ║                                                                      ║
    ║  ┌─ KPIs ───────────────────────────────────────────────────────┐   ║
    ║  │  KPI-1 Runtime coverage:  #{kpi_status(runtime_coverage, 100.0)}                  │   ║
    ║  │  KPI-2 Pass rate:         #{kpi_status(pass_rate, 100.0)}                  │   ║
    ║  │  KPI-3 Code coverage:     #{kpi_status(coverage_pct, 95.0)}                  │   ║
    ║  │  KPI-4 Zero failures:     #{kpi_status(if(fail == 0, do: 100.0, else: 0.0), 100.0)}                  │   ║
    ║  │  KPI-5 Zero invalid:      #{kpi_status(if(invalid == 0, do: 100.0, else: 0.0), 100.0)}                  │   ║
    ║  │  KPI-6 Compile clean:     #{kpi_status(if(compile_errors == 0, do: 100.0, else: 0.0), 100.0)}                  │   ║
    ║  └──────────────────────────────────────────────────────────────┘   ║
    ╚══════════════════════════════════════════════════════════════════════╝
    """)
  end

  def show_partitions do
    partitions = compute_partitions()

    IO.puts("""
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  TEST PARTITIONS (#{length(partitions)} partitions, #{System.schedulers_online()} cores)                            ║
    ╠══════════════════════════════════════════════════════════════════════╣
    """)

    for {name, count, _paths} <- partitions do
      IO.puts("    ║  #{pad_str(name, 40)} #{pad(count, 5)} files              ║")
    end

    IO.puts("    ╚══════════════════════════════════════════════════════════════════════╝")
  end

  def show_failures do
    failures = parse_failures()

    IO.puts("""
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  TEST FAILURES (#{length(failures)} total)                                          ║
    ╠══════════════════════════════════════════════════════════════════════╣
    """)

    for {file, line, desc} <- Enum.take(failures, 50) do
      short_file = String.slice(file, -50..-1//1) || file
      IO.puts("    ║  #{pad_str(short_file, 50)}:#{pad(line, 4)} ║")
      IO.puts("    ║    #{pad_str(String.slice(desc, 0..58), 59)}   ║")
    end

    if length(failures) > 50 do
      IO.puts("    ║  ... and #{length(failures) - 50} more failures                                    ║")
    end

    IO.puts("    ╚══════════════════════════════════════════════════════════════════════╝")
  end

  def show_coverage do
    modules = parse_coverage_modules()

    IO.puts("""
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  CODE COVERAGE BY MODULE (bottom 20)                                ║
    ╠══════════════════════════════════════════════════════════════════════╣
    """)

    for {mod, pct} <- Enum.take(Enum.sort_by(modules, &elem(&1, 1)), 20) do
      short_mod = String.slice(mod, -45..-1//1) || mod
      IO.puts("    ║  #{pad_str(short_mod, 45)} #{pad_str("#{pct}%", 6)} #{bar(pct, 10)} ║")
    end

    IO.puts("    ╚══════════════════════════════════════════════════════════════════════╝")
  end

  def show_kpis do
    {pass, fail, skip, exclude, invalid} = parse_test_results()
    total = pass + fail + skip + exclude + invalid
    coverage = parse_coverage_percentage()
    {errors, _warnings} = parse_compile_issues()
    {total_files, test_files, _} = count_test_files()
    runtime_cov = if test_files > 0, do: Float.round((test_files - errors) / test_files * 100, 1), else: 0.0

    IO.puts("""
    ┌─────────────────────────────────────────────────────────────┐
    │                    KPI SCORECARD                             │
    ├──────────────────────────┬──────────┬───────────┬───────────┤
    │ KPI                      │ Current  │ Target    │ Status    │
    ├──────────────────────────┼──────────┼───────────┼───────────┤
    │ Runtime File Coverage    │ #{pad_str("#{runtime_cov}%", 8)} │ 100.0%    │ #{gate(runtime_cov >= 100.0)} │
    │ Test Pass Rate           │ #{pad_str("#{if(total > 0, do: Float.round(pass/total*100,1), else: 0)}%", 8)} │ 100.0%    │ #{gate(fail == 0)} │
    │ Code Coverage            │ #{pad_str("#{coverage}%", 8)} │ 95.0%     │ #{gate(coverage >= 95.0)} │
    │ Test Failures            │ #{pad(fail, 8)} │ 0         │ #{gate(fail == 0)} │
    │ Compile Errors           │ #{pad(errors, 8)} │ 0         │ #{gate(errors == 0)} │
    │ Invalid Tests            │ #{pad(invalid, 8)} │ 0         │ #{gate(invalid == 0)} │
    │ Total Test Files         │ #{pad(test_files, 8)} │ #{pad(total_files, 9)} │ #{gate(true)} │
    │ Parallel Cores           │ #{pad(System.schedulers_online(), 8)} │ 16        │ #{gate(System.schedulers_online() >= 16)} │
    └──────────────────────────┴──────────┴───────────┴───────────┘
    """)
  end

  # --- Parsing Functions ---

  defp count_test_files do
    {all_str, 0} = System.cmd("find", ["test", "-name", "*.exs", "-type", "f", "-not", "-path", "*/support/*"])
    all = all_str |> String.split("\n", trim: true)
    test_files = Enum.filter(all, &String.ends_with?(&1, "_test.exs"))
    support = length(all) - length(test_files)
    {length(all), length(test_files), support}
  end

  defp count_tagged do
    {skip_out, _} = System.cmd("grep", ["-rl", "@tag.*:skip\\|@moduletag.*:skip", "test/"], stderr_to_stdout: true)
    {pending_out, _} = System.cmd("grep", ["-rl", "@tag.*:pending\\|@moduletag.*:pending", "test/"], stderr_to_stdout: true)
    {cont_out, _} = System.cmd("grep", ["-rl", "@tag.*:requires_containers\\|@moduletag.*:requires_containers", "test/"], stderr_to_stdout: true)
    {
      count_lines(skip_out),
      count_lines(pending_out),
      count_lines(cont_out)
    }
  end

  defp parse_test_results do
    case File.read(@test_log) do
      {:ok, content} ->
        # Look for the summary line: "X tests, Y failures, Z excluded, W skipped, N invalid"
        regex = ~r/(\d+) tests?,\s*(\d+) failures?(?:,\s*(\d+) excluded)?(?:,\s*(\d+) skipped)?(?:,\s*(\d+) invalid)?/
        case Regex.run(regex, content) do
          [_, total, failures | rest] ->
            excluded = Enum.at(rest, 0, "0") |> to_int()
            skipped = Enum.at(rest, 1, "0") |> to_int()
            invalid = Enum.at(rest, 2, "0") |> to_int()
            t = to_int(total)
            f = to_int(failures)
            {t - f - skipped - invalid, f, skipped, excluded, invalid}
          _ -> {0, 0, 0, 0, 0}
        end
      _ -> {0, 0, 0, 0, 0}
    end
  end

  defp parse_coverage_percentage do
    case File.read(@test_log) do
      {:ok, content} ->
        case Regex.run(~r/(?:Total|Overall|Coverage)\s*[:=]\s*([\d.]+)%/, content) do
          [_, pct] -> to_float(pct)
          _ ->
            # Try cover/ directory
            case File.ls("cover") do
              {:ok, files} ->
                case Enum.find(files, &String.ends_with?(&1, ".html")) do
                  nil -> 0.0
                  _file -> 0.0 # Would need to parse HTML
                end
              _ -> 0.0
            end
        end
      _ -> 0.0
    end
  end

  defp parse_compile_issues do
    case File.read(@test_log) do
      {:ok, content} ->
        errors = content |> String.split("\n") |> Enum.count(&String.contains?(&1, "** (CompileError)"))
        comp_errors = content |> String.split("\n") |> Enum.count(&String.contains?(&1, "== Compilation error in file"))
        warnings = content |> String.split("\n") |> Enum.count(&String.match?(&1, ~r/warning:/))
        {errors + comp_errors, warnings}
      _ -> {0, 0}
    end
  end

  defp parse_run_time do
    case File.read(@test_log) do
      {:ok, content} ->
        case Regex.run(~r/Finished in ([\d.]+ \w+)/, content) do
          [_, time] -> time
          _ -> "running..."
        end
      _ -> "no data"
    end
  end

  defp parse_failures do
    case File.read(@test_log) do
      {:ok, content} ->
        Regex.scan(~r/\d+\) (.+)\n\s+(test\/[^\s:]+):(\d+)/, content)
        |> Enum.map(fn [_, desc, file, line] -> {file, to_int(line), desc} end)
      _ -> []
    end
  end

  defp parse_coverage_modules do
    case File.read(@test_log) do
      {:ok, content} ->
        Regex.scan(~r/(\S+)\s+([\d.]+)%/, content)
        |> Enum.filter(fn [_, mod, _] -> String.starts_with?(mod, "Elixir.") or String.contains?(mod, ".") end)
        |> Enum.map(fn [_, mod, pct] -> {mod, to_float(pct)} end)
      _ -> []
    end
  end

  defp compute_partitions do
    {out, 0} = System.cmd("find", ["test", "-name", "*_test.exs", "-type", "f"])
    files = String.split(out, "\n", trim: true)

    groups = Enum.group_by(files, fn f ->
      parts = String.split(f, "/")
      cond do
        length(parts) >= 3 -> Enum.at(parts, 1) <> "/" <> Enum.at(parts, 2)
        length(parts) == 2 -> Enum.at(parts, 1)
        true -> "root"
      end
    end)

    groups
    |> Enum.map(fn {name, paths} -> {name, length(paths), paths} end)
    |> Enum.sort_by(fn {_, count, _} -> -count end)
  end

  # --- Formatting Helpers ---

  defp pad(n, width) when is_integer(n), do: String.pad_leading(Integer.to_string(n), width)
  defp pad(n, width) when is_float(n), do: String.pad_leading(Float.to_string(n), width)
  defp pad_str(s, width), do: String.pad_trailing(s, width)

  defp bar(pct, width) when is_float(pct) do
    filled = round(pct / 100.0 * width)
    empty = width - filled
    "[#{String.duplicate("█", max(filled, 0))}#{String.duplicate("░", max(empty, 0))}]"
  end
  defp bar(_, width), do: "[#{String.duplicate("░", width)}]"

  defp status_icon(true), do: "✓"
  defp status_icon(false), do: "✗"
  defp status_icon(0), do: "✓"
  defp status_icon(_), do: "✗"

  defp kpi_status(current, target) when is_float(current) and is_float(target) do
    status = if current >= target, do: "PASS", else: "FAIL"
    "#{pad_str("#{current}%", 8)} / #{pad_str("#{target}%", 7)} #{status}"
  end
  defp kpi_status(_, _), do: "N/A"

  defp gate(true), do: "  PASS   "
  defp gate(false), do: "  FAIL   "

  defp to_int(s) when is_binary(s), do: String.to_integer(s)
  defp to_int(nil), do: 0

  defp to_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp count_lines(s), do: s |> String.split("\n", trim: true) |> length()
end

# Run with args
CoverageDashboard.run(System.argv())
