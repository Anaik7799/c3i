#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule DirectErrorFixer do
  @moduledoc """
  AEE SOPv5.11 Direct Error Fixer

  Applies targeted fixes to specific files with known undefined variable errors.
  """

  def main(args) do
    case args do
      ["--fix-target-files"] -> fix_target_files()
      ["--validate-direct-fixes"] -> validate_direct_fixes()
      _ -> show_help()
    end
  end

  defp fix_target_files do
    IO.puts("🔧 AEE SOPv5.11: Direct Targeted Error Fixes")
    IO.puts("===========================================")

    # Based on the error analysis, target specific files with known issues
    target_files_and_fixes = [
      {
        "lib/indrajaal/access_control/analytics_engine.ex",
        %{
          "__tenant_id" => "tenantid",
          "enriched_event" => "__event",
          "__event_data" => "__data",
          "historical_data" => "__data",
          "factor_scores" => "scores",
          "risk_factors" => "factors"
        }
      },
      {
        "lib/indrajaal/access_control/timescale_integration.ex",
        %{
          "__tenant_id" => "_tenant_id",  # Since it seems unused in functions
          "table" => "_table"  # Since it seems unused
        }
      },
      {
        "lib/indrajaal/access_control_context.ex",
        %{
          "tenantid" => "__tenant_id"  # Standardize parameter names
        }
      },
      {
        "lib/indrajaal/access_control/compliance_reporter.ex",
        %{
          "__data" => "_data"  # Since it seems unused in some functions
        }
      }
    ]

    _total_fixes = 0

    Enum.each(target_files_and_fixes, fn {file_path, fixes} ->
      if File.exists?(file_path) do
        IO.puts("📝 Processing: #{file_path}")

        content = File.read!(file_path)
        fixed_content = apply_targeted_fixes(content, fixes)
        fixes_count = count_lines_changed(content, fixed_content)

        if fixes_count > 0 do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Applied fixes to #{fixes_count} lines")
          total_fixes = total_fixes + fixes_count
        else
          IO.puts("  ℹ️  No changes needed")
        end
      else
        IO.puts("  ❌ File not found: #{file_path}")
      end
    end)

    IO.puts("🎯 Total lines fixed: #{total_fixes}")

    # Save comprehensive report
    report = %{
      timestamp: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC"),
      methodology: "AEE SOPv5.11 Direct Targeted Fixes",
      total_files_processed: length(target_files_and_fixes),
      total_lines_fixed: total_fixes,
      target_files: Enum.map(target_files_and_fixes, fn {file, _} -> file end)
    }

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./__data/tmp/direct_fix_report_#{timestamp}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))
    IO.puts("📋 Report saved: #{report_file}")
  end

  defp apply_targeted_fixes(content, fixes) do
    Enum.reduce(fixes, content, fn {old_var, new_var}, acc ->
      # More conservative pattern matching
      patterns = [
        # 1. Direct variable usage at word boundaries
        {~r/\b#{Regex.escape(old_var)}\b(?![a-zA-Z_0-9])/, new_var},

        # 2. In string interpolation
        {~r/\#\{#{Regex.escape(old_var)}\}/, "\#{#{new_var}}"},

        # 3. After dots (struct/map access)
        {~r/\.#{Regex.escape(old_var)}\b/, ".#{new_var}"}
      ]

      Enum.reduce(patterns, acc, fn {pattern, replacement}, content_acc ->
        String.replace(content_acc, pattern, replacement)
      end)
    end)
  end

  defp validate_direct_fixes do
    IO.puts("✅ AEE SOPv5.11: Direct Fix Validation")
    IO.puts("===================================")

    # Run compilation check
    {_output, _exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true)

    # Count specific error types
    error_lines = output |> String.split("\n") |> Enum.filter(&String.contains?(&1, "error:"))
    warning_lines = output |> String.split("\n") |> Enum.filter(&String.contains?(&1, "warning:"))

    undefined_var_errors = error_lines
                          |> Enum.filter(&String.contains?(&1, "undefined variable"))
                          |> length()

    results = %{
      timestamp: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC"),
      compilation_success: exit_code == 0,
      total_errors: length(error_lines),
      undefined_variable_errors: undefined_var_errors,
      total_warnings: length(warning_lines),
      improvement_status: determine_status(length(error_lines), undefined_var_errors)
    }

    IO.puts("📊 Validation Results:")
    IO.puts("  Compilation Success: #{results.compilation_success}")
    IO.puts("  Total Errors: #{results.total_errors}")
    IO.puts("  Undefined Variable Errors: #{results.undefined_variable_errors}")
    IO.puts("  Total Warnings: #{results.total_warnings}")
    IO.puts("  Status: #{results.improvement_status}")

    # Save validation results
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    validation_file = "./__data/tmp/direct_fix_validation_#{timestamp}.json"
    File.write!(validation_file, Jason.encode!(results, pretty: true))

    # Save detailed compilation output
    output_file = "./__data/tmp/compilation_output_#{timestamp}.txt"
    File.write!(output_file, output)

    IO.puts("📁 Validation saved: #{validation_file}")
    IO.puts("📁 Full output saved: #{output_file}")

    results
  end

  defp determine_status(total_errors, undefined_errors) do
    cond do
      total_errors == 0 -> "🎯 ZERO ERRORS ACHIEVED"
      undefined_errors == 0 -> "🏆 UNDEFINED VARIABLES ELIMINATED"
      total_errors < 50 -> "📈 SIGNIFICANT IMPROVEMENT"
      total_errors < 100 -> "🔧 MODERATE IMPROVEMENT"
      true -> "⚠️ ADDITIONAL FIXES NEEDED"
    end
  end

  defp count_lines_changed(original, fixed) do
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    Enum.zip(original_lines, fixed_lines)
    |> Enum.count(fn {orig, fix} -> orig != fix end)
  end

  defp show_help do
    IO.puts("""
    AEE SOPv5.11 Direct Error Fixer
    ===============================

    Usage: elixir direct_error_fixer.exs [COMMAND]

    Commands:
      --fix-target-files       Apply targeted fixes to specific files with known errors
      --validate-direct-fixes  Validate the results of direct fixes

    Targets files specifically identified in error analysis:
    - lib/indrajaal/access_control/analytics_engine.ex
    - lib/indrajaal/access_control/timescale_integration.ex
    - lib/indrajaal/access_control_context.ex
    - lib/indrajaal/access_control/compliance_reporter.ex
    """)
  end
end

DirectErrorFixer.main(System.argv())