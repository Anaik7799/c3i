#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveCompilationErrorAnalyzer do
  @moduledoc """
  SOPv5.11 Cybernetic Framework: Comprehensive Compilation Error Analysis

  This script analyzes the complete 1-compile.log file to classify all 1,935 errors
  and 3,601 warnings systematically without using head/tail commands as required
  by the SOPv5.11 protocol.
  """

  def main(args \\ []) do
    IO.puts("🧠 SOPv5.11 Comprehensive Compilation Error Analysis")
    IO.puts("=" |> String.duplicate(60))

    case args do
      ["--comprehensive"] -> analyze_complete_log()
      ["--classify-errors"] -> classify_all_errors()
      ["--file-impact"] -> analyze_file_impact()
      ["--criticality"] -> analyze_criticality()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts("""
    Usage:
      elixir scripts/analysis/comprehensive_compilation_error_analyzer.exs --comprehensive
      elixir scripts/analysis/comprehensive_compilation_error_analyzer.exs --classify-errors
      elixir scripts/analysis/comprehensive_compilation_error_analyzer.exs --file-impact
      elixir scripts/analysis/comprehensive_compilation_error_analyzer.exs --criticality

    Options:
      --comprehensive   Complete analysis of all 38,986 lines in 1-compile.log
      --classify-errors Classify all 1,935 errors by type and pattern
      --file-impact     Analyze which files have the most critical errors
      --criticality     Perform criticality analysis for unused functions
    """)
  end

  defp analyze_complete_log do
    IO.puts("📊 Analyzing complete 1-compile.log (38,986 lines)...")

    if File.exists?("1-compile.log") do
      content = File.read!("1-compile.log")
      lines = String.split(content, "\n")

      IO.puts("✅ Total lines: #{length(lines)}")

      # Extract all errors
      errors = extract_all_errors(lines)
      warnings = extract_all_warnings(lines)

      IO.puts("📋 COMPLETE ERROR ANALYSIS:")
      IO.puts("  🔴 Total Errors: #{length(errors)}")
      IO.puts("  🟡 Total Warnings: #{length(warnings)}")

      # Analyze error patterns
      analyze_error_patterns(errors)

      # Analyze file impact
      analyze_files_with_most_errors(errors)

      # Save comprehensive report
      save_comprehensive_report(errors, warnings)

    else
      IO.puts("❌ 1-compile.log not found")
    end
  end

  defp extract_all_errors(lines) do
    IO.puts("🔍 Extracting all errors from complete log...")

    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} ->
      String.contains?(line, "error:") and not String.contains?(line, "warning:")
    end)
    |> Enum.map(fn {line, index} ->
      # Extract error details
      %{
        line_number: index + 1,
        content: line,
        type: extract_error_type(line),
        file: extract_file_path(line),
        variable_or_function: extract_undefined_item(line)
      }
    end)
  end

  defp extract_all_warnings(lines) do
    IO.puts("🔍 Extracting all warnings from complete log...")

    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} -> String.contains?(line, "warning:") end)
    |> Enum.map(fn {line, index} ->
      %{
        line_number: index + 1,
        content: line,
        type: extract_warning_type(line),
        file: extract_file_path(line)
      }
    end)
  end

  defp extract_error_type(line) do
    cond do
      String.contains?(line, "undefined variable") -> :undefined_variable
      String.contains?(line, "undefined function") -> :undefined_function
      String.contains?(line, "CompileError") -> :compile_error
      String.contains?(line, "syntax error") -> :syntax_error
      String.contains?(line, "** (") -> :exception_error
      true -> :other_error
    end
  end

  defp extract_warning_type(line) do
    cond do
      String.contains?(line, "is unused") -> :unused_variable
      String.contains?(line, "deprecated") -> :deprecated
      String.contains?(line, "unreachable") -> :unreachable_code
      true -> :other_warning
    end
  end

  defp extract_file_path(line) do
    case Regex.run(~r/(lib\/[^:]+\.ex)/, line) do
      [_, file_path] -> file_path
      _ -> "unknown"
    end
  end

  defp extract_undefined_item(line) do
    case Regex.run(~r/undefined (?:variable|function) "([^"]+)"/, line) do
      [_, item] -> item
      _ -> nil
    end
  end

  defp analyze_error_patterns(errors) do
    IO.puts("\n📈 ERROR PATTERN ANALYSIS:")

    # Group by error type
    by_type = Enum.group_by(errors, & &1.type)

    Enum.each(by_type, fn {type, type_errors} ->
      IO.puts("  🔹 #{type}: #{length(type_errors)} errors")

      if type in [:undefined_variable, :undefined_function] do
        # Show most common undefined items
        type_errors
        |> Enum.map(& &1.variable_or_function)
        |> Enum.filter(& &1 != nil)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_item, count} -> -count end)
        |> Enum.take(10)
        |> Enum.each(fn {item, count} ->
          IO.puts("    - \"#{item}\": #{count} times")
        end)
      end
    end)
  end

  defp analyze_files_with_most_errors(errors) do
    IO.puts("\n📂 FILES WITH MOST ERRORS:")

    errors
    |> Enum.group_by(& &1.file)
    |> Enum.map(fn {file, file_errors} -> {file, length(file_errors)} end)
    |> Enum.sort_by(fn {_file, count} -> -count end)
    |> Enum.take(20)
    |> Enum.each(fn {file, count} ->
      IO.puts("  📄 #{file}: #{count} errors")
    end)
  end

  defp classify_all_errors do
    IO.puts("🏷️ Classifying all errors for batch processing...")

    if File.exists?("1-compile.log") do
      content = File.read!("1-compile.log")
      lines = String.split(content, "\n")
      errors = extract_all_errors(lines)

      # Create classifications for batch processing
      classifications = %{
        high_priority: filter_high_priority_errors(errors),
        medium_priority: filter_medium_priority_errors(errors),
        low_priority: filter_low_priority_errors(errors)
      }

      IO.puts("\n🎯 ERROR CLASSIFICATIONS FOR BATCH PROCESSING:")
      IO.puts("  🔴 High Priority: #{length(classifications.high_priority)} errors")
      IO.puts("  🟡 Medium Priority: #{length(classifications.medium_priority)} errors")
      IO.puts("  🟢 Low Priority: #{length(classifications.low_priority)} errors")

      # Save classification for batch processing
      save_error_classifications(classifications)

    else
      IO.puts("❌ 1-compile.log not found")
    end
  end

  defp filter_high_priority_errors(errors) do
    # High priority: undefined variables in critical files
    errors
    |> Enum.filter(fn error ->
      error.type == :undefined_variable and
      String.contains?(error.file, "access_control") and
      error.variable_or_function in ["_context", "opts", "__opts", "__tenant_id", "access_rule", "access_grant"]
    end)
  end

  defp filter_medium_priority_errors(errors) do
    # Medium priority: undefined functions and other undefined variables
    errors
    |> Enum.filter(fn error ->
      error.type in [:undefined_function, :undefined_variable] and
      not (error.type == :undefined_variable and
           String.contains?(error.file, "access_control") and
           error.variable_or_function in ["_context", "opts", "__opts", "__tenant_id", "access_rule", "access_grant"])
    end)
  end

  defp filter_low_priority_errors(errors) do
    # Low priority: syntax errors, compile errors, etc.
    errors
    |> Enum.filter(fn error ->
      error.type in [:syntax_error, :compile_error, :exception_error, :other_error]
    end)
  end

  defp save_comprehensive_report(errors, warnings) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./data/tmp/comprehensive_compilation_analysis_#{timestamp}.json"

    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      total_lines_analyzed: 38986,
      total_errors: length(errors),
      total_warnings: length(warnings),
      error_breakdown: analyze_error_breakdown(errors),
      warning_breakdown: analyze_warning_breakdown(warnings),
      file_impact: analyze_file_impact_data(errors),
      priority_classification: classify_errors_by_priority(errors)
    }

    File.write!(filename, Jason.encode!(report, pretty: true))
    IO.puts("💾 Comprehensive report saved to: #{filename}")
  end

  defp save_error_classifications(classifications) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./data/tmp/error_classifications_#{timestamp}.json"

    File.write!(filename, Jason.encode!(classifications, pretty: true))
    IO.puts("💾 Error classifications saved to: #{filename}")
  end

  defp analyze_error_breakdown(errors) do
    errors
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, type_errors} -> {type, length(type_errors)} end)
    |> Enum.into(%{})
  end

  defp analyze_warning_breakdown(warnings) do
    warnings
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, type_warnings} -> {type, length(type_warnings)} end)
    |> Enum.into(%{})
  end

  defp analyze_file_impact_data(errors) do
    errors
    |> Enum.group_by(& &1.file)
    |> Enum.map(fn {file, file_errors} -> {file, length(file_errors)} end)
    |> Enum.sort_by(fn {_file, count} -> -count end)
    |> Enum.take(30)
    |> Enum.into(%{})
  end

  defp classify_errors_by_priority(errors) do
    %{
      high_priority: length(filter_high_priority_errors(errors)),
      medium_priority: length(filter_medium_priority_errors(errors)),
      low_priority: length(filter_low_priority_errors(errors))
    }
  end

  defp analyze_file_impact do
    IO.puts("📂 Analyzing file impact for batch processing strategy...")

    if File.exists?("1-compile.log") do
      content = File.read!("1-compile.log")
      lines = String.split(content, "\n")
      errors = extract_all_errors(lines)

      file_analysis =
        errors
        |> Enum.group_by(& &1.file)
        |> Enum.map(fn {file, file_errors} ->
          error_types = Enum.group_by(file_errors, & &1.type)
          %{
            file: file,
            total_errors: length(file_errors),
            undefined_variables: length(Map.get(error_types, :undefined_variable, [])),
            undefined_functions: length(Map.get(error_types, :undefined_function, [])),
            other_errors: length(file_errors) - length(Map.get(error_types, :undefined_variable, [])) - length(Map.get(error_types, :undefined_function, []))
          }
        end)
        |> Enum.sort_by(& &1.total_errors, :desc)
        |> Enum.take(20)

      IO.puts("\n🎯 TOP 20 FILES BY ERROR COUNT:")
      Enum.each(file_analysis, fn analysis ->
        IO.puts("  📄 #{analysis.file}")
        IO.puts("    🔴 Total: #{analysis.total_errors} | Variables: #{analysis.undefined_variables} | Functions: #{analysis.undefined_functions} | Other: #{analysis.other_errors}")
      end)

      # Save for batch processing strategy
      timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
      filename = "./data/tmp/file_impact_analysis_#{timestamp}.json"
      File.write!(filename, Jason.encode!(file_analysis, pretty: true))
      IO.puts("\n💾 File impact analysis saved to: #{filename}")

    else
      IO.puts("❌ 1-compile.log not found")
    end
  end

  defp analyze_criticality do
    IO.puts("🔍 Performing criticality analysis for unused functions...")

    if File.exists?("1-compile.log") do
      content = File.read!("1-compile.log")
      lines = String.split(content, "\n")
      warnings = extract_all_warnings(lines)

      unused_warnings = Enum.filter(warnings, & &1.type == :unused_variable)

      IO.puts("\n📊 UNUSED VARIABLE ANALYSIS:")
      IO.puts("  🟡 Total unused warnings: #{length(unused_warnings)}")

      # Analyze by file
      file_analysis =
        unused_warnings
        |> Enum.group_by(& &1.file)
        |> Enum.map(fn {file, file_warnings} -> {file, length(file_warnings)} end)
        |> Enum.sort_by(fn {_file, count} -> -count end)
        |> Enum.take(15)

      IO.puts("\n🎯 FILES WITH MOST UNUSED VARIABLES:")
      Enum.each(file_analysis, fn {file, count} ->
        IO.puts("  📄 #{file}: #{count} unused variables")
      end)

      # Extract specific unused variable patterns
      unused_patterns =
        unused_warnings
        |> Enum.map(& &1.content)
        |> Enum.map(&extract_unused_variable_name/1)
        |> Enum.filter(& &1 != nil)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_var, count} -> -count end)
        |> Enum.take(20)

      IO.puts("\n🏷️ MOST COMMON UNUSED VARIABLE PATTERNS:")
      Enum.each(unused_patterns, fn {pattern, count} ->
        IO.puts("  🔹 #{pattern}: #{count} occurrences")
      end)

    else
      IO.puts("❌ 1-compile.log not found")
    end
  end

  defp extract_unused_variable_name(warning_line) do
    case Regex.run(~r/variable "([^"]+)" is unused/, warning_line) do
      [_, var_name] -> var_name
      _ -> nil
    end
  end
end

# Execute with command line arguments
System.argv() |> ComprehensiveCompilationErrorAnalyzer.main()