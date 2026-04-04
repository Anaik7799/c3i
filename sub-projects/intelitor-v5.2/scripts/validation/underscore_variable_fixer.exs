#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule UnderscoreVariableFixer do
  @moduledoc """
  AEE SOPv5.11 Underscore Variable Warning Elimination Engine

  Systematically fixes two types of underscore variable warnings:
  1. Underscored variables that are used (remove underscore)
  2. Variables that are unused (add underscore)
  """

  def main(args) do
    case args do
      ["--analyze-warnings"] -> analyze_compilation_warnings()
      ["--fix-used-underscored"] -> fix_used_underscored_variables()
      ["--fix-unused-variables"] -> fix_unused_variables()
      ["--comprehensive-fix"] -> comprehensive_warning_fix()
      ["--validate-fixes"] -> validate_applied_fixes()
      _ -> show_help()
    end
  end

  defp analyze_compilation_warnings do
    IO.puts("🔍 AEE SOPv5.11: Underscore Variable Warning Analysis")
    IO.puts("==================================================")

    # Read the latest compilation log
    log_content = case File.read("2-compile.log") do
      {:ok, content} -> content
      {:error, _} ->
        IO.puts("❌ Could not read 2-compile.log")
        System.halt(1)
    end

    # Extract underscore variable warnings
    warnings = String.split(log_content, "\n")
               |> Enum.filter(&String.contains?(&1, "warning:"))
               |> Enum.filter(fn line ->
                 String.contains?(line, "underscored variable") or
                 String.contains?(line, "variable") and String.contains?(line, "is unused")
               end)

    # Categorize warnings
    used_underscored = warnings
                      |> Enum.filter(&String.contains?(&1, "underscored variable") and String.contains?(&1, "is used"))
                      |> length()

    unused_variables = warnings
                      |> Enum.filter(&String.contains?(&1, "is unused"))
                      |> length()

    IO.puts("📊 Warning Analysis Results:")
    IO.puts("  Total underscore warnings: #{length(warnings)}")
    IO.puts("  Used underscored variables: #{used_underscored}")
    IO.puts("  Unused variables: #{unused_variables}")

    # Save analysis
    analysis = %{
      total_warnings: length(warnings),
      used_underscored: used_underscored,
      unused_variables: unused_variables,
      sample_warnings: Enum.take(warnings, 10)
    }

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    File.write!("./__data/tmp/underscore_warning_analysis_#{timestamp}.json",
                Jason.encode!(analysis, pretty: true))

    IO.puts("📁 Analysis saved: ./__data/tmp/underscore_warning_analysis_#{timestamp}.json")
  end

  defp fix_used_underscored_variables do
    IO.puts("🔧 AEE SOPv5.11: Fixing Used Underscored Variables")
    IO.puts("==============================================")

    # Target files from compilation log analysis
    target_files = [
      "lib/indrajaal/access_control/timescale_integration.ex",
      "lib/indrajaal/access_control/compliance_reporter.ex"
    ]

    _total_fixes = 0

    Enum.each(target_files, fn file_path ->
      if File.exists?(file_path) do
        IO.puts("📝 Processing: #{file_path}")

        content = File.read!(file_path)

        # Fix patterns for used underscored variables
        fixes = [
          # Fix _tenant_id being used
          {~r/\b_tenant_id\b/, "__tenant_id"},
          # Fix _data being used
          {~r/\b_data\./, "__data."},
          # Fix other common patterns
          {~r/\b__metadata\b/, "metadata"},
          {~r/\b_opts\b/, "__opts"},
          {~r/\b_context\b/, "__context"}
        ]

        _fixed_content = Enum.reduce(fixes, _content, fn {pattern, replacement}, acc ->
          String.replace(acc, pattern, replacement)
        end)

        if content != fixed_content do
          File.write!(file_path, fixed_content)
          changes = count_changes(content, fixed_content)
          IO.puts("  ✅ Applied #{changes} underscore fixes")
          total_fixes = total_fixes + changes
        else
          IO.puts("  ℹ️  No fixes needed")
        end
      else
        IO.puts("  ❌ File not found: #{file_path}")
      end
    end)

    IO.puts("🎯 Total used underscore fixes applied: #{total_fixes}")
    save_fix_report("used_underscored", total_fixes)
  end

  defp fix_unused_variables do
    IO.puts("🔧 AEE SOPv5.11: Fixing Unused Variables")
    IO.puts("=====================================")

    # Target files with unused variable warnings
    target_files = [
      "lib/indrajaal/access_control_context.ex",
      "lib/indrajaal/access_control/compliance_reporter.ex",
      "lib/indrajaal/access_control/domain_hooks.ex",
      "lib/indrajaal/access_control/analytics_engine.ex"
    ]

    _total_fixes = 0

    Enum.each(target_files, fn file_path ->
      if File.exists?(file_path) do
        IO.puts("📝 Processing: #{file_path}")

        content = File.read!(file_path)

        # Fix patterns for unused variables (add underscore)
        fixes = [
          # Function parameters that are unused
          {~r/\b__user\b(?=,\s*_action,\s*_resource\))/, "_user"},
          {~r/\b__tenant_id\b(?=,\s*_framework\))/, "_tenant_id"},
          {~r/\baccesslog\b(?=,\s*__context)/, "_accesslog"},
          {~r/\b__eventtype\b(?=,\s*\w+,\s*__context)/, "_eventtype"},
          {~r/\baccessgrant\b(?=,\s*__context)/, "_accessgrant"},
          {~r/\b__opts\b(?=\)\s*do)/, "_opts"},
          {~r/\breport_data\b(?=,\s*errors\))/, "_report_data"},
          {~r/\breports\b(?=\)\s*do)/, "_reports"},
          {~r/\b__event__data\b(?=\)\s*do)/, "_event__data"},
          {~r/\braw__data\b(?=,\s*_opts\))/, "_raw__data"},
          {~r/\bprocessed__data\b(?=,\s*__opts\))/, "_processed__data"},
          {~r/\bbaseline__data\b(?=,\s*current_data)/, "_baseline__data"}
        ]

        _fixed_content = Enum.reduce(fixes, _content, fn {pattern, replacement}, acc ->
          String.replace(acc, pattern, replacement)
        end)

        if content != fixed_content do
          File.write!(file_path, fixed_content)
          changes = count_changes(content, fixed_content)
          IO.puts("  ✅ Applied #{changes} unused variable fixes")
          total_fixes = total_fixes + changes
        else
          IO.puts("  ℹ️  No fixes needed")
        end
      else
        IO.puts("  ❌ File not found: #{file_path}")
      end
    end)

    IO.puts("🎯 Total unused variable fixes applied: #{total_fixes}")
    save_fix_report("unused_variables", total_fixes)
  end

  defp comprehensive_warning_fix do
    IO.puts("🚀 AEE SOPv5.11: Comprehensive Underscore Warning Elimination")
    IO.puts("=========================================================")

    analyze_compilation_warnings()
    fix_used_underscored_variables()
    fix_unused_variables()

    IO.puts("✅ Comprehensive warning fix complete")
  end

  defp validate_applied_fixes do
    IO.puts("✅ AEE SOPv5.11: Validation of Applied Fixes")
    IO.puts("=========================================")

    IO.puts("🔄 Running compilation check...")

    {_output, _exit_code} = System.cmd("mix", ["compile"],
                                     stderr_to_stdout: true,
                                     env: [{"ELIXIR_ERL_OPTIONS", "+fnu +S 16"}])

    # Count warnings
    warning_count = output
                   |> String.split("\n")
                   |> Enum.count(&String.contains?(&1, "warning:"))

    underscore_warnings = output
                         |> String.split("\n")
                         |> Enum.count(fn line ->
                           String.contains?(line, "underscored variable") or
                           (String.contains?(line, "variable") and String.contains?(line, "is unused"))
                         end)

    improvement_status = case underscore_warnings do
      0 -> "🎯 ZERO UNDERSCORE WARNINGS ACHIEVED"
      n when n < 20 -> "📈 SIGNIFICANT IMPROVEMENT"
      n when n < 50 -> "🔧 MODERATE IMPROVEMENT"
      _ -> "⚠️ ADDITIONAL FIXES NEEDED"
    end

    IO.puts("📊 Validation Results:")
    IO.puts("  Compilation: #{if exit_code == 0, do: "✅ SUCCESS", else: "❌ FAILED"}")
    IO.puts("  Total warnings: #{warning_count}")
    IO.puts("  Underscore warnings: #{underscore_warnings}")
    IO.puts("  Status: #{improvement_status}")

    # Save validation report
    validation_result = %{
      timestamp: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC"),
      compilation_success: exit_code == 0,
      total_warnings: warning_count,
      underscore_warnings: underscore_warnings,
      improvement_status: improvement_status
    }

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    File.write!("./__data/tmp/underscore_fix_validation_#{timestamp}.json",
                Jason.encode!(validation_result, pretty: true))

    IO.puts("📁 Validation report saved: ./__data/tmp/underscore_fix_validation_#{timestamp}.json")

    validation_result
  end

  defp count_changes(original, fixed) do
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    Enum.zip(original_lines, fixed_lines)
    |> Enum.count(fn {orig, fix} -> orig != fix end)
  end

  defp save_fix_report(fix_type, total_fixes) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")

    report = %{
      timestamp: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC"),
      fix_type: fix_type,
      total_fixes_applied: total_fixes,
      aee_methodology: "SOPv5.11",
      systematic_approach: true
    }

    report_file = "./__data/tmp/underscore_fix_report_#{fix_type}_#{timestamp}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))
    IO.puts("📋 Fix report saved: #{report_file}")
  end

  defp show_help do
    IO.puts("""
    AEE SOPv5.11 Underscore Variable Warning Elimination Engine
    =========================================================

    Usage: elixir underscore_variable_fixer.exs [COMMAND]

    Commands:
      --analyze-warnings        Analyze current underscore variable warnings
      --fix-used-underscored   Remove underscore from variables that are used
      --fix-unused-variables   Add underscore to variables that are unused
      --comprehensive-fix      Run all fixes systematically
      --validate-fixes         Validate applied fixes with compilation check

    This engine addresses the two types of underscore variable warnings:
    1. "underscored variable '_var' is used" → Remove underscore
    2. "variable 'var' is unused" → Add underscore prefix
    """)
  end
end

UnderscoreVariableFixer.main(System.argv())