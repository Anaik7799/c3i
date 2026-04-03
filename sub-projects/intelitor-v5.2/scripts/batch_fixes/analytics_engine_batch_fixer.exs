#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule AnalyticsEngineBatchFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Framework: Analytics Engine Batch Fixer

  Systematically fixes undefined variable errors in analytics_engine.ex
  following the 200-change batch protocol with compilation validation.
  """

  @file_path "lib/indrajaal/access_control/analytics_engine.ex"

  def main(args \\ []) do
    IO.puts("🔧 SOPv5.11 Analytics Engine Batch Fixer")
    IO.puts("=" |> String.duplicate(50))

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
      elixir scripts/batch_fixes/analytics_engine_batch_fixer.exs --analyze
      elixir scripts/batch_fixes/analytics_engine_batch_fixer.exs --count-changes
      elixir scripts/batch_fixes/analytics_engine_batch_fixer.exs --batch 1

    Options:
      --analyze       Analyze all error patterns in analytics_engine.ex
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
        "access_rule" => count_pattern_usage(content, "access_rule"),
        "access_grant" => count_pattern_usage(content, "access_grant"),
        "access_log" => count_pattern_usage(content, "access_log"),
        "scores" => count_pattern_usage(content, "scores"),
        "_context" => count_pattern_usage(content, "_context"),
        "opts" => count_opts_issues(content),
        "__opts" => count_pattern_usage(content, "__opts"),
        "_opts" => count_pattern_usage(content, "_opts"),
        "__tenant_id" => count_pattern_usage(content, "__tenant_id"),
        "tenant_id" => count_tenant_id_issues(content)
      }

      IO.puts("\n📊 ERROR PATTERN ANALYSIS:")
      Enum.each(error_patterns, fn {pattern, count} ->
        IO.puts("  🔹 #{pattern}: #{count} potential issues")
      end)

      # Identify specific fix patterns
      identify_fix_patterns(content)

    else
      IO.puts("❌ File not found: #{@file_path}")
    end
  end

  defp count_pattern_usage(content, pattern) do
    content
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.count(fn {line, _index} ->
      # Count lines that use the pattern but don't define it as a parameter
      String.contains?(line, pattern) and
      not String.contains?(line, "#{pattern}:") and
      not String.contains?(line, "def ") and
      not String.contains?(line, "defp ")
    end)
  end

  defp count_opts_issues(content) do
    # Look for [][:key] patterns and missing opts usage
    content
    |> String.split("\n")
    |> Enum.count(fn line ->
      String.contains?(line, "[][:") or
      (String.contains?(line, "opts") and String.contains?(line, "] ="))
    end)
  end

  defp count_tenant_id_issues(content) do
    # Look for parameter mismatches
    content
    |> String.split("\n")
    |> Enum.count(fn line ->
      (String.contains?(line, "__tenant_id") or String.contains?(line, "_tenant_id")) and
      not String.contains?(line, "def")
    end)
  end

  defp identify_fix_patterns(content) do
    IO.puts("\n🎯 IDENTIFIED FIX PATTERNS:")

    lines = String.split(content, "\n")

    # Look for specific issues
    Enum.with_index(lines)
    |> Enum.take(20)  # First 20 issues for analysis
    |> Enum.each(fn {line, index} ->
      cond do
        String.contains?(line, "[][:") ->
          IO.puts("  Line #{index + 1}: Fix [][:key] to opts[:key] - #{String.trim(line)}")

        String.contains?(line, "processeddata") ->
          IO.puts("  Line #{index + 1}: Fix processeddata to processed_data - #{String.trim(line)}")

        String.contains?(line, "accessrule") and not String.contains?(line, "access_rule") ->
          IO.puts("  Line #{index + 1}: Fix accessrule to access_rule - #{String.trim(line)}")

        String.contains?(line, "_analysis_type:") ->
          IO.puts("  Line #{index + 1}: Fix _analysis_type to analysis_type - #{String.trim(line)}")

        true -> nil
      end
    end)
  end

  defp count_potential_changes do
    IO.puts("📊 Counting total potential changes needed...")

    if File.exists?(@file_path) do
      content = File.read!(@file_path)

      changes = %{
        opts_fixes: count_opts_fixes_needed(content),
        variable_name_fixes: count_variable_name_fixes(content),
        parameter_fixes: count_parameter_fixes(content),
        typo_fixes: count_typo_fixes(content)
      }

      total_changes = Enum.sum(Map.values(changes))

      IO.puts("\n📋 CHANGE COUNT ANALYSIS:")
      Enum.each(changes, fn {category, count} ->
        IO.puts("  🔹 #{category}: #{count} changes")
      end)

      IO.puts("\n🎯 TOTAL ESTIMATED CHANGES: #{total_changes}")
      IO.puts("📦 BATCHES NEEDED: #{ceil(total_changes / 200)}")

    else
      IO.puts("❌ File not found: #{@file_path}")
    end
  end

  defp count_opts_fixes_needed(content) do
    content
    |> String.split("\n")
    |> Enum.count(fn line ->
      String.contains?(line, "[][:") or String.contains?(line, "_opts:")
    end)
  end

  defp count_variable_name_fixes(content) do
    patterns = ["processeddata", "accessrule", "analysisresult", "analysisresults", "detectiontype"]

    content
    |> String.split("\n")
    |> Enum.count(fn line ->
      Enum.any?(patterns, fn pattern -> String.contains?(line, pattern) end)
    end)
  end

  defp count_parameter_fixes(content) do
    content
    |> String.split("\n")
    |> Enum.count(fn line ->
      String.contains?(line, "_analysis_type:") or
      String.contains?(line, "_opts:") or
      String.contains?(line, "__opts") or
      String.contains?(line, "__tenant_id")
    end)
  end

  defp count_typo_fixes(content) do
    typos = ["invalidanalysis_type", "analysisresult", "detectiontype"]

    content
    |> String.split("\n")
    |> Enum.count(fn line ->
      Enum.any?(typos, fn typo -> String.contains?(line, typo) end)
    end)
  end

  defp fix_batch(batch_num) do
    IO.puts("🔧 Applying Batch #{batch_num} fixes to #{@file_path}...")

    if File.exists?(@file_path) do
      content = File.read!(@file_path)

      {fixed_content, changes_made} =
        case batch_num do
          1 -> apply_batch_1_fixes(content)
          2 -> apply_batch_2_fixes(content)
          3 -> apply_batch_3_fixes(content)
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
    IO.puts("🎯 Batch 1: Fixing opts usage and basic variable patterns...")

    changes = 0

    # Fix 1: [][:key] -> opts[:key]
    {content, changes} = fix_pattern(content, changes, "[][:analysis_type]", "opts[:analysis_type]")
    {content, changes} = fix_pattern(content, changes, "[][:detection_type]", "opts[:detection_type]")
    {content, changes} = fix_pattern(content, changes, "[][:algorithms]", "opts[:algorithms]")
    {content, changes} = fix_pattern(content, changes, "[][:_analysis_type]", "opts[:analysis_type]")

    # Fix 2: _opts: -> opts: (in struct/map definitions)
    {content, changes} = fix_pattern(content, changes, "_opts: opts", "opts: opts")

    # Fix 3: processeddata -> processed_data
    {content, changes} = fix_pattern(content, changes, "processeddata", "processed_data")

    # Fix 4: accessrule -> access_rule (when not already correct)
    {content, changes} = fix_pattern(content, changes, " accessrule", " access_rule")
    {content, changes} = fix_pattern(content, changes, "(accessrule", "(access_rule")
    {content, changes} = fix_pattern(content, changes, ",accessrule", ",access_rule")

    # Fix 5: analysisresult -> analysis_result
    {content, changes} = fix_pattern(content, changes, "analysisresult", "analysis_result")
    {content, changes} = fix_pattern(content, changes, "analysisresults", "analysis_results")

    # Fix 6: detectiontype -> detection_type
    {content, changes} = fix_pattern(content, changes, "detectiontype", "detection_type")

    # Fix 7: _analysis_type: -> analysis_type:
    {content, changes} = fix_pattern(content, changes, "_analysis_type:", "analysis_type:")

    # Fix 8: invalidanalysis_type -> invalid_analysis_type
    {content, changes} = fix_pattern(content, changes, "invalidanalysis_type", "invalid_analysis_type")

    {content, changes}
  end

  defp apply_batch_2_fixes(content) do
    IO.puts("🎯 Batch 2: Fixing parameter mismatches and variable references...")

    changes = 0

    # More specific variable fixes based on actual errors
    # These will be determined after seeing actual compilation results

    {content, changes}
  end

  defp apply_batch_3_fixes(content) do
    IO.puts("🎯 Batch 3: Final cleanup and remaining issues...")

    changes = 0

    # Final cleanup based on remaining compilation errors

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
    filename = "./data/tmp/analytics_engine_batch#{batch_num}_changes_#{timestamp}.log"

    log_content = """
    SOPv5.11 Batch Fix Log
    ====================
    File: #{@file_path}
    Batch: #{batch_num}
    Changes Applied: #{changes_made}
    Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    Next Steps:
    1. Run compilation validation: env ELIXIR_ERL_OPTIONS="+S 16" mix compile --jobs 16 --warnings-as-errors
    2. If successful, commit changes and proceed to next batch
    3. If failed, analyze errors and adjust fixes
    """

    File.write!(filename, log_content)
    IO.puts("📝 Change log saved to: #{filename}")
  end
end

# Execute with command line arguments
System.argv() |> AnalyticsEngineBatchFixer.main()