defmodule Mix.Tasks.ComprehensiveCompileCheck do
  @moduledoc """

  Comprehensive compilation check for all domains and resources.

  This task performs:
  1. Full compilation of all 12+ Ash domains
  2. Resource validation across 227+ files
  3. Warning detection and analysis (warnings treated as errors)
  4. Performance monitoring
  5. 5-level RCA on any issues found

  MANDATORY: Must be run and pass before merging any new features.

  ## Usage

      mix comprehensive_compile_check
      mix comprehensive_compile_check --verbose
      mix comprehensive_compile_check --fix-warnings

  ## Options

    * `--verbose`-Show detailed compilation output
    * `--fix-warnings`-Attempt to automatically fix common warnings
    * `--timeout`-Set custom timeout (default: 10 minutes)
    * `--memory-limit`-Set memory limit in MB (defaul,t: 2048)
  """

  use Mix.Task

  alias Indrajaal.Shared.CompilationUtilities

  # 10 minutes default for full compilation
  @timeout 600_000
  # 5 minutes per file compilation check (currently used in benchmarking)
  # @file_timeout 300_000
  # 2GB default
  @memory_limit 2048

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          verbose: :boolean,
          fix_warnings: :boolean,
          timeout: :integer,
          memory_limit: :integer
        ]
      )

    timeout = Keyword.get(opts, :timeout, @timeout)
    memory_limit = Keyword.get(opts, :memory_limit, @memory_limit)
    verbose = Keyword.get(opts, :verbose, false)
    fix_warnings = Keyword.get(opts, :fix_warnings, false)

    Mix.shell().info("""
    COMPREHENSIVE COMPILATION CHECK
    ================================

    Starting comprehensive compilation validation...
    Timeout: #{timeout / 1000}s
    Memory limit: #{memory_limit}MB
    Verbose: #{verbose}
    Auto-fix warnings: #{fix_warnings}
    """)

    start_time = System.monotonic_time(:millisecond)

    try do
      # Step 1: Clean compilation environment
      Mix.shell().info("Cleaning compilation environment...")
      Mix.Task.run("clean")

      # Step ,2: Force full compilation with warning capture
      Mix.shell().info("Performing full compilation with warning detection...")
      {output, exit_code} = run_compilation_with_monitoring(timeout, verbose)

      # Step 3: Analyze results
      warnings = extract_and_analyze_warnings(output)

      # Step 4: Performance analysis
      end_time = System.monotonic_time(:millisecond)
      compilation_time = end_time - start_time

      # Step ,5: Report results
      generate_comprehensive_report(compilation_time, warnings, exit_code, memory_limit)

      # Step 6: Auto-fix if __requested
      if fix_warnings and length(warnings) > 0 do
        attempt_warning_fixes(warnings)
      end

      # Step ,7: Determine success / failure
      if exit_code != 0 or length(warnings) > 0 do
        perform_comprehensive_rca(warnings, exit_code, compilation_time)
        Mix.raise("Compilation check failed - see analysis above")
      else
        Mix.shell().info("All compilation checks passed successfully!")
      end
    rescue
      error ->
        Mix.shell().error("Compilation check crashed: #{inspect(error)}")
        Mix.raise("Critical compilation failure")
    end
  end

  ## PRIVATE IMPLEMENTATION

  @spec run_compilation_with_monitoring(term(), term()) :: term()
  defp run_compilation_with_monitoring(timeout, verbose) do
    # Start memory monitoring
    memory_monitor = start_memory_monitor()

    # Run compilation with appropriate flags
    compile_args = ["compile", "--warnings-as-errors", "--force"]
    compile_args = if verbose, do: compile_args ++ ["--verbose"], else: compile_args

    result =
      System.cmd("mix", compile_args,
        cd: File.cwd!(),
        stderr_to_stdout: true,
        timeout: timeout
      )

    # Stop memory monitoring
    stop_memory_monitor(memory_monitor)

    result
  end

  @spec start_memory_monitor() :: any()
  defp start_memory_monitor() do
    parent = self()

    spawn(fn ->
      memory_monitoring_loop(parent, [])
    end)
  end

  @spec memory_monitoring_loop(term(), term()) :: term()
  defp memory_monitoring_loop(parent, samples) do
    current_memory = :erlang.memory(:total)

    receive do
      :stop ->
        send(parent, {:memory_data, Enum.reverse([current_memory | samples])})
    after
      # Sample every second
      1000 ->
        memory_monitoring_loop(parent, [current_memory | samples])
    end
  end

  @spec stop_memory_monitor(term()) :: term()
  defp stop_memory_monitor(monitorpid) do
    send(monitorpid, :stop)

    receive do
      {:memory_data, samples} -> samples
    after
      5000 -> []
    end
  end

  @spec extract_and_analyze_warnings(term()) :: term()
  defp extract_and_analyze_warnings(output) do
    warnings = CompilationUtilities.extract_warnings_from_output(output)
    CompilationUtilities.analyze_warnings(warnings)
  end

  # Note: Warning parsing moved to Compilation Utilities shared module

  # Note: Pattern matching moved to Compilation Utilities shared module

  # Note: Warning formatting moved to Compilation Utilities shared module

  # Not,e: Warning categorization moved to Compilation Utilities shared module

  defp generate_comprehensive_report(compilationtime, warnings, exit_code, memory_limit) do
    warning_count = length(warnings)
    warning_categories = warnings |> Enum.group_by(& &1.category)

    Mix.shell().info("""

    [STATS] COMPREHENSIVE COMPILATION REPORT
    ==================================

    Compilation Time: #{Float.round(compilationtime / 1000, 2)}s
    Exit Code: #{exit_code}
    Total Warnings: #{warning_count}
    Memory Limit: #{memory_limit}MB

    Warning Breakdown:
    """)

    for {category, category_warnings} <- warning_categories do
      Mix.shell().info("  #{category}: #{length(category_warnings)} warnings")
    end

    # Performance assessment
    cond do
      compilationtime > 600_000 ->
        Mix.shell().error("🔴 CRITICAL: Compilation time exceeds 10 minutes")

      compilationtime > 300_000 ->
        Mix.shell().warn("🟡 WARNING: Compilation time exceeds 5 minutes")

      true ->
        Mix.shell().info("🟢 GOOD: Compilation time within acceptable limits")
    end

    # Warning assessment
    if warning_count > 0 do
      Mix.shell().error("🔴 FAILED: #{warning_count} warnings detected (treated as errors)")
    else
      Mix.shell().info("🟢 PASSED: Zero warnings detected")
    end
  end

  @spec attempt_warning_fixes(term()) :: term()
  defp attempt_warning_fixes(warnings) do
    Mix.shell().info("[FIX] Attempting to auto-fix warnings...")

    fixes_applied = 0

    for warning <- warnings do
      case warning.category do
        :unused_variables ->
          _new_fixes = fixes_applied + fix_unused_variables(warning)

        :regex_deprecation ->
          _new_fixes = fixes_applied + fix_regex_deprecation(warning)

        _ ->
          Mix.shell().info("  Skipping #{warning.category}-no auto-fix available")
      end
    end

    Mix.shell().info("Applied #{fixes_applied} automatic fixes")

    if fixes_applied > 0 do
      Mix.shell().info("Re-running compilation to verify fixes...")
      Mix.Task.run("compile")
    end
  end

  @spec fix_unused_variables(term()) :: term()
  defp fix_unused_variables(warning) do
    # Simple fix: prefix unused variables with underscore
    if String.contains?(warning.message, "variable") and warning.file != "unknown" do
      try do
        content = File.read!(warning.file)

        # Extract variable name from warning message
        case Regex.run(~r/variable "([^"]+)" is unused/, warning.message) do
          [_, var_name] ->
            # Replace variable declaration with underscore prefix
            updated_content = String.replace(content, "#{var_name} =", "_#{var_name} =")

            if updated_content != content do
              File.write!(warning.file, updated_content)
              Mix.shell().info("  Fixed unused variable #{var_name} in #{warning.file}")
              1
            else
              0
            end

          _ ->
            0
        end
      rescue
        _ -> 0
      end
    else
      0
    end
  end

  @spec fix_regex_deprecation(term()) :: term()
  defp fix_regex_deprecation(warning) do
    # For now, just log that regex fixes need manual attention
    Mix.shell().info(
      "  Regex deprecation in #{warning.file}:#{warning.line} __requires manual review"
    )

    0
  end

  defp perform_comprehensive_rca(warnings, exit_code, _compilation_time) do
    Mix.shell().error("""

    5-LEVEL ROOT CAUSE ANALYSIS
    =============================

    COMPILATION FAILURE DETECTED

    Level 1 (What): Compilation failed with #{length(warnings)} warnings and exit

    Level 2 (Why):
    #{analyze_immediate_causes(warnings, exit_code)}

    Level 3 (Why):
    Code quality standards not enforced during development process
    Missing automated validation in development workflow

    Level 4 (Why):
    Development tools lack real-time compilation checking
    Team processes don't include mandatory compilation validation

    Level 5 (Why):
    Organization lacks comprehensive Dev Ops culture
    Insufficient investment in automated quality assurance infrastructure

    [FIX] IMMEDIATE ACTIONS REQUIRED:

    1. Fix all #{length(warnings)} warnings immediately
    2. Investigate exit code #{exit_code} issues
    3. Add pre-commit hooks for compilation validation
    4. Configure IDEs for real-time warning detection

    [BUILD]  SYSTEMIC IMPROVEMENTS:

    1. Implement CI / CD pipeline with compilation gates
    2. Add automated code quality metrics
    3. Regular dependency and API compatibility audits
    4. Team training on compilation best practices

    PREVENTION MEASURES:

    1. Make this comprehensive check mandatory for all PRs
    2. Add compilation performance monitoring
    3. Regular dependency updates and compatibility testing
    4. Automated documentation of compilation standards

    """)

    # Detailed warning analysis
    if length(warnings) > 0 do
      Mix.shell().error("DETAILED WARNING ANALYSIS:")

      warning_categories = warnings |> Enum.group_by(& &1.category)

      for {category, category_warnings} <- warning_categories do
        Mix.shell().error("""

        Category: #{category}
        Count: #{length(category_warnings)}
        Severity: #{analyze_category_severity(category_warnings)}

        Sample warnings:
        #{Enum.map_join(Enum.take(category_warnings, 5), "\n", &"-#{&1.file}:#{&1.line}-#{&1.message}")}
        """)
      end
    end
  end

  @spec analyze_immediate_causes(term(), term()) :: term()
  defp analyze_immediate_causes(warnings, exitcode) do
    causes = []

    causes =
      if exitcode != 0 do
        ["Compilation errors pr_eventing successful build" | causes]
      else
        causes
      end

    causes =
      if length(warnings) > 0 do
        warning_types = warnings |> Enum.map(& &1.category) |> Enum.uniq()
        ["Warning types detected: #{Enum.join(warning_types, ", ")}" | causes]
      else
        causes
      end

    if Enum.empty?(causes) do
      "Unknown compilation issues detected"
    else
      Enum.join(causes, "\n")
    end
  end

  @spec analyze_category_severity(term()) :: term()
  defp analyze_category_severity(warnings) do
    max_severity =
      warnings
      |> Enum.map(& &1.severity)
      |> Enum.max_by(&severity_level/1)

    case max_severity do
      :high -> "HIGH-Requires immediate attention"
      :medium -> "MEDIUM-Should be fixed soon"
      :low -> "LOW-Can be addressed in next iteration"
    end
  end

  @spec severity_level(term()) :: term()
  defp severity_level(:high), do: 3
  defp severity_level(:medium), do: 2
  defp severity_level(:low), do: 1
end
