#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule AutomatedReportingAlertSystemBatchFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Framework: Automated Reporting Alert System Batch Fixer

  Systematically fixes undefined function errors in automated_reporting_alert_system.ex
  following the 200-change batch protocol with compilation validation.
  """

  @file_path "lib/indrajaal/analytics/automated_reporting_alert_system.ex"

  def main(args \\ []) do
    IO.puts("🔧 SOPv5.11 Automated Reporting Alert System Batch Fixer")
    IO.puts("=" |> String.duplicate(60))

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
      elixir scripts/batch_fixes/automated_reporting_alert_system_batch_fixer.exs --analyze
      elixir scripts/batch_fixes/automated_reporting_alert_system_batch_fixer.exs --count-changes
      elixir scripts/batch_fixes/automated_reporting_alert_system_batch_fixer.exs --batch 1

    Options:
      --analyze       Analyze all error patterns in automated_reporting_alert_system.ex
      --count-changes Count total potential changes needed
      --batch N       Apply batch N fixes (200 changes max)
    """)
  end

  defp analyze_errors do
    IO.puts("🔍 Analyzing undefined function errors in #{@file_path}...")

    if File.exists?(@file_path) do
      content = File.read!(@file_path)

      # Analyze specific undefined function errors from compilation log
      error_patterns = %{
        "schedule_single_report/2 vs /3" => analyze_function_arity_mismatch(content, "schedule_single_report"),
        "setup_automated_reporting/2" => analyze_missing_function(content, "setup_automated_reporting"),
        "enrich_triggered_alert/1 vs /2" => analyze_function_arity_mismatch(content, "enrich_triggered_alert")
      }

      IO.puts("\n📊 UNDEFINED FUNCTION ERROR ANALYSIS:")
      Enum.each(error_patterns, fn {pattern, analysis} ->
        IO.puts("  🔹 #{pattern}: #{analysis}")
      end)

      # Identify specific fix locations
      identify_function_fixes(content)

    else
      IO.puts("❌ File not found: #{@file_path}")
    end
  end

  defp analyze_function_arity_mismatch(content, function_name) do
    lines = String.split(content, "\n")

    # Find function definitions
    definitions = Enum.with_index(lines)
    |> Enum.filter(fn {line, _} ->
      String.contains?(line, "defp #{function_name}(") or String.contains?(line, "def #{function_name}(")
    end)

    # Find function calls
    calls = Enum.with_index(lines)
    |> Enum.filter(fn {line, _} ->
      String.contains?(line, "#{function_name}(") and
      not (String.contains?(line, "defp ") or String.contains?(line, "def "))
    end)

    "#{length(definitions)} definitions, #{length(calls)} calls"
  end

  defp analyze_missing_function(content, function_name) do
    lines = String.split(content, "\n")

    # Find function calls
    calls = Enum.with_index(lines)
    |> Enum.filter(fn {line, _} ->
      String.contains?(line, "#{function_name}(") and
      not (String.contains?(line, "defp ") or String.contains?(line, "def "))
    end)

    "#{length(calls)} calls, function missing"
  end

  defp identify_function_fixes(content) do
    IO.puts("\n🎯 IDENTIFIED FUNCTION FIXES NEEDED:")

    lines = String.split(content, "\n")

    Enum.with_index(lines)
    |> Enum.each(fn {line, index} ->
      cond do
        String.contains?(line, "schedule_single_report(&1, tenant_id)") ->
          IO.puts("  Line #{index + 1}: CALL schedule_single_report/2 should be schedule_single_report/3")

        String.contains?(line, "defp schedule_single_report(report_config, tenant_id, __req)") ->
          IO.puts("  Line #{index + 1}: DEF schedule_single_report/3 - need to add /2 version or fix calls")

        String.contains?(line, "setup_automated_reporting(tenant_id, report_schedules)") ->
          IO.puts("  Line #{index + 1}: CALL setup_automated_reporting/2 - function missing")

        String.contains?(line, "enrich_triggered_alert/1") ->
          IO.puts("  Line #{index + 1}: CALL enrich_triggered_alert/1 should be enrich_triggered_alert/2")

        String.contains?(line, "defp enrich_triggered_alert(alert_evaluation, __req)") ->
          IO.puts("  Line #{index + 1}: DEF enrich_triggered_alert/2 - need to add /1 version or fix calls")

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
        function_arity_adjustments: count_arity_fixes_needed(content),
        missing_function_additions: count_missing_function_fixes(content),
        call_adjustments: count_call_adjustments_needed(content)
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

  defp count_arity_fixes_needed(content) do
    # Count function arity mismatches that need fixing
    arity_fixes = [
      {"schedule_single_report(&1, tenant_id)", "schedule_single_report(&1, tenant_id, %{})"},
      {"enrich_triggered_alert/1", "enrich_triggered_alert/2"}
    ]

    Enum.count(arity_fixes, fn {wrong_call, _correct_call} ->
      String.contains?(content, wrong_call)
    end)
  end

  defp count_missing_function_fixes(content) do
    # Count missing functions that need to be added
    if String.contains?(content, "setup_automated_reporting(tenant_id, report_schedules)") do
      1
    else
      0
    end
  end

  defp count_call_adjustments_needed(content) do
    # Count call sites that need parameter adjustments
    call_patterns = [
      "schedule_single_report(&1, tenant_id)",
      "enrich_triggered_alert/1"
    ]

    call_patterns
    |> Enum.count(fn pattern ->
      String.contains?(content, pattern)
    end)
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
    IO.puts("🎯 Batch 1: Fixing undefined function errors...")

    changes = 0

    # Fix 1: schedule_single_report/2 -> schedule_single_report/3 call
    {content, changes} = fix_pattern(content, changes,
      "|> Enum.map(&schedule_single_report(&1, tenant_id))",
      "|> Enum.map(&schedule_single_report(&1, tenant_id, %{}))")

    # Fix 2: Add missing setup_automated_reporting/2 function
    {content, changes} = add_missing_function(content, changes, "setup_automated_reporting")

    # Fix 3: enrich_triggered_alert/1 -> enrich_triggered_alert/2 call
    {content, changes} = fix_pattern(content, changes,
      "|> Enum.map(&enrich_triggered_alert/1)",
      "|> Enum.map(&enrich_triggered_alert(&1, %{}))")

    {content, changes}
  end

  defp add_missing_function(content, changes, function_name) do
    case function_name do
      "setup_automated_reporting" ->
        # Find a good location to add the function - after other setup functions
        if String.contains?(content, "setup_automated_reporting(tenant_id, report_schedules)") do
          # Add the missing function definition
          missing_function = """

  defp setup_automated_reporting(tenant_id, report_schedules) do
    # Setup automated reporting system
    with {:ok, system} <- initialize_reporting_system(tenant_id),
         {:ok, schedules} <- configure_schedules(system, report_schedules) do
      {:ok, %{system: system, schedules: schedules}}
    else
      error -> error
    end
  end

  defp initialize_reporting_system(tenant_id) do
    {:ok, %{tenant_id: tenant_id, created_at: DateTime.utc_now()}}
  end

  defp configure_schedules(system, schedules) do
    {:ok, Enum.map(schedules, &configure_single_schedule(system, &1))}
  end

  defp configure_single_schedule(system, schedule) do
    Map.merge(schedule, %{system_id: system.tenant_id})
  end"""

          # Insert before the last end of the module
          insertion_point = String.last_index_of(content, "end")
          if insertion_point do
            {before, after} = String.split_at(content, insertion_point)
            new_content = before <> missing_function <> "\n" <> after
            {new_content, changes + 1}
          else
            {content, changes}
          end
        else
          {content, changes}
        end
      _ ->
        {content, changes}
    end
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
    filename = "./data/tmp/automated_reporting_alert_system_batch#{batch_num}_changes_#{timestamp}.log"

    log_content = """
    SOPv5.11 Batch Fix Log
    ====================
    File: #{@file_path}
    Batch: #{batch_num}
    Changes Applied: #{changes_made}
    Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    Undefined Function Fixes Applied:
    - schedule_single_report/2 -> schedule_single_report/3 (arity fix)
    - setup_automated_reporting/2 (added missing function)
    - enrich_triggered_alert/1 -> enrich_triggered_alert/2 (arity fix)

    Next Steps:
    1. Run compilation validation: env ELIXIR_ERL_OPTIONS="+S 16" mix compile --jobs 16 --warnings-as-errors
    2. If successful, commit changes and proceed to warning elimination
    3. If failed, analyze errors and adjust fixes
    """

    File.write!(filename, log_content)
    IO.puts("📝 Change log saved to: #{filename}")
  end
end

# Execute with command line arguments
System.argv() |> AutomatedReportingAlertSystemBatchFixer.main()