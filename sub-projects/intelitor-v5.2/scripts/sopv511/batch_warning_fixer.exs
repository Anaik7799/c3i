#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule BatchWarningFixer do
  @moduledoc """
  Batch Warning Fixer - SOPv5.11 Systematic Approach
  
  Applies systematic fixes to common unused variable patterns
  across multiple files efficiently.
  """

  def main(args) do
    case args do
      ["--execute"] -> execute_batch_fixes()
      ["--scan"] -> scan_warning_patterns()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts """
    Batch Warning Fixer - SOPv5.11 Systematic Approach
    
    Usage:
      --execute    Apply batch fixes to common patterns
      --scan       Scan and identify fixable patterns
    """
  end

  defp execute_batch_fixes do
    IO.puts """
    🚀 SOPv5.11 BATCH WARNING ELIMINATION
    ====================================
    """

    # Get current warning count
    {_output, __} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    initial_warnings = count_warnings(output)
    
    IO.puts "📊 Initial warnings: #{initial_warnings}"
    
    # Apply batch fixes
    results = apply_common_fixes()
    
    # Validate results
    {_new_output, __} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    final_warnings = count_warnings(new_output)
    
    IO.puts """
    
    ✅ BATCH FIXES COMPLETE
    ======================
    📊 Results:
      • Initial warnings: #{initial_warnings}
      • Final warnings: #{final_warnings}
      • Eliminated: #{initial_warnings - final_warnings}
      • Files processed: #{results.files_processed}
      • Fixes applied: #{results.fixes_applied}
    """
  end

  defp scan_warning_patterns do
    IO.puts "🔍 Scanning warning patterns..."
    
    {_output, __} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    
    unused_state_count = count_pattern(output, ~r/variable "_state" is unused/)
    unused_params_count = count_pattern(output, ~r/variable "_params" is unused/)
    
    IO.puts """
    📊 Pattern Analysis:
      • Unused '__state': #{unused_state_count}
      • Unused '__params': #{unused_params_count}
      • Total fixable: #{unused_state_count + unused_params_count}
    """
  end

  defp apply_common_fixes do
    files_with_fixes = [
      # High-impact files with multiple warnings
      "lib/indrajaal/alarms/analytics_dashboard.ex",
      "lib/indrajaal/analytics/executive_dashboard_engine.ex", 
      "lib/indrajaal/analytics/predictive_performance_monitor.ex",
      "lib/indrajaal/analytics/unified_analytics_engine.ex",
      "lib/indrajaal/alarms.ex",
      "lib/indrajaal/compilation/progress_tracker.ex",
      "lib/indrajaal/coordination/advanced_multi_agent_coordinator.ex"
    ]
    
    results = %{files_processed: 0, fixes_applied: 0}
    
    Enum.reduce(files_with_fixes, results, fn file, acc ->
      case apply_fixes_to_file(file) do
        {:ok, fixes_count} ->
          IO.puts "✅ #{file}: #{fixes_count} fixes applied"
          %{acc | files_processed: acc.files_processed + 1, fixes_applied: acc.fixes_applied + fixes_count}
        
        {:error, reason} ->
          IO.puts "❌ #{file}: #{reason}"
          acc
      end
    end)
  end

  defp apply_fixes_to_file(file_path) do
    if File.exists?(file_path) do
      content = File.read!(file_path)
      
      fixes = [
        # Fix unused __state parameters
        {~r/defp ([a-zA-Z_]+)\([^)]*,\s*__state\s*\)/, "defp \\1(\\2_state)"},
        {~r/defp ([a-zA-Z_]+)\(([^,)]+),\s*__state\s*\)/, "defp \\1(\\2, _state)"},
        
        # Fix unused __params parameters
        {~r/defp ([a-zA-Z_]+)\([^)]*,\s*__params\s*\)/, "defp \\1(\\2_params)"},
        {~r/defp ([a-zA-Z_]+)\(([^,)]+),\s*__params\s*\)/, "defp \\1(\\2, _params)"},
        
        # Fix simple unused variables
        {~r/def ([a-zA-Z_]+)\(__params\)/, "def \\1(_params)"},
        {~r/defp ([a-zA-Z_]+)\(__state\)\s+do/, "defp \\1(_state) do"}
      ]
      
      {_new_content, _fix_count} = apply_fixes_to_content(content, fixes)
      
      if fix_count > 0 do
        File.write!(file_path, new_content)
        {:ok, fix_count}
      else
        {:ok, 0}
      end
    else
      {:error, "File not found"}
    end
  rescue
    e -> {:error, inspect(e)}
  end

  defp apply_fixes_to_content(content, fixes) do
    Enum.reduce(fixes, {content, 0}, fn {pattern, replacement}, {current_content, count} ->
      if String.match?(current_content, pattern) do
        new_content = String.replace(current_content, pattern, replacement)
        {new_content, count + 1}
      else
        {current_content, count}
      end
    end)
  end

  defp count_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "warning:"))
  end

  defp count_pattern(output, pattern) do
    output
    |> String.split("\n")
    |> Enum.count(&String.match?(&1, pattern))
  end
end

BatchWarningFixer.main(System.argv())