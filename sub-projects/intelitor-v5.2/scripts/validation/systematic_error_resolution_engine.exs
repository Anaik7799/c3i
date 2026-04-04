#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SystematicErrorResolutionEngine do
  @moduledoc """
  AEE SOPv5.11 Systematic Error Resolution Engine

  Applies systematic fixes to undefined variable errors based on
  pattern analysis from the false positive pr__evention system.
  """

  def main(args) do
    case args do
      ["--fix-undefined-variables"] -> fix_undefined_variables()
      ["--fix-function-names"] -> fix_function_names()
      ["--analyze-patterns"] -> analyze_error_patterns()
      ["--validate-fixes"] -> validate_applied_fixes()
      _ -> show_help()
    end
  end

  defp fix_undefined_variables do
    IO.puts("🔧 AEE SOPv5.11: Systematic Undefined Variable Resolution")
    IO.puts("=======================================================")

    # Top undefined variables identified from Patient Mode analysis
    variable_fixes = %{
      "__tenant_id" => "tenantid",      # Most common (63 instances)
      "session_id" => "sessionid",   # Second most common (40 instances)
      "claude_data" => "_claude_data", # Should be prefixed if unused (7 instances)
      "workflow_type" => "workflowtype", # Parameter naming fix
      "workflow_config" => "workflowconfig",
      "__user_engagement" => "__userengagement",
      "message_params" => "message__params",
      "integration_params" => "integration__params",
      "analytics_data" => "analytics__data",
      "workflow_id" => "workflowid"
    }

    files_to_fix = [
      "lib/indrajaal/communication/message_delivery_analytics.ex",
      "lib/indrajaal/analytics/real_time_bi_collector.ex",
      "lib/indrajaal/analytics/predictive_performance_monitor.ex",
      "lib/indrajaal/analytics/analytics_dashboard_engine.ex"
    ]

    _total_fixes = 0

    Enum.each(files_to_fix, fn file_path ->
      if File.exists?(file_path) do
        IO.puts("📝 Processing: #{file_path}")

        content = File.read!(file_path)
        fixed_content = apply_variable_fixes(content, variable_fixes)
        fixes_count = count_fixes_applied(content, fixed_content)

        if fixes_count > 0 do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Applied #{fixes_count} variable fixes")
          _total_fixes = total_fixes + fixes_count
        else
          IO.puts("  ℹ️  No fixes needed")
        end
      else
        IO.puts("  ❌ File not found: #{file_path}")
      end
    end)

    IO.puts("🎯 Total undefined variable fixes applied: #{total_fixes}")
    save_fix_report("undefined_variables", total_fixes, variable_fixes)
  end

  defp apply_variable_fixes(content, variable_fixes) do
    Enum.reduce(variable_fixes, content, fn {undefined_var, correct_var}, acc ->
      # Fix cases where undefined variable is used but the parameter has a different name
      patterns = [
        # Pattern 1: Direct variable usage (most common)
        {~r/\b#{Regex.escape(undefined_var)}\b(?![a-zA-Z_])/, correct_var},

        # Pattern 2: String interpolation
        {~r/\#\{#{Regex.escape(undefined_var)}\}/, "\#{#{correct_var}}"},

        # Pattern 3: In function calls
        {~r/(\w+\(.*?)#{Regex.escape(undefined_var)}(.*?\))/, "\\1#{correct_var}\\2"},

        # Pattern 4: Variable assignment reference
        {~r/= #{Regex.escape(undefined_var)}(\s|$|\n)/, "= #{correct_var}\\1"}
      ]

      Enum.reduce(patterns, acc, fn {pattern, replacement}, content_acc ->
        String.replace(content_acc, pattern, replacement)
      end)
    end)
  end

  defp fix_function_names do
    IO.puts("🔧 AEE SOPv5.11: Function Name Consistency Resolution")
    IO.puts("==================================================")

    # Function name inconsistencies identified
    function_fixes = %{
      "handlecall" => "handle_call",
      "handlecast" => "handle_cast",
      "handleinfo" => "handle_info"
    }

    # Files with function name issues
    files_with_function_issues = [
      "lib/indrajaal/analytics/real_time_bi_collector.ex",
      "lib/indrajaal/analytics/predictive_performance_monitor.ex",
      "lib/indrajaal/analytics/analytics_dashboard_engine.ex"
    ]

    _total_fixes = 0

    Enum.each(files_with_function_issues, fn file_path ->
      if File.exists?(file_path) do
        IO.puts("📝 Processing: #{file_path}")

        content = File.read!(file_path)
        fixed_content = apply_function_name_fixes(content, function_fixes)
        fixes_count = count_fixes_applied(content, fixed_content)

        if fixes_count > 0 do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Applied #{fixes_count} function name fixes")
          _total_fixes = total_fixes + fixes_count
        else
          IO.puts("  ℹ️  No fixes needed")
        end
      end
    end)

    IO.puts("🎯 Total function name fixes applied: #{total_fixes}")
    save_fix_report("function_names", total_fixes, function_fixes)
  end

  defp apply_function_name_fixes(content, function_fixes) do
    Enum.reduce(function_fixes, content, fn {incorrect_name, correct_name}, acc ->
      # Pattern: def function_name(...) or defp function_name(...)
      pattern = ~r/\b(def|defp)\s+#{Regex.escape(incorrect_name)}\b/
      replacement = "\\1 #{correct_name}"
      String.replace(acc, pattern, replacement)
    end)
  end

  defp analyze_error_patterns do
    IO.puts("📊 AEE SOPv5.11: Error Pattern Analysis")
    IO.puts("=====================================")

    # Load the latest validation failure log
    log_files = Path.wildcard("./__data/tmp/zero_error_validation_failure_*.log")
                |> Enum.sort()
                |> Enum.reverse()

    case log_files do
      [latest_log | _] ->
        IO.puts("📄 Analyzing: #{latest_log}")
        analyze_log_patterns(latest_log)
      [] ->
        IO.puts("❌ No validation failure logs found")
    end
  end

  defp analyze_log_patterns(log_file) do
    content = File.read!(log_file)

    # Extract error patterns
    error_lines = String.split(content, "\n")
                  |> Enum.filter(&String.contains?(&1, "error:"))

    # Categorize errors
    undefined_vars = error_lines
                     |> Enum.filter(&String.contains?(&1, "undefined variable"))
                     |> Enum.map(&extract_variable_name/1)
                     |> Enum.f__requencies()

    function_errors = error_lines
                      |> Enum.filter(&String.contains?(&1, "undefined function"))
                      |> length()

    syntax_errors = error_lines
                    |> Enum.filter(&String.contains?(&1, "syntax error"))
                    |> length()

    # Generate analysis report
    analysis = %{
      total_errors: length(error_lines),
      undefined_variables: undefined_vars,
      function_errors: function_errors,
      syntax_errors: syntax_errors,
      top_variables: undefined_vars |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(10)
    }

    IO.puts("📈 Error Analysis Results:")
    IO.puts("  Total errors: #{analysis.total_errors}")
    IO.puts("  Undefined variables: #{map_size(analysis.undefined_variables)}")
    IO.puts("  Function errors: #{analysis.function_errors}")
    IO.puts("  Syntax errors: #{analysis.syntax_errors}")

    IO.puts("\n🔝 Top undefined variables:")
    Enum.each(analysis.top_variables, fn {var, count} ->
      IO.puts("  #{var}: #{count} occurrences")
    end)

    # Save analysis with proper JSON structure
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    analysis_file = "./__data/tmp/error_pattern_analysis_#{timestamp}.json"

    # Convert to JSON-serializable format
    json_analysis = %{
      total_errors: analysis.total_errors,
      undefined_variables: Map.new(analysis.undefined_variables),
      function_errors: analysis.function_errors,
      syntax_errors: analysis.syntax_errors,
      top_variables: Enum.map(analysis.top_variables, fn {var, count} -> %{variable: var, count: count} end)
    }

    File.write!(analysis_file, Jason.encode!(json_analysis, pretty: true))
    IO.puts("\n📁 Analysis saved: #{analysis_file}")

    analysis
  end

  defp extract_variable_name(error_line) do
    case Regex.run(~r/undefined variable "([^"]+)"/, error_line) do
      [_, var_name] -> var_name
      _ -> "unknown"
    end
  end

  defp validate_applied_fixes do
    IO.puts("✅ AEE SOPv5.11: Validation of Applied Fixes")
    IO.puts("==========================================")

    # Run quick compilation check
    IO.puts("🔄 Running compilation check...")

    {_output, _exit_code} = System.cmd("mix", ["compile", "--force"],
                                     stderr_to_stdout: true,
                                     env: [{"ELIXIR_ERL_OPTIONS", "+fnu +S 16"}])

    error_count = output
                  |> String.split("\n")
                  |> Enum.count(&String.contains?(&1, "error:"))

    warning_count = output
                    |> String.split("\n")
                    |> Enum.count(&String.contains?(&1, "warning:"))

    # Generate validation report
    validation_result = %{
      timestamp: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC"),
      compilation_success: exit_code == 0,
      error_count: error_count,
      warning_count: warning_count,
      improvement_status: determine_improvement_status(error_count)
    }

    IO.puts("📊 Validation Results:")
    IO.puts("  Compilation: #{if validation_result.compilation_success, do: "✅ SUCCESS", else: "❌ FAILED"}")
    IO.puts("  Errors: #{error_count}")
    IO.puts("  Warnings: #{warning_count}")
    IO.puts("  Status: #{validation_result.improvement_status}")

    # Save validation report
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    validation_file = "./__data/tmp/fix_validation_report_#{timestamp}.json"
    File.write!(validation_file, Jason.encode!(validation_result, pretty: true))
    IO.puts("📁 Validation report saved: #{validation_file}")

    validation_result
  end

  defp determine_improvement_status(error_count) do
    cond do
      error_count == 0 -> "🎯 ZERO ERRORS ACHIEVED"
      error_count < 50 -> "📈 SIGNIFICANT IMPROVEMENT"
      error_count < 100 -> "🔧 MODERATE IMPROVEMENT"
      true -> "⚠️ ADDITIONAL FIXES NEEDED"
    end
  end

  defp count_fixes_applied(original, fixed) do
    # Simple metric: count lines that changed
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    Enum.zip(original_lines, fixed_lines)
    |> Enum.count(fn {orig, fix} -> orig != fix end)
  end

  defp save_fix_report(fix_type, total_fixes, patterns) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")

    report = %{
      timestamp: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC"),
      fix_type: fix_type,
      total_fixes_applied: total_fixes,
      patterns_used: patterns,
      aee_methodology: "SOPv5.11",
      systematic_approach: true
    }

    report_file = "./__data/tmp/systematic_fix_report_#{fix_type}_#{timestamp}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))
    IO.puts("📋 Fix report saved: #{report_file}")
  end

  defp show_help do
    IO.puts("""
    AEE SOPv5.11 Systematic Error Resolution Engine
    ==============================================

    Usage: elixir systematic_error_resolution_engine.exs [COMMAND]

    Commands:
      --fix-undefined-variables    Fix undefined variable errors systematically
      --fix-function-names         Resolve function name inconsistencies
      --analyze-patterns           Analyze error patterns from validation logs
      --validate-fixes             Validate applied fixes with compilation check

    Based on false positive pr__evention analysis identifying:
    - 63 instances of undefined '__tenant_id' variable
    - 40 instances of undefined 'session_id' variable
    - Function name inconsistencies (handlecall vs handle_call)
    """)
  end
end

SystematicErrorResolutionEngine.main(System.argv())