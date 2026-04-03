#!/usr/bin/env elixir

# AEE Exhaustive Defensive Validation System
# Date: 2025-09-07 10:15:00 CEST
# Purpose: Extremely thorough validation of all compilation fixes

defmodule AEE.ExhaustiveDefensiveValidation do
  @moduledoc """
  Performs exhaustive and defensive validation of all compilation fixes
  using the full power of the AEE 25-agent architecture.
  """

  __require Logger

  @containers 1..10
  @validation_rounds 3
  @batch_size 25

  def main(args \\ []) do
    IO.puts """
    ╔══════════════════════════════════════════════════════════════╗
    ║        AEE EXHAUSTIVE DEFENSIVE VALIDATION SYSTEM            ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  Agents: 25 (1 Supervisor + 6 Helpers + 18 Workers)         ║
    ║  Containers: 10 PHICS-enabled                                ║
    ║  Validation Rounds: #{@validation_rounds}                    ║
    ║  Zero Tolerance: Enabled                                     ║
    ╚══════════════════════════════════════════════════════════════╝
    """

    start_time = System.monotonic_time(:millisecond)

    # Phase 1: Container Infrastructure Validation
    IO.puts("\n🔍 Phase 1: Container Infrastructure Validation")
    validate_container_infrastructure()

    # Phase 2: Git State Validation
    IO.puts("\n🔍 Phase 2: Git State Validation")
    validate_git_state()

    # Phase 3: Compilation State Analysis
    IO.puts("\n🔍 Phase 3: Initial Compilation State Analysis")
    initial_state = analyze_compilation_state()

    # Phase 4: Multi-Round Exhaustive Validation
    IO.puts("\n🔍 Phase 4: Multi-Round Exhaustive Validation")
    validation_results = perform_exhaustive_validation()

    # Phase 5: Defensive Pattern Checking
    IO.puts("\n🔍 Phase 5: Defensive Pattern Checking")
    pattern_results = check_all_error_patterns()

    # Phase 6: Container-Based Parallel Validation
    IO.puts("\n🔍 Phase 6: Container-Based Parallel Validation")
    parallel_results = parallel_container_validation()

    # Phase 7: Final Compilation Verification
    IO.puts("\n🔍 Phase 7: Final Compilation Verification")
    final_state = final_compilation_check()

    # Phase 8: Generate Comprehensive Report
    IO.puts("\n📊 Phase 8: Generating Comprehensive Report")
    generate_validation_report(initial_state, validation_results, pattern_results, parallel_results, final_state)

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    IO.puts("\n✅ Validation completed in #{duration}ms")
  end

  defp validate_container_infrastructure do
    IO.puts("  Checking container status...")
    
    _containers_status = Enum.map(@containers, fn id ->
      case System.cmd("podman", ["inspect", "aee-container-#{id}", "--format", "{{.State.Status}}"]) do
        {status, 0} -> {id, String.trim(status)}
        _ -> {id, "not_found"}
      end
    end)

    running_count = Enum.count(containers_status, fn {_, status} -> status == "running" end)
    
    if running_count < 10 do
      IO.puts("  ⚠️  Only #{running_count}/10 containers running")
      IO.puts("  🔧 Deploying missing containers...")
      deploy_missing_containers(containers_status)
    else
      IO.puts("  ✅ All 10 containers operational")
    end
  end

  defp validate_git_state do
    IO.puts("  Checking git status...")
    
    {_status_output, __} = System.cmd("git", ["status", "--porcelain"])
    
    if String.trim(status_output) == "" do
      IO.puts("  ✅ Git working directory clean")
    else
      IO.puts("  ⚠️  Uncommitted changes detected:")
      IO.puts("  #{status_output}")
      
      # Create safety checkpoint
      timestamp = Indrajaal.LocalTime.timestamp_string()
      System.cmd("git", ["add", "-A"])
      System.cmd("git", ["commit", "-m", "Safety checkpoint: #{timestamp}"])
      IO.puts("  ✅ Created safety checkpoint")
    end
  end

  defp analyze_compilation_state do
    IO.puts("  Running initial compilation analysis...")
    
    # Capture all output including warnings
    {_output, _exit_code} = System.cmd("mix", ["compile", "--warnings-as-errors"], 
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )
    
    warnings = extract_warnings(output)
    errors = extract_errors(output)
    
    IO.puts("  📊 Initial __state: #{length(errors)} errors, #{length(warnings)} warnings")
    
    %{
      errors: errors,
      warnings: warnings,
      exit_code: exit_code,
      timestamp: Indrajaal.LocalTime.timestamp_string()
    }
  end

  defp perform_exhaustive_validation do
    IO.puts("  Performing #{@validation_rounds} rounds of validation...")
    
    _results = Enum.map(1..@validation_rounds, fn round ->
      IO.puts("\n  🔄 Round #{round}/#{@validation_rounds}")
      
      # Clean build
      IO.puts("    Cleaning build artifacts...")
      System.cmd("rm", ["-rf", "_build/dev/lib/indrajaal"])
      
      # Force recompilation
      IO.puts("    Force recompiling...")
      {_output, _exit_code} = System.cmd("mix", ["compile", "--force", "--warnings-as-errors"],
        stderr_to_stdout: true
      )
      
      warnings = extract_warnings(output)
      errors = extract_errors(output)
      
      IO.puts("    📊 Round #{round}: #{length(errors)} errors, #{length(warnings)} warnings")
      
      %{
        round: round,
        errors: errors,
        warnings: warnings,
        exit_code: exit_code
      }
    end)
    
    results
  end

  defp check_all_error_patterns do
    IO.puts("  Checking all known error patterns...")
    
    patterns = [
      # EP-001: Undefined variables
      %{
        pattern: ~r/variable "(\w+)" is undefined/,
        files: ["lib/**/*.ex"],
        description: "Undefined variable errors"
      },
      # EP-002: Unused variables
      %{
        pattern: ~r/variable "_(\w+)" is unused/,
        files: ["lib/**/*.ex"],
        description: "Unused variable warnings"
      },
      # EP-003: Parameter mismatches
      %{
        pattern: ~r/def \w+\([^)]*_(\w+)[^)]*\).*\n.*\1[^_]/,
        files: ["lib/**/*.ex"],
        description: "Underscore parameter usage"
      },
      # EP-004: Multiple defaults
      %{
        pattern: ~r/def \w+\([^\\]*\\\\ [^)]+\).*\n.*def \w+\([^\\]*\\\\ [^)]+\)/,
        files: ["lib/**/*.ex"],
        description: "Multiple function head defaults"
      }
    ]
    
    _pattern_results = Enum.map(patterns, fn pattern_def ->
      files = Path.wildcard(List.first(pattern_def.files))
      matches = check_pattern_in_files(pattern_def.pattern, files)
      
      IO.puts("    #{pattern_def.description}: #{length(matches)} occurrences")
      
      %{
        description: pattern_def.description,
        matches: matches,
        count: length(matches)
      }
    end)
    
    pattern_results
  end

  defp parallel_container_validation do
    IO.puts("  Running parallel validation across all containers...")
    
    _tasks = Enum.map(@containers, fn container_id ->
      Task.async(fn ->
        validate_in_container(container_id)
      end)
    end)
    
    results = Task.await_many(tasks, :infinity)
    
    # Aggregate results
    total_warnings = Enum.sum(Enum.map(results, & &1.warning_count))
    total_errors = Enum.sum(Enum.map(results, & &1.error_count))
    
    IO.puts("  📊 Parallel validation: #{total_errors} errors, #{total_warnings} warnings across all containers")
    
    %{
      container_results: results,
      total_errors: total_errors,
      total_warnings: total_warnings
    }
  end

  defp validate_in_container(container_id) do
    # Run compilation check in specific container
    {_output, _exit_code} = System.cmd("podman", [
      "exec", "aee-container-#{container_id}",
      "sh", "-c", "cd /workspace && mix compile --jobs 16 --warnings-as-errors 2>&1"
    ])
    
    warnings = extract_warnings(output)
    errors = extract_errors(output)
    
    %{
      container_id: container_id,
      warning_count: length(warnings),
      error_count: length(errors),
      exit_code: exit_code,
      warnings: warnings,
      errors: errors
    }
  end

  defp final_compilation_check do
    IO.puts("  Running final comprehensive compilation check...")
    
    # Use patient mode with full output capture
    env = [
      {"NO_TIMEOUT", "true"},
      {"PATIENT_MODE", "enabled"},
      {"INFINITE_PATIENCE", "true"},
      {"ELIXIR_ERL_OPTIONS", "+S 16"}
    ]
    
    {_output, _exit_code} = System.cmd("mix", ["compile", "--warnings-as-errors"],
      stderr_to_stdout: true,
      env: env
    )
    
    warnings = extract_warnings(output)
    errors = extract_errors(output)
    
    IO.puts("  📊 Final __state: #{length(errors)} errors, #{length(warnings)} warnings")
    
    # List specific issues if any
    if length(errors) > 0 do
      IO.puts("\n  ❌ ERRORS FOUND:")
      Enum.each(errors, fn error ->
        IO.puts("    - #{error}")
      end)
    end
    
    if length(warnings) > 0 do
      IO.puts("\n  ⚠️  WARNINGS FOUND:")
      Enum.each(warnings, fn warning ->
        IO.puts("    - #{warning}")
      end)
    end
    
    %{
      errors: errors,
      warnings: warnings,
      exit_code: exit_code,
      timestamp: Indrajaal.LocalTime.timestamp_string(),
      success: exit_code == 0 && length(errors) == 0 && length(warnings) == 0
    }
  end

  defp extract_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.uniq()
  end

  defp extract_errors(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&(String.contains?(&1, "error:") || String.contains?(&1, "** (")))
    |> Enum.uniq()
  end

  defp check_pattern_in_files(pattern, files) do
    Enum.flat_map(files, fn file ->
      content = File.read!(file)
      matches = Regex.scan(pattern, content)
      
      Enum.map(matches, fn match ->
        %{file: file, match: match}
      end)
    end)
  end

  defp deploy_missing_containers(status_list) do
    Enum.each(status_list, fn {id, status} ->
      if status != "running" do
        IO.puts("    Deploying container #{id}...")
        System.cmd("elixir", ["scripts/aee/deploy_single_container.exs", "--id", "#{id}"])
      end
    end)
  end

  defp generate_validation_report(initial__state, validation_results, pattern_results, parallel_results, final_state) do
    report = """
    ═══════════════════════════════════════════════════════════════
    AEE EXHAUSTIVE DEFENSIVE VALIDATION REPORT
    Generated: #{Indrajaal.LocalTime.timestamp_string()}
    ═══════════════════════════════════════════════════════════════

    INITIAL STATE:
    - Errors: #{length(initial_state.errors)}
    - Warnings: #{length(initial_state.warnings)}

    VALIDATION ROUNDS (#{@validation_rounds} rounds):
    #{format_validation_rounds(validation_results)}

    PATTERN ANALYSIS:
    #{format_pattern_results(pattern_results)}

    PARALLEL CONTAINER VALIDATION:
    - Total Errors: #{parallel_results.total_errors}
    - Total Warnings: #{parallel_results.total_warnings}
    #{format_container_results(parallel_results.container_results)}

    FINAL STATE:
    - Errors: #{length(final_state.errors)}
    - Warnings: #{length(final_state.warnings)}
    - Success: #{final_state.success}

    RECOMMENDATION: #{get_recommendation(final_state)}
    ═══════════════════════════════════════════════════════════════
    """
    
    # Save report
    report_file = "__data/tmp/aee_validation_report_#{Indrajaal.LocalTime.for_filename()}.txt"
    File.write!(report_file, report)
    IO.puts("\n📄 Report saved to: #{report_file}")
    
    if !final_state.success do
      IO.puts("\n🚨 VALIDATION FAILED - ISSUES DETECTED")
      IO.puts("🔧 Initiating automatic fix procedures...")
      initiate_automatic_fixes(final_state)
    else
      IO.puts("\n✅ VALIDATION SUCCESSFUL - ALL CLEAR")
    end
  end

  defp format_validation_rounds(results) do
    Enum.map(results, fn r ->
      "  Round #{r.round}: #{length(r.errors)} errors, #{length(r.warnings)} warnings"
    end)
    |> Enum.join("\n")
  end

  defp format_pattern_results(results) do
    Enum.map(results, fn r ->
      "  #{r.description}: #{r.count} occurrences"
    end)
    |> Enum.join("\n")
  end

  defp format_container_results(results) do
    Enum.map(results, fn r ->
      "  Container #{r.container_id}: #{r.error_count} errors, #{r.warning_count} warnings"
    end)
    |> Enum.join("\n")
  end

  defp get_recommendation(final__state) do
    if final_state.success do
      "✅ SAFE TO MERGE - No issues detected"
    else
      "❌ DO NOT MERGE - Issues must be resolved first"
    end
  end

  defp initiate_automatic_fixes(state) do
    # This would trigger the full AEE fix system
    IO.puts("  Deploying 25 agents for automatic resolution...")
    IO.puts("  Targeting #{length(__state.errors)} errors and #{length(__state.warnings)} warnings")
    
    # Would execute the full fix cycle here
    System.cmd("elixir", ["scripts/aee/autonomous_fix_execution.exs", "--defensive", "--exhaustive"])
  end
end

# Run the validation
AEE.ExhaustiveDefensiveValidation.main(System.argv())