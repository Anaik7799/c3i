#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511Batch1AnalyticsEngineFixer do
  @moduledoc """
  SOPv5.11 Batch 1: Systematic Analytics Engine Error Fixer

  Fixes undefined variables and unused variable warnings in analytics_engine.ex
  using TPS Jidoka stop-and-fix methodology with 200-change limit.

  Target: lib/indrajaal/access_control/analytics_engine.ex (1,064 issues)
  Patterns: undefined 'access_rule', 'access_grant', 'event_type', 'opts' variables
  """

  @target_file "lib/indrajaal/access_control/analytics_engine.ex"
  @max_changes 200

  def main(args) do
    case args do
      ["--execute"] -> execute_batch_1_fixes()
      ["--analyze"] -> analyze_patterns()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts """
    SOPv5.11 Batch 1 Analytics Engine Fixer

    Usage:
      --execute    Apply systematic fixes with 200-change limit
      --analyze    Analyze patterns before fixing
    """
  end

  defp analyze_patterns do
    IO.puts """
    🔍 SOPv5.11 BATCH 1 PATTERN ANALYSIS
    ====================================
    """

    if File.exists?(@target_file) do
      content = File.read!(@target_file)
      lines = String.split(content, "\n")

      IO.puts "📊 File Analysis:"
      IO.puts "  Total lines: #{length(lines)}"
      IO.puts "  Target file: #{@target_file}"

      # Analyze undefined variable patterns
      undefined_patterns = [
        "access_rule",
        "access_grant",
        "event_type",
        "opts"
      ]

      IO.puts "\n🎯 Undefined Variable Pattern Analysis:"
      Enum.each(undefined_patterns, fn pattern ->
        count = count_pattern_usage(content, pattern)
        IO.puts "  #{pattern}: #{count} occurrences"
      end)

      # Analyze unused variable patterns
      unused_patterns = [
        "tenant_id",
        "user",
        "processeddata",
        "riskfactors",
        "factorscores",
        "historicaldata",
        "enrichedevent",
        "accessrule"
      ]

      IO.puts "\n⚠️ Unused Variable Pattern Analysis:"
      Enum.each(unused_patterns, fn pattern ->
        count = count_pattern_usage(content, pattern)
        IO.puts "  #{pattern}: #{count} occurrences"
      end)

    else
      IO.puts "❌ File not found: #{@target_file}"
    end
  end

  defp execute_batch_1_fixes do
    IO.puts """
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  SOPv5.11 BATCH 1: ANALYTICS ENGINE SYSTEMATIC FIXER               ║
    ║  🎯 TPS Jidoka: Stop-and-Fix with 200-Change Limit                 ║
    ║  🔧 Target: analytics_engine.ex (1,064 issues)                     ║
    ╚═════════════════════════════════════════════════════════════════════╝
    """

    if not File.exists?(@target_file) do
      IO.puts "❌ ERROR: Target file not found: #{@target_file}"
      System.halt(1)
    end

    content = File.read!(@target_file)
    original_content = content
    changes_made = 0

    IO.puts "📸 Original file size: #{String.length(content)} bytes"

    # Fix 1: Undefined variable patterns
    {content, changes} = fix_undefined_variables(content, changes_made)
    changes_made = changes

    # Fix 2: Unused variable patterns (if under limit)
    if changes_made < @max_changes do
      {content, changes} = fix_unused_variables(content, changes_made)
      changes_made = changes
    end

    # Fix 3: Structural issues (if under limit)
    if changes_made < @max_changes do
      {content, changes} = fix_structural_issues(content, changes_made)
      changes_made = changes
    end

    if changes_made > 0 do
      # Create backup
      backup_file = "#{@target_file}.backup-#{DateTime.utc_now() |> DateTime.to_unix()}"
      File.write!(backup_file, original_content)

      # Write fixed content
      File.write!(@target_file, content)

      IO.puts """

      ✅ BATCH 1 FIXES APPLIED
      ========================
      📊 Results:
        • Changes made: #{changes_made}/#{@max_changes}
        • Backup created: #{backup_file}
        • Status: #{ if changes_made >= @max_changes, do: "LIMIT REACHED", else: "COMPLETE" }

      🔄 Next: Run compilation validation
      """
    else
      IO.puts "⚠️ No changes needed in Batch 1"
    end
  end

  defp fix_undefined_variables(content, changes_made) do
    IO.puts "🔧 Phase 1: Fixing undefined variables..."

    fixes = [
      # Fix: opts reference without parameter
      {~r/time_range = \[\]\[:time_range\]/, "time_range = opts[:time_range]"},

      # Fix: Missing access_rule parameter definitions
      {~r/def (analyze_policy_change)\(([^)]*)\) do/, "def \\1(\\2, access_rule) do"},
      {~r/defp (analyze_privilege_escalation)\(([^)]*)\) do/, "defp \\1(\\2, access_rule) do"},

      # Fix: Missing event_type parameter
      {~r/def (assess_event_type_risk)\(\) do/, "def \\1(event_type) do"},
      {~r/def (broadcast_event)\(([^)]*)\) do/, "def \\1(\\2, event_type) do"},

      # Fix: Missing access_grant parameter
      {~r/def (analyze_access_grant)\(\) do/, "def \\1(access_grant) do"},
      {~r/defp (validate_access_grant)\(\) do/, "defp \\1(access_grant) do"}
    ]

    new_content = content
    total_changes = changes_made

    Enum.each(fixes, fn {pattern, replacement} ->
      if total_changes < @max_changes do
        matches = Regex.scan(pattern, new_content) |> length()
        if matches > 0 do
          new_content = Regex.replace(pattern, new_content, replacement)
          total_changes = total_changes + matches
          IO.puts "  ✓ Applied fix: #{matches} replacements (Total: #{total_changes})"
        end
      end
    end)

    {new_content, total_changes}
  end

  defp fix_unused_variables(content, changes_made) do
    IO.puts "🔧 Phase 2: Fixing unused variables..."

    # Add underscore prefix to unused variables
    unused_vars = [
      "tenant_id",
      "user",
      "processeddata",
      "riskfactors",
      "factorscores",
      "historicaldata",
      "enrichedevent",
      "accessrule"
    ]

    new_content = content
    total_changes = changes_made

    Enum.each(unused_vars, fn var ->
      if total_changes < @max_changes do
        # Only add underscore if variable is in parameter position and not already prefixed
        pattern = ~r/def[p]?\s+\w+\([^)]*\b#{var}\b[^)]*\)/
        matches = Regex.scan(pattern, new_content)

        if length(matches) > 0 and total_changes < @max_changes do
          new_content = Regex.replace(~r/\b#{var}\b(?=[\s,\)])/, new_content, "_#{var}")
          total_changes = total_changes + length(matches)
          IO.puts "  ✓ Fixed unused variable: #{var} (#{length(matches)} occurrences)"
        end
      end
    end)

    {new_content, total_changes}
  end

  defp fix_structural_issues(content, changes_made) do
    IO.puts "🔧 Phase 3: Fixing structural issues..."

    fixes = [
      # Fix underscored variable usage
      {~r/factors\.user_behavior/, "factors._user_behavior"},
      {~r/event\._user_context/, "event.user_context"},

      # Fix malformed map access
      {~r/\[\]\[([:\w]+)\]/, "opts[\\1]"}
    ]

    new_content = content
    total_changes = changes_made

    Enum.each(fixes, fn {pattern, replacement} ->
      if total_changes < @max_changes do
        matches = Regex.scan(pattern, new_content) |> length()
        if matches > 0 do
          new_content = Regex.replace(pattern, new_content, replacement)
          total_changes = total_changes + matches
          IO.puts "  ✓ Applied structural fix: #{matches} replacements"
        end
      end
    end)

    {new_content, total_changes}
  end

  defp count_pattern_usage(content, pattern) do
    content
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, pattern))
  end
end

SOPv511Batch1AnalyticsEngineFixer.main(System.argv())