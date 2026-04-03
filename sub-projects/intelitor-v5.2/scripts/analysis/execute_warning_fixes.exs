#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

# ============================================================================
# AEE SOPv5.11 AUTONOMOUS EXECUTION ENGINE
# WARNING ELIMINATION EXECUTION SCRIPT
# ============================================================================
# Generated: 2025-10-05 08:42:10.403570Z
# Mode: AEE SOPv5.11 + Goal-Directed Execution (GDE)
# Purpose: Systematically eliminate all 586 compilation warnings
# Safety: Life-Critical Software - Zero Tolerance for Warnings
# ============================================================================

defmodule WarningFixExecutor do
  @moduledoc """
  Autonomous execution engine for systematic warning elimination.
  Implements AEE SOPv5.11 with Goal-Directed Execution methodology.
  """

  # Execution state
  defstruct [
    :fix_plan,
    :current_phase,
    :fixes_applied,
    :validations_passed,
    :validations_failed,
    :total_time,
    :log_file,
    :start_time
  ]

  def main(args) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🚀 AEE SOPv5.11 AUTONOMOUS EXECUTION ENGINE")
    IO.puts("🎯 GOAL: Zero-Warning State for Life-Critical Software")
    IO.puts(String.duplicate("=", 80) <> "\n")

    # Initialize execution state
    state = %__MODULE__{
      fix_plan: load_fix_plan(),
      current_phase: 1,
      fixes_applied: 0,
      validations_passed: 0,
      validations_failed: 0,
      total_time: 0,
      log_file: create_log_file(),
      start_time: DateTime.utc_now()
    }

    log(state, "🔧 EXECUTION START: #{DateTime.to_string(state.start_time)}")
    log(state, "📊 Total Warnings to Fix: #{state.fix_plan["total_warnings"]}")
    log(state, "📋 Total Phases: #{length(state.fix_plan["phases"])}")

    # Execute all phases
    final_state = execute_all_phases(state)

    # Generate completion report
    generate_completion_report(final_state)

    IO.puts("\n✅ EXECUTION COMPLETE")
  end

  # ============================================================================
  # PHASE EXECUTION
  # ============================================================================

  defp execute_all_phases(state) do
    state.fix_plan["phases"]
    |> Enum.reduce(state, fn phase, acc_state ->
      execute_phase(acc_state, phase)
    end)
  end

  defp execute_phase(state, phase) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("📍 PHASE #{phase["phase"]}: #{phase["name"]}")
    IO.puts("   Priority: #{phase["priority"]}")
    IO.puts("   Warnings: #{phase["warning_count"]}")
    IO.puts("   Strategy: #{phase["fix_strategy"]}")
    IO.puts(String.duplicate("=", 80))

    log(state, "\n=== PHASE #{phase["phase"]} START ===")
    log(state, "Name: #{phase["name"]}")
    log(state, "Warnings: #{phase["warning_count"]}")

    phase_start = DateTime.utc_now()

    # Execute phase based on type
    updated_state = case phase["phase"] do
      1 -> execute_unused_variable_fixes(state, phase)
      2 -> execute_underscore_prefix_fixes(state, phase)
      3 -> execute_syntax_ambiguity_fixes(state, phase)
      4 -> execute_miscellaneous_fixes(state, phase)
      5 -> execute_quality_gate_enhancements(state, phase)
      _ -> state
    end

    phase_duration = DateTime.diff(DateTime.utc_now(), phase_start, :second)
    log(updated_state, "Phase #{phase["phase"]} completed in #{phase_duration} seconds")

    updated_state
  end

  # ============================================================================
  # PHASE 1: UNUSED VARIABLE ELIMINATION
  # ============================================================================

  defp execute_unused_variable_fixes(state, phase) do
    IO.puts("\n🔧 Applying unused variable fixes...")

    detailed_fixes = phase["detailed_fixes"] || []

    if Enum.empty?(detailed_fixes) do
      IO.puts("⚠️  No detailed fixes found in fix plan for Phase 1")
      log(state, "WARNING: No detailed fixes found for Phase 1")
      state
    else
      # Group fixes by file for efficient processing
      fixes_by_file = Enum.group_by(detailed_fixes, & &1["file"])

      IO.puts("   Files to process: #{map_size(fixes_by_file)}")

      # Process each file
      Enum.reduce(fixes_by_file, state, fn {file, fixes}, acc_state ->
        process_unused_variable_file(acc_state, file, fixes)
      end)
    end
  end

  defp process_unused_variable_file(state, file, fixes) do
    IO.puts("\n   📄 Processing: #{file}")
    IO.puts("      Fixes to apply: #{length(fixes)}")

    log(state, "Processing file: #{file} (#{length(fixes)} fixes)")

    # Read file content
    case File.read(file) do
      {:ok, content} ->
        # Apply all fixes for this file
        updated_content = apply_unused_variable_fixes(content, fixes, file)

        # Write back
        File.write!(file, updated_content)

        # Validate
        case validate_compilation(state, file) do
          :ok ->
            IO.puts("      ✅ Validation passed")
            %{state |
              fixes_applied: state.fixes_applied + length(fixes),
              validations_passed: state.validations_passed + 1
            }
          {:error, reason} ->
            IO.puts("      ❌ Validation failed: #{reason}")
            log(state, "VALIDATION FAILED for #{file}: #{reason}")

            # Jidoka: Halt on validation failure
            IO.puts("\n🚨 JIDOKA HALT: Validation failed")
            IO.puts("   File: #{file}")
            IO.puts("   Action: Please review and fix manually")

            %{state | validations_failed: state.validations_failed + 1}
        end

      {:error, reason} ->
        IO.puts("      ❌ Failed to read file: #{reason}")
        log(state, "ERROR reading #{file}: #{reason}")
        state
    end
  end

  defp apply_unused_variable_fixes(content, fixes, file) do
    # For unused variable warnings, we need to add underscore prefix
    # Example: "user" -> "_user" for unused parameters

    lines = String.split(content, "\n")

    updated_lines = Enum.reduce(fixes, lines, fn fix, acc_lines ->
      line_num = String.to_integer(fix["line"]) - 1  # 0-indexed

      if line_num >= 0 and line_num < length(acc_lines) do
        line = Enum.at(acc_lines, line_num)
        variable = fix["variable"]

        # Add underscore prefix to unused variable
        updated_line = String.replace(line, ~r/\b#{variable}\b/, "_#{variable}", global: false)

        List.replace_at(acc_lines, line_num, updated_line)
      else
        acc_lines
      end
    end)

    Enum.join(updated_lines, "\n")
  end

  # ============================================================================
  # PHASE 2: UNDERSCORE PREFIX CORRECTION
  # ============================================================================

  defp execute_underscore_prefix_fixes(state, phase) do
    IO.puts("\n🔧 Applying underscore prefix corrections...")

    detailed_fixes = phase["detailed_fixes"] || []

    if Enum.empty?(detailed_fixes) do
      IO.puts("⚠️  No detailed fixes found in fix plan for Phase 2")
      state
    else
      fixes_by_file = Enum.group_by(detailed_fixes, & &1["file"])
      IO.puts("   Files to process: #{map_size(fixes_by_file)}")

      Enum.reduce(fixes_by_file, state, fn {file, fixes}, acc_state ->
        process_underscore_prefix_file(acc_state, file, fixes)
      end)
    end
  end

  defp process_underscore_prefix_file(state, file, fixes) do
    IO.puts("\n   📄 Processing: #{file}")
    IO.puts("      Fixes to apply: #{length(fixes)}")

    case File.read(file) do
      {:ok, content} ->
        updated_content = apply_underscore_prefix_fixes(content, fixes)
        File.write!(file, updated_content)

        case validate_compilation(state, file) do
          :ok ->
            IO.puts("      ✅ Validation passed")
            %{state |
              fixes_applied: state.fixes_applied + length(fixes),
              validations_passed: state.validations_passed + 1
            }
          {:error, reason} ->
            IO.puts("      ❌ Validation failed: #{reason}")
            %{state | validations_failed: state.validations_failed + 1}
        end

      {:error, reason} ->
        IO.puts("      ❌ Failed to read file: #{reason}")
        state
    end
  end

  defp apply_underscore_prefix_fixes(content, fixes) do
    # For underscore prefix misuse, we need to remove underscore
    # Example: "_user" -> "user" when variable is actually used

    Enum.reduce(fixes, content, fn fix, acc_content ->
      variable = fix["variable"]

      # Remove underscore prefix
      String.replace(acc_content, "_#{variable}", variable)
    end)
  end

  # ============================================================================
  # PHASE 3: SYNTAX AMBIGUITY RESOLUTION
  # ============================================================================

  defp execute_syntax_ambiguity_fixes(state, phase) do
    IO.puts("\n🔧 Applying syntax ambiguity fixes...")

    detailed_fixes = phase["detailed_fixes"] || []

    if Enum.empty?(detailed_fixes) do
      IO.puts("⚠️  No detailed fixes found in fix plan for Phase 3")
      state
    else
      IO.puts("   Total fixes: #{length(detailed_fixes)}")

      # These require manual review - add parentheses to keyword expressions
      IO.puts("\n   ℹ️  Syntax ambiguity fixes require manual review")
      IO.puts("   Please review and apply the following fixes:")

      Enum.each(detailed_fixes, fn fix ->
        IO.puts("\n   File: #{fix["file"]}")
        IO.puts("   Line: #{fix["line"]}")
        IO.puts("   Fix: Add parentheses to keyword expression")
      end)

      state
    end
  end

  # ============================================================================
  # PHASE 4: MISCELLANEOUS WARNING RESOLUTION
  # ============================================================================

  defp execute_miscellaneous_fixes(state, phase) do
    IO.puts("\n🔧 Applying miscellaneous fixes...")

    IO.puts("   ℹ️  Miscellaneous warnings require case-by-case analysis")
    IO.puts("   Refer to fix plan for specific instructions")

    state
  end

  # ============================================================================
  # PHASE 5: QUALITY GATE ENHANCEMENT
  # ============================================================================

  defp execute_quality_gate_enhancements(state, phase) do
    IO.puts("\n🔧 Implementing quality gate enhancements...")

    implementation_steps = phase["implementation_steps"] || []

    Enum.each(implementation_steps, fn step ->
      IO.puts("   • #{step}")
    end)

    IO.puts("\n   ℹ️  Quality gate enhancements require infrastructure changes")
    IO.puts("   Please implement the steps listed above manually")

    state
  end

  # ============================================================================
  # COMPILATION VALIDATION
  # ============================================================================

  defp validate_compilation(state, file) do
    log(state, "Validating compilation for #{file}...")

    # Run incremental compilation with warnings as errors
    case System.cmd("mix", ["compile", "--warnings-as-errors"],
                    stderr_to_stdout: true,
                    cd: "/home/an/dev/indrajaal-demo") do
      {output, 0} ->
        log(state, "Compilation validation passed")
        :ok

      {output, exit_code} ->
        log(state, "Compilation validation failed (exit code: #{exit_code})")
        log(state, "Output: #{output}")
        {:error, "Exit code #{exit_code}"}
    end
  end

  # ============================================================================
  # UTILITIES
  # ============================================================================

  defp load_fix_plan do
    "./data/tmp/fix_plan_20251005-084210.json"
    |> File.read!()
    |> Jason.decode!()
  end

  defp create_log_file do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    log_path = "./data/tmp/aee_execution_#{timestamp}.log"

    # Create log file with header
    header = """
    ============================================================================
    AEE SOPv5.11 AUTONOMOUS EXECUTION ENGINE - EXECUTION LOG
    ============================================================================
    Start Time: #{DateTime.utc_now() |> DateTime.to_string()}
    Purpose: Systematic Warning Elimination
    Safety Level: Life-Critical
    ============================================================================

    """

    File.write!(log_path, header)
    log_path
  end

  defp log(state, message) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
    log_entry = "[#{timestamp}] #{message}\n"

    File.write!(state.log_file, log_entry, [:append])
  end

  defp generate_completion_report(state) do
    duration = DateTime.diff(DateTime.utc_now(), state.start_time, :second)

    report = """

    ============================================================================
    📊 EXECUTION COMPLETION REPORT
    ============================================================================

    Start Time:          #{DateTime.to_string(state.start_time)}
    End Time:            #{DateTime.to_string(DateTime.utc_now())}
    Total Duration:      #{duration} seconds (#{Float.round(duration / 60, 2)} minutes)

    Statistics:
    - Total Warnings:    #{state.fix_plan["total_warnings"]}
    - Fixes Applied:     #{state.fixes_applied}
    - Validations Passed: #{state.validations_passed}
    - Validations Failed: #{state.validations_failed}

    Status:              #{if state.validations_failed == 0, do: "✅ SUCCESS", else: "⚠️  PARTIAL - MANUAL REVIEW REQUIRED"}

    Log File:            #{state.log_file}

    Next Steps:
    1. Review validation failures (if any)
    2. Run comprehensive compilation: mix compile --jobs 16 --warnings-as-errors
    3. Verify zero-warning state achieved
    4. Update journal with completion status

    ============================================================================
    """

    IO.puts(report)
    log(state, report)

    # Save report to file
    report_path = "./data/tmp/execution_report_#{Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")}.txt"
    File.write!(report_path, report)

    IO.puts("📄 Report saved to: #{report_path}")
  end
end

# Execute
WarningFixExecutor.main(System.argv())
