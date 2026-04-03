#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FixCyberneticControllerErrors do
  @moduledoc """
  Fix undefined variable errors in cybernetic_controller.ex
  Addresses specific compilation errors found during systematic compilation
  """

  def main(args \\ []) do
    IO.puts("🚀 Fix Cybernetic Controller Undefined Variable Errors")
    IO.puts("📊 Fixing specific compilation errors")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--fix"] -> fix_controller_errors()
      ["--analyze"] -> analyze_controller_errors()
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --fix      # Fix the cybernetic controller errors
      elixir #{__ENV__.file} --analyze  # Analyze the errors
    """)
  end

  def fix_controller_errors do
    file_path = "lib/indrajaal/coordination/cybernetic_controller.ex"
    IO.puts("🔧 Fixing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = apply_specific_fixes(content)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Fixed undefined variable errors in #{file_path}")

          # Log the changes
          log_file = "./data/tmp/#{current_timestamp()}-cybernetic-controller-fix.log"
          log_entry = """
          Cybernetic Controller Error Fix Applied: #{file_path}

          Fixed Issues:
          - rca_result → rcaresult (line 643)
          - interval_ms → intervalms (lines 777, 781)
          - new_mode → newmode (line 799)
          - goal_analysis → goalanalysis (line 853)
          - goal_spec → goalspec (line 960)
          - feedback_loops → feedbackloops parameter issues
          - learning_system → learningsystem parameter issues

          Timestamp: #{current_timestamp()}
          """
          File.write!(log_file, log_entry)
        else
          IO.puts("  ℹ️ No fixes needed in #{file_path}")
        end

        # Test compilation
        test_compilation()

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  defp apply_specific_fixes(content) do
    content
    # Fix line 643: undefined variable "rca_result" → "rcaresult"
    |> String.replace(
      "update_error_metrics(recovery_state.performance_metrics, error, rca_result)",
      "update_error_metrics(recovery_state.performance_metrics, error, rcaresult)"
    )
    # Fix lines 777, 781: interval_ms → intervalms
    |> String.replace(
      "Process.send_after(self(), :evaluate_system, interval_ms)",
      "Process.send_after(self(), :evaluate_system, intervalms)"
    )
    |> String.replace(
      "Process.send_after(self(), :update_learning, interval_ms)",
      "Process.send_after(self(), :update_learning, intervalms)"
    )
    # Fix line 799: new_mode → newmode
    |> String.replace(
      "%{state | control_mode: new_mode}",
      "%{state | control_mode: newmode}"
    )
    # Fix line 853: goal_analysis → goalanalysis (if this parameter exists)
    |> String.replace(
      "case goal_analysis.complexity_score do",
      "case goalanalysis.complexity_score do"
    )
    # Fix line 960: goal_spec → goalspec (if this parameter exists)
    |> String.replace(
      "apply_tps_rca_analysis(error, goal_spec, state)",
      "apply_tps_rca_analysis(error, goalspec, state)"
    )
    # Fix feedback_loops parameter issues - need to check specific function signatures
    |> fix_parameter_mismatches()
  end

  defp fix_parameter_mismatches(content) do
    content
    # Fix functions that use feedback_loops but parameter might be different
    |> String.replace(
      ~r/defp count_active_feedback_loops\(([^)]+)\) do\s*feedback_loops/,
      "defp count_active_feedback_loops(\\1) do\n    \\1"
    )
    |> String.replace(
      ~r/defp update_feedback_loop\(([^,]+), ([^,]+), ([^)]+)\) do\s*Map\.update!\(feedback_loops,/,
      "defp update_feedback_loop(\\1, \\2, \\3) do\n    Map.update!(\\1,"
    )
    # Fix learning_system parameter issues
    |> String.replace(
      ~r/defp get_recent_learning_insights\(([^)]+)\) do\s*if learning_system/,
      "defp get_recent_learning_insights(\\1) do\n    if \\1"
    )
  end

  def analyze_controller_errors do
    file_path = "lib/indrajaal/coordination/cybernetic_controller.ex"
    IO.puts("🔍 Analyzing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Find lines with specific error patterns
        error_lines = lines
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} ->
          String.contains?(line, "rca_result") or
          String.contains?(line, "interval_ms") or
          String.contains?(line, "new_mode") or
          String.contains?(line, "goal_analysis") or
          String.contains?(line, "goal_spec") or
          String.contains?(line, "feedback_loops") or
          String.contains?(line, "learning_system")
        end)

        IO.puts("  📋 Found #{length(error_lines)} problematic lines:")
        Enum.each(error_lines, fn {line, line_num} ->
          IO.puts("    Line #{line_num}: #{String.trim(line)}")
        end)

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  defp test_compilation do
    IO.puts("🧪 Testing compilation after fixes...")

    case System.cmd("mix", ["compile", "lib/indrajaal/coordination/cybernetic_controller.ex", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful - cybernetic controller fixed!")
        true
      {output, _} ->
        IO.puts("❌ Compilation still has issues:")

        # Show first few errors
        errors = output
        |> String.split("\n")
        |> Enum.filter(&(String.contains?(&1, "error:") or String.contains?(&1, "** (")))
        |> Enum.take(5)

        Enum.each(errors, fn error ->
          IO.puts("  #{error}")
        end)

        false
    end
  end

  defp current_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Execute
FixCyberneticControllerErrors.main(System.argv())