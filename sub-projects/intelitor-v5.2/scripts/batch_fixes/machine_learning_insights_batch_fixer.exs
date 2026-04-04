#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule MachineLearningInsightsBatchFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Framework: Machine Learning Insights Batch Fixer

  Systematically fixes undefined variable errors in machine_learning_insights.ex
  following the 200-change batch protocol with compilation validation.
  """

  @file_path "lib/indrajaal/analytics/machine_learning_insights.ex"

  def main(args \\ []) do
    IO.puts("🔧 SOPv5.11 Machine Learning Insights Batch Fixer")
    IO.puts("=" |> String.duplicate(55))

    case args do
      ["--batch", batch_num] -> fix_batch(String.to_integer(batch_num))
      ["--analyze"] -> analyze_errors()
      ["--count-changes"] -> count_potential_changes()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts("""
    Usage:
      elixir scripts/batch_fixes/machine_learning_insights_batch_fixer.exs --analyze
      elixir scripts/batch_fixes/machine_learning_insights_batch_fixer.exs --count-changes
      elixir scripts/batch_fixes/machine_learning_insights_batch_fixer.exs --batch 1

    Options:
      --analyze       Analyze all error patterns in machine_learning_insights.ex
      --count-changes Count total potential changes needed
      --batch N       Apply batch N fixes (200 changes max)
    """)
  end

  defp analyze_errors do
    IO.puts("🔍 Analyzing error patterns in #{@file_path}...")

    if File.exists?(@file_path) do
      content = File.read!(@file_path)

      # Analyze specific error patterns from compilation log
      error_patterns = %{
        "training_data vs trainingdata" => count_parameter_mismatch(content, "trainingdata", "training_data"),
        "current_state vs currentstate" => count_parameter_mismatch(content, "currentstate", "current_state"),
        "metrics_data vs metricsdata" => count_parameter_mismatch(content, "metricsdata", "metrics_data")
      }

      IO.puts("\n📊 ERROR PATTERN ANALYSIS:")
      Enum.each(error_patterns, fn {pattern, count} ->
        IO.puts("  🔹 #{pattern}: #{count} potential mismatches")
      end)

      # Identify specific fix locations
      identify_parameter_mismatches(content)

    else
      IO.puts("❌ File not found: #{@file_path}")
    end
  end

  defp count_parameter_mismatch(content, wrong_param, correct_param) do
    lines = String.split(content, "\n")

    # Find functions with wrong parameter name
    function_lines = Enum.with_index(lines)
    |> Enum.filter(fn {line, _} ->
      (String.contains?(line, "def ") or String.contains?(line, "defp ")) and
      String.contains?(line, wrong_param)
    end)

    if length(function_lines) > 0 do
      # Count usage of correct parameter name in the same file
      correct_usage_count = content
      |> String.split("\n")
      |> Enum.count(fn line ->
        String.contains?(line, correct_param) and
        not String.contains?(line, "def") and
        not String.contains?(line, "#")
      end)

      correct_usage_count
    else
      0
    end
  end

  defp identify_parameter_mismatches(content) do
    IO.puts("\n🎯 IDENTIFIED PARAMETER MISMATCHES:")

    lines = String.split(content, "\n")

    Enum.with_index(lines)
    |> Enum.each(fn {line, index} ->
      cond do
        String.contains?(line, "def generate_insights(metricsdata") ->
          IO.puts("  Line #{index + 1}: metricsdata parameter should be metrics_data")

        String.contains?(line, "def train_performance_models(trainingdata") ->
          IO.puts("  Line #{index + 1}: trainingdata parameter should be training_data")

        String.contains?(line, "def optimize_system_performance(currentstate") ->
          IO.puts("  Line #{index + 1}: currentstate parameter should be current_state")

        String.contains?(line, "training_data") and not String.contains?(line, "def") ->
          IO.puts("  Line #{index + 1}: Uses training_data (should match parameter name)")

        String.contains?(line, "current_state") and not String.contains?(line, "def") ->
          IO.puts("  Line #{index + 1}: Uses current_state (should match parameter name)")

        String.contains?(line, "metrics_data") and not String.contains?(line, "def") ->
          IO.puts("  Line #{index + 1}: Uses metrics_data (should match parameter name)")

        true -> nil
      end
    end)
  end

  defp count_potential_changes do
    IO.puts("📊 Counting total potential changes needed...")

    if File.exists?(@file_path) do
      content = File.read!(@file_path)

      # Count specific fixes needed
      fixes = %{
        parameter_renames: count_parameter_renames_needed(content),
        variable_usage_fixes: count_variable_usage_fixes_needed(content)
      }

      total_changes = Enum.sum(Map.values(fixes))

      IO.puts("\n📋 CHANGE COUNT ANALYSIS:")
      Enum.each(fixes, fn {category, count} ->
        IO.puts("  🔹 #{category}: #{count} changes")
      end)

      IO.puts("\n🎯 TOTAL ESTIMATED CHANGES: #{total_changes}")
      IO.puts("📦 BATCHES NEEDED: #{ceil(total_changes / 200)}")

    else
      IO.puts("❌ File not found: #{@file_path}")
    end
  end

  defp count_parameter_renames_needed(content) do
    # Count how many parameter names need to be changed
    parameter_fixes = [
      {"metricsdata", "metrics_data"},
      {"trainingdata", "training_data"},
      {"currentstate", "current_state"}
    ]

    Enum.count(parameter_fixes, fn {wrong_name, _correct_name} ->
      String.contains?(content, wrong_name)
    end)
  end

  defp count_variable_usage_fixes_needed(content) do
    # Count variable usages that will be automatically fixed
    # when parameter names are corrected
    usage_patterns = ["training_data", "current_state", "metrics_data"]

    usage_patterns
    |> Enum.map(fn pattern ->
      content
      |> String.split("\n")
      |> Enum.count(fn line ->
        String.contains?(line, pattern) and
        not String.contains?(line, "def") and
        not String.contains?(line, "@") and
        not String.contains?(line, "#")
      end)
    end)
    |> Enum.sum()
  end

  defp fix_batch(batch_num) do
    IO.puts("🔧 Applying Batch #{batch_num} fixes to #{@file_path}...")

    if File.exists?(@file_path) do
      content = File.read!(@file_path)

      {fixed_content, changes_made} =
        case batch_num do
          1 -> apply_batch_1_fixes(content)
          _ -> {content, 0}
        end

      if changes_made > 0 do
        File.write!(@file_path, fixed_content)
        IO.puts("✅ Applied #{changes_made} fixes to #{@file_path}")

        # Save change log
        save_change_log(batch_num, changes_made)

        IO.puts("🚨 MANDATORY: Run compilation validation now!")
        IO.puts("Command: env ELIXIR_ERL_OPTIONS=\"+S 16\" mix compile --jobs 16 --warnings-as-errors")
      else
        IO.puts("ℹ️ No changes needed for batch #{batch_num}")
      end

    else
      IO.puts("❌ File not found: #{@file_path}")
    end
  end

  defp apply_batch_1_fixes(content) do
    IO.puts("🎯 Batch 1: Fixing parameter naming mismatches...")

    changes = 0

    # Fix 1: metricsdata -> metrics_data (parameter name)
    {content, changes} = fix_pattern(content, changes, "def generate_insights(metricsdata,", "def generate_insights(metrics_data,")

    # Fix 2: trainingdata -> training_data (parameter name)
    {content, changes} = fix_pattern(content, changes, "def train_performance_models(trainingdata,", "def train_performance_models(training_data,")

    # Fix 3: currentstate -> current_state (parameter name)
    {content, changes} = fix_pattern(content, changes, "def optimize_system_performance(currentstate,", "def optimize_system_performance(current_state,")

    {content, changes}
  end

  defp fix_pattern(content, changes, old_pattern, new_pattern) do
    if String.contains?(content, old_pattern) do
      occurrences = count_occurrences(content, old_pattern)
      new_content = String.replace(content, old_pattern, new_pattern, global: true)
      new_changes = changes + occurrences

      if occurrences > 0 do
        IO.puts("  ✅ Fixed #{occurrences}x: #{old_pattern} -> #{new_pattern}")
      end

      {new_content, new_changes}
    else
      {content, changes}
    end
  end

  defp count_occurrences(content, pattern) do
    content
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end

  defp save_change_log(batch_num, changes_made) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./data/tmp/machine_learning_insights_batch#{batch_num}_changes_#{timestamp}.log"

    log_content = """
    SOPv5.11 Batch Fix Log
    ====================
    File: #{@file_path}
    Batch: #{batch_num}
    Changes Applied: #{changes_made}
    Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    Parameter Fixes Applied:
    - metricsdata -> metrics_data
    - trainingdata -> training_data
    - currentstate -> current_state

    Next Steps:
    1. Run compilation validation: env ELIXIR_ERL_OPTIONS="+fnu +S 16" mix compile --jobs 16 --warnings-as-errors
    2. If successful, commit changes and proceed to next batch
    3. If failed, analyze errors and adjust fixes
    """

    File.write!(filename, log_content)
    IO.puts("📝 Change log saved to: #{filename}")
  end
end

# Execute with command line arguments
System.argv() |> MachineLearningInsightsBatchFixer.main()