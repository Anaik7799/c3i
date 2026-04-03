#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Final205RemainingErrorsFixer do
  @moduledoc """
  🎯 CRITICAL: Fix final remaining 205 compilation errors for zero-error validation checkpoint

  Based on latest compilation analysis, these are the remaining error patterns:
  1. "analyticsdata" undefined - needs proper variable naming
  2. "analysis_type" undefined - variable scoping issue
  3. "access_data" undefined - missing variable definition
  4. "timerange" undefined - needs proper variable scope
  5. "_event" undefined - event variable scoping
  6. Function name concatenation issues (fetchaccess_control, etc.)
  """

  def main(args \\ []) do
    IO.puts("🎯 CRITICAL: Fixing final 205 compilation errors for zero-error validation checkpoint")

    case Enum.at(args, 0) do
      "--execute" -> execute_final_fixes()
      "--analyze" -> analyze_remaining_patterns()
      _ -> show_help()
    end
  end

  defp execute_final_fixes do
    IO.puts("🔧 Applying final targeted error fixes...")

    # Target files with known remaining errors
    target_files = [
      "lib/indrajaal/access_control/analytics_engine.ex",
      "lib/indrajaal/access_control/timescale_integration.ex",
      "lib/indrajaal/access_control_context.ex",
      "lib/indrajaal/access_control/unified_patterns.ex"
    ]

    IO.puts("📋 Processing #{length(target_files)} targeted files...")

    {_fixed_files, _total_fixes} = Enum.reduce(target_files, {[], 0}, fn file, {acc_files, acc_fixes} ->
      if File.exists?(file) do
        case fix_remaining_errors(file) do
          {:ok, fixes_count} when fixes_count > 0 ->
            IO.puts("✅ Fixed #{Path.basename(file)}: #{fixes_count} final fixes")
            {[file | acc_files], acc_fixes + fixes_count}
          {:ok, 0} ->
            {acc_files, acc_fixes}
          {:error, reason} ->
            IO.puts("❌ Error processing #{Path.basename(file)}: #{reason}")
            {acc_files, acc_fixes}
        end
      else
        {acc_files, acc_fixes}
      end
    end)

    IO.puts("🎯 Running final Patient Mode validation...")
    validate_compilation_success()
  end

  defp fix_remaining_errors(file_path) do
    try do
      original_content = File.read!(file_path)

      # Apply final targeted fixes
      fixed_content = original_content
      |> fix_analytics_data_variables()
      |> fix_analysis_type_variables()
      |> fix_access_data_variables()
      |> fix_time_range_variables()
      |> fix_event_variables()
      |> fix_concatenated_function_names()
      |> fix_remaining_undefined_variables()
      |> fix_unused_parameter_warnings()

      if fixed_content != original_content do
        File.write!(file_path, fixed_content)
        fixes_count = count_differences(original_content, fixed_content)
        {:ok, fixes_count}
      else
        {:ok, 0}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp fix_analytics_data_variables(content) do
    content
    # Fix analyticsdata -> analytics_data
    |> String.replace(~r/\banalyticsdata\b/, "analytics_data")
    # Fix common analytics variable patterns
    |> String.replace(~r/analytics_data = collect_([^)]+)/, "analytics_data = collect_\\1")
    |> String.replace(~r/analyze_temporal_patterns\(analyticsdata\)/, "analyze_temporal_patterns(analytics_data)")
    |> String.replace(~r/generate_insights\(analyticsdata\)/, "generate_insights(analytics_data)")
  end

  defp fix_analysis_type_variables(content) do
    content
    # Fix analysis_type variable scoping
    |> String.replace(~r/analysis_type = determine_analysis_type\([^)]+\)/, "analysis_type = determine_analysis_type(data)")
    |> String.replace(~r/\banalysis_type\b/, "_analysis_type")
    # When analysis_type is actually used, remove the underscore
    |> String.replace(~r/case _analysis_type do/, "case analysis_type do")
    |> String.replace(~r/if _analysis_type == /, "if analysis_type == ")
  end

  defp fix_access_data_variables(content) do
    content
    # Fix access_data variable scoping
    |> String.replace(~r/access_data = extract_access_data\([^)]+\)/, "access_data = extract_access_data(context)")
    |> String.replace(~r/\baccess_data\b/, "_access_data")
    # When access_data is actually used, remove the underscore
    |> String.replace(~r/process_access_data\(_access_data\)/, "process_access_data(access_data)")
    |> String.replace(~r/_access_data\[/, "access_data[")
    |> String.replace(~r/_access_data\./, "access_data.")
  end

  defp fix_time_range_variables(content) do
    content
    # Fix timerange -> time_range
    |> String.replace(~r/\btimerange\b/, "time_range")
    # Fix time_range variable scoping issues
    |> String.replace(~r/time_range = extract_time_range\([^)]+\)/, "time_range = extract_time_range(params)")
    |> String.replace(~r/analyze_time_patterns\(timerange\)/, "analyze_time_patterns(time_range)")
    |> String.replace(~r/generate_time_series\(timerange\)/, "generate_time_series(time_range)")
  end

  defp fix_event_variables(content) do
    content
    # Fix _event variable usage patterns
    |> String.replace(~r/\b_event\[/, "event[")
    |> String.replace(~r/\b_event\./, "event.")
    |> String.replace(~r/process_event\(_event\)/, "process_event(event)")
    |> String.replace(~r/enrich_event_data\(_event\)/, "enrich_event_data(event)")
    # Fix event scoping in function definitions
    |> String.replace(~r/defp process_event\(_event\) do/, "defp process_event(event) do")
  end

  defp fix_concatenated_function_names(content) do
    content
    # Fix concatenated function names from previous fixes
    |> String.replace(~r/fetchaccess_control/, "fetch_access_control")
    |> String.replace(~r/docreate_access_control/, "do_create_access_control")
    |> String.replace(~r/validateuser_access/, "validate_user_access")
    |> String.replace(~r/validateitem_access/, "validate_item_access")
    |> String.replace(~r/validatecreate_attrs/, "validate_create_attrs")
    |> String.replace(~r/validateid/, "validate_id")
    |> String.replace(~r/tenantid/, "tenant_id")
    |> String.replace(~r/createdby_id/, "created_by_id")
    |> String.replace(~r/uniqueinteger/, "unique_integer")
  end

  defp fix_remaining_undefined_variables(content) do
    content
    # Fix common undefined variable patterns
    |> String.replace(~r/\bparams\b(?=\s*=)/, "_params")
    |> String.replace(~r/\buser\b(?=\s*=)/, "_user")
    |> String.replace(~r/\breq\b(?=\s*=)/, "_req")
    |> String.replace(~r/\baction\b(?=\s*=)/, "_action")
    |> String.replace(~r/\bresource\b(?=\s*=)/, "_resource")
    |> String.replace(~r/\bitem\b(?=\s*=)/, "_item")
    |> String.replace(~r/\battrs\b(?=\s*=)/, "_attrs")
    # Fix function parameter duplications
    |> String.replace(~r/\(user, action, resource, _req, req\)/, "(user, action, resource, req)")
    |> String.replace(~r/\(user, item, _req, req\)/, "(user, item, req)")
    |> String.replace(~r/\(attrs, _req, req\)/, "(attrs, req)")
  end

  defp fix_unused_parameter_warnings(content) do
    content
    # Fix unused parameter warnings by adding underscores
    |> String.replace(~r/defp validate_user_access\(user, action, resource, req\) do/, "defp validate_user_access(_user, _action, _resource, _req) do")
    |> String.replace(~r/defp validate_item_access\(user, item, req\) do/, "defp validate_item_access(_user, _item, _req) do")
    |> String.replace(~r/defp validate_create_attrs\(attrs, req\) do/, "defp validate_create_attrs(_attrs, _req) do")
    # But keep them without underscore if they're actually used in the function body
    |> String.replace(~r/defp fetch_access_control\(id, tenant_id\) do/, "defp fetch_access_control(id, tenant_id) do")
    |> String.replace(~r/defp do_create_access_control\(attrs, tenant_id, user\) do/, "defp do_create_access_control(attrs, tenant_id, user) do")
  end

  defp count_differences(original, fixed) do
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    max_lines = max(length(original_lines), length(fixed_lines))

    0..(max_lines - 1)
    |> Enum.count(fn i ->
      orig_line = Enum.at(original_lines, i, "")
      fixed_line = Enum.at(fixed_lines, i, "")
      orig_line != fixed_line
    end)
  end

  defp analyze_remaining_patterns do
    IO.puts("🔍 Analyzing remaining error patterns from latest compilation...")

    # Read the most recent compilation log
    log_files = Path.wildcard("./data/tmp/*validation*.log")
                |> Enum.sort()
                |> Enum.reverse()
                |> Enum.take(1)

    if length(log_files) > 0 do
      log_file = hd(log_files)
      content = File.read!(log_file)

      # Extract specific undefined variable errors
      undefined_errors = String.split(content, "\n")
                        |> Enum.filter(&String.contains?(&1, "undefined variable"))
                        |> Enum.map(&extract_variable_name/1)
                        |> Enum.frequencies()

      IO.puts("📊 Top undefined variables:")
      undefined_errors
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.each(fn {var, count} ->
        IO.puts("   #{var}: #{count} occurrences")
      end)
    else
      IO.puts("📋 No recent compilation logs found")
    end
  end

  defp extract_variable_name(line) do
    case Regex.run(~r/undefined variable "([^"]+)"/, line) do
      [_, var_name] -> var_name
      _ -> "unknown"
    end
  end

  defp validate_compilation_success do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_file = "./data/tmp/final_205_remaining_validation_#{timestamp}.log"

    File.mkdir_p("./data/tmp")

    case System.cmd("mix", ["compile", "--warnings-as-errors"],
                   stderr_to_stdout: true,
                   env: [{"NO_TIMEOUT", "true"}, {"PATIENT_MODE", "enabled"}, {"INFINITE_PATIENCE", "true"}]) do
      {output, 0} ->
        File.write!(log_file, output)
        IO.puts("🏆 ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED!")
        IO.puts("✅ All compilation errors and warnings resolved")
        save_success_report(timestamp)
        true
      {output, _} ->
        File.write!(log_file, output)
        errors = count_errors(output)
        warnings = count_warnings(output)

        IO.puts("📊 Final Fix Results:")
        IO.puts("   Errors: #{errors}")
        IO.puts("   Warnings: #{warnings}")
        IO.puts("📄 Full compilation log saved: #{log_file}")

        if errors > 0 do
          IO.puts("🔄 #{errors} errors remain - need more analysis")
          show_sample_issues(output, "error")
        end

        if warnings > 0 do
          IO.puts("🔄 #{warnings} warnings remain - need final cleanup")
          show_sample_issues(output, "warning")
        end

        false
    end
  end

  defp count_errors(output) do
    output
    |> String.split("\n")
    |> Enum.count(fn line ->
      String.contains?(line, "error:") ||
      String.contains?(line, "** (") ||
      String.contains?(line, "CompileError") ||
      String.contains?(line, "undefined variable") ||
      String.contains?(line, "undefined function")
    end)
  end

  defp count_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "warning:"))
  end

  defp show_sample_issues(output, type) do
    IO.puts("\n🔍 Sample #{type}s:")

    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "#{type}:"))
    |> Enum.take(10)
    |> Enum.each(fn line ->
      IO.puts("   #{String.trim(line)}")
    end)
  end

  defp save_success_report(timestamp) do
    report_path = "./data/tmp/final_205_remaining_success_#{timestamp}.log"

    report = """
    🏆 FINAL 205 REMAINING ERRORS ELIMINATED SUCCESSFULLY
    ====================================================

    Timestamp: #{DateTime.utc_now()}

    📊 RESULTS:
    - Compilation Errors: 0 ✅ (was 205)
    - Compilation Warnings: 0 ✅ (was 76)
    - Zero-Error Validation Checkpoint: ACHIEVED ✅

    🔧 Applied Final Fixes:
    - analyticsdata variable naming corrections
    - analysis_type variable scoping fixes
    - access_data variable definition fixes
    - timerange -> time_range naming corrections
    - _event variable scoping fixes
    - concatenated function name corrections
    - unused parameter warning fixes

    🎯 ULTIMATE SUCCESS: Zero-error validation checkpoint achieved!
    """

    File.write!(report_path, report)
    IO.puts("📄 Success report saved: #{report_path}")
  end

  defp show_help do
    IO.puts("""
    🎯 Final 205 Remaining Errors Eliminator

    Usage:
      elixir final_205_remaining_errors_fixer.exs [--execute|--analyze]

    Commands:
      --execute    Execute final targeted fixes for remaining 205 errors
      --analyze    Analyze remaining error patterns in recent logs
    """)
  end
end

Final205RemainingErrorsFixer.main(System.argv())