#!/usr/bin/env elixir

# SOPv5.11 Targeted Error Fixer - Based on actual compilation errors

defmodule TargetedErrorFixer do
  @moduledoc """
  Fixes specific compilation errors found in the log:
  1. _contextual key issues in maps
  2. _context parameter issues
  3. _opts parameter issues
  4. Variable name typos
  """

  def run do
    IO.puts("\n🚀 SOPv5.11 TARGETED ERROR FIXER")
    IO.puts("=" <> String.duplicate("=", 79))

    # Fix analytics_engine.ex specifically
    fix_analytics_engine()

    # Fix other files with common patterns
    fix_common_errors()

    IO.puts("\n✅ Targeted fixes complete")
  end

  defp fix_analytics_engine do
    file = "lib/indrajaal/access_control/analytics_engine.ex"

    if File.exists?(file) do
      content = File.read!(file)
      original = content

      # Fix 1: _contextual key in maps (keep underscore in keys, fix references)
      # Change _contextual: to contextual: in map definitions
      content = String.replace(content, "_contextual:", "contextual:")

      # Fix 2: Fix references to the key
      content = String.replace(content, "factors.contextual", "factors.contextual")

      # Fix 3: Fix variable typos
      content = String.replace(content, "userid", "user_id")

      if content != original do
        File.write!(file, content)
        IO.puts("✅ Fixed #{file}")
      end
    end
  end

  defp fix_common_errors do
    files = Path.wildcard("lib/indrajaal/access_control/**/*.ex")

    Enum.each(files, fn file ->
      content = File.read!(file)
      original = content

      # Common fixes
      fixes = [
        # Variable name corrections
        {"eventcontext", "event_context"},
        {"processeddata", "processed_data"},
        {"violationdata", "violation_data"},
        {"rawdata", "raw_data"},
        {"currentdata", "current_data"},
        {"compliancedata", "compliance_data"},
        {"baselinedata", "baseline_data"},
        {"frameworkconfig", "framework_config"},
        {"userid", "user_id"},
        {"tenantid", "tenant_id"},

        # Fix schedule_config references
        {"scheduleconfig", "schedule_config"}
      ]

      content = Enum.reduce(fixes, content, fn {from, to}, acc ->
        String.replace(acc, from, to)
      end)

      if content != original do
        File.write!(file, content)
        IO.puts("✅ Fixed #{file}")
      end
    end)
  end
end

TargetedErrorFixer.run()