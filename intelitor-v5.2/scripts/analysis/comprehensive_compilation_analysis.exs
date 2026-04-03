#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveCompilationAnalysis do
  @moduledoc """
  SOPv5.11 AEE Cybernetic Compilation Analysis Engine
  Systematically analyzes 1-compile.log for errors and warnings
  """

  def main(args \\ []) do
    log_file = "1-compile.log"

    IO.puts("🚀 SOPv5.11 AEE: Comprehensive Compilation Analysis")
    IO.puts("📊 Analyzing: #{log_file}")
    IO.puts("⏰ Timestamp: #{DateTime.utc_now()}")

    case File.read(log_file) do
      {:ok, content} ->
        analysis = analyze_compilation(content)
        generate_comprehensive_report(analysis)
        save_analysis_results(analysis)

      {:error, reason} ->
        IO.puts("❌ Error reading #{log_file}: #{reason}")
        System.halt(1)
    end
  end

  def analyze_compilation(content) do
    lines = String.split(content, "\n")

    %{
      total_lines: length(lines),
      errors: extract_errors(lines),
      warnings: extract_warnings(lines),
      files_analyzed: extract_compiled_files(lines),
      summary: generate_summary_stats(lines)
    }
  end

  defp extract_errors(lines) do
    error_lines = Enum.filter(lines, &String.contains?(&1, "error:"))

    errors =
      Enum.map(error_lines, fn line ->
        %{
          type: classify_error_type(line),
          message: extract_error_message(line),
          file: extract_file_location(line),
          line_number: extract_line_number(line),
          raw: line
        }
      end)

    %{
      count: length(errors),
      by_type: group_by_type(errors),
      by_file: group_by_file(errors),
      details: errors
    }
  end

  defp extract_warnings(lines) do
    warning_lines = Enum.filter(lines, &String.contains?(&1, "warning:"))

    warnings =
      Enum.map(warning_lines, fn line ->
        %{
          type: classify_warning_type(line),
          message: extract_warning_message(line),
          file: extract_file_location(line),
          line_number: extract_line_number(line),
          severity: classify_warning_severity(line),
          raw: line
        }
      end)

    %{
      count: length(warnings),
      by_type: group_by_type(warnings),
      by_severity: group_by_severity(warnings),
      by_file: group_by_file(warnings),
      details: warnings
    }
  end

  defp extract_compiled_files(lines) do
    compiled_lines = Enum.filter(lines, &String.starts_with?(&1, "Compiled "))

    files =
      Enum.map(compiled_lines, fn line ->
        String.replace(line, "Compiled ", "") |> String.trim()
      end)

    %{
      count: length(files),
      files: files
    }
  end

  defp classify_error_type(line) do
    cond do
      String.contains?(line, "undefined variable") -> :undefined_variable
      String.contains?(line, "undefined function") -> :undefined_function
      String.contains?(line, "CompileError") -> :compile_error
      String.contains?(line, "syntax error") -> :syntax_error
      String.contains?(line, "** (") -> :exception_error
      true -> :other_error
    end
  end

  defp classify_warning_type(line) do
    cond do
      String.contains?(line, "variable") && String.contains?(line, "is unused") ->
        :unused_variable

      String.contains?(line, "underscored variable") && String.contains?(line, "is used") ->
        :underscored_variable_used

      String.contains?(line, "clauses with the same name") ->
        :duplicate_function_clauses

      String.contains?(line, "deprecated") ->
        :deprecated_pattern

      String.contains?(line, "cannot match because a previous clause") ->
        :unreachable_clause

      String.contains?(line, "function") && String.contains?(line, "is unused") ->
        :unused_function

      true ->
        :other_warning
    end
  end

  defp classify_warning_severity(line) do
    cond do
      String.contains?(line, "underscored variable") -> :high
      String.contains?(line, "clauses with the same name") -> :high
      String.contains?(line, "cannot match") -> :medium
      String.contains?(line, "deprecated") -> :medium
      String.contains?(line, "is unused") -> :low
      true -> :medium
    end
  end

  defp extract_error_message(line) do
    case Regex.run(~r/error:\s*(.+)/, line) do
      [_, message] -> String.trim(message)
      _ -> "Unknown error message"
    end
  end

  defp extract_warning_message(line) do
    case Regex.run(~r/warning:\s*(.+)/, line) do
      [_, message] -> String.trim(message)
      _ -> "Unknown warning message"
    end
  end

  defp extract_file_location(line) do
    case Regex.run(~r/└─\s*([^:]+)/, line) do
      [_, file] ->
        String.trim(file)

      _ ->
        case Regex.run(~r/(lib\/[^:]+)/, line) do
          [_, file] -> String.trim(file)
          _ -> "Unknown file"
        end
    end
  end

  defp extract_line_number(line) do
    case Regex.run(~r/:(\d+):/, line) do
      [_, number] -> String.to_integer(number)
      _ -> 0
    end
  end

  defp group_by_type(items) do
    Enum.group_by(items, & &1.type)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Enum.into(%{})
  end

  defp group_by_file(items) do
    Enum.group_by(items, & &1.file)
    |> Enum.map(fn {file, items} -> {file, length(items)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    # Top 20 files with most issues
    |> Enum.take(20)
  end

  defp group_by_severity(warnings) do
    Enum.group_by(warnings, & &1.severity)
    |> Enum.map(fn {severity, items} -> {severity, length(items)} end)
    |> Enum.into(%{})
  end

  defp generate_summary_stats(lines) do
    %{
      total_lines: length(lines),
      compilation_lines: count_lines_containing(lines, "Compiled "),
      error_lines: count_lines_containing(lines, "error:"),
      warning_lines: count_lines_containing(lines, "warning:"),
      success_lines: count_lines_containing(lines, "Generated "),
      time_info: extract_compilation_time(lines)
    }
  end

  defp count_lines_containing(lines, pattern) do
    Enum.count(lines, &String.contains?(&1, pattern))
  end

  defp extract_compilation_time(lines) do
    # Look for timing information in compilation output
    timing_lines =
      Enum.filter(lines, fn line ->
        String.contains?(line, "Compiling") || String.contains?(line, "Generated")
      end)

    %{
      timing_lines_found: length(timing_lines),
      estimated_duration: "Available in detailed analysis"
    }
  end

  def generate_comprehensive_report(analysis) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🚀 SOPv5.11 AEE COMPREHENSIVE COMPILATION ANALYSIS REPORT")
    IO.puts(String.duplicate("=", 80))

    print_summary(analysis)
    print_error_analysis(analysis.errors)
    print_warning_analysis(analysis.warnings)
    print_file_analysis(analysis)
    print_recommendations(analysis)

    IO.puts(String.duplicate("=", 80))
  end

  defp print_summary(%{
         summary: summary,
         errors: errors,
         warnings: warnings,
         files_analyzed: files
       }) do
    IO.puts("\n📊 COMPILATION SUMMARY")
    IO.puts("├── Total Lines Analyzed: #{summary.total_lines}")
    IO.puts("├── Files Compiled: #{files.count}")
    IO.puts("├── Total Errors: #{errors.count}")
    IO.puts("├── Total Warnings: #{warnings.count}")

    IO.puts(
      "└── Success Rate: #{calculate_success_rate(errors.count, warnings.count, files.count)}%"
    )
  end

  defp print_error_analysis(%{count: count, by_type: by_type, by_file: by_file}) do
    IO.puts("\n🚨 ERROR ANALYSIS (#{count} total)")

    if count > 0 do
      IO.puts("├── By Type:")

      Enum.each(by_type, fn {type, count} ->
        IO.puts("│   ├── #{type}: #{count}")
      end)

      IO.puts("├── Top Files with Errors:")

      by_file
      |> Enum.take(10)
      |> Enum.each(fn {file, count} ->
        IO.puts("│   ├── #{file}: #{count}")
      end)
    else
      IO.puts("├── ✅ No compilation errors detected")
    end
  end

  defp print_warning_analysis(%{
         count: count,
         by_type: by_type,
         by_severity: by_severity,
         by_file: by_file
       }) do
    IO.puts("\n⚠️  WARNING ANALYSIS (#{count} total)")

    IO.puts("├── By Type:")

    Enum.each(by_type, fn {type, count} ->
      IO.puts("│   ├── #{type}: #{count}")
    end)

    IO.puts("├── By Severity:")

    Enum.each(by_severity, fn {severity, count} ->
      IO.puts("│   ├── #{severity}: #{count}")
    end)

    IO.puts("├── Top Files with Warnings:")

    by_file
    |> Enum.take(10)
    |> Enum.each(fn {file, count} ->
      IO.puts("│   ├── #{file}: #{count}")
    end)
  end

  defp print_file_analysis(%{files_analyzed: files, errors: errors, warnings: warnings}) do
    IO.puts("\n📁 FILE ANALYSIS")
    IO.puts("├── Total Files Compiled: #{files.count}")
    IO.puts("├── Files with Errors: #{length(Enum.uniq(Enum.map(errors.details, & &1.file)))}")

    IO.puts(
      "├── Files with Warnings: #{length(Enum.uniq(Enum.map(warnings.details, & &1.file)))}"
    )

    clean_files =
      files.count - length(Enum.uniq(Enum.map(errors.details ++ warnings.details, & &1.file)))

    IO.puts("└── Clean Files: #{clean_files}")
  end

  defp print_recommendations(analysis) do
    IO.puts("\n🎯 SOPv5.11 AEE AGENT DEPLOYMENT RECOMMENDATIONS")

    errors = analysis.errors
    warnings = analysis.warnings

    IO.puts("├── Priority 1 (Critical): Fix #{errors.count} compilation errors")

    if errors.count > 0 do
      IO.puts("│   ├── Deploy Error Resolution Agent (Agent-081)")
      IO.puts("│   ├── Focus: #{get_top_error_type(errors.by_type)}")
      IO.puts("│   └── Target Files: #{get_top_error_files(errors.by_file, 3)}")
    end

    IO.puts(
      "├── Priority 2 (High): Fix #{Map.get(warnings.by_severity, :high, 0)} high-severity warnings"
    )

    IO.puts(
      "├── Priority 3 (Medium): Fix #{Map.get(warnings.by_severity, :medium, 0)} medium-severity warnings"
    )

    IO.puts(
      "└── Priority 4 (Low): Fix #{Map.get(warnings.by_severity, :low, 0)} low-severity warnings"
    )

    IO.puts("\n🤖 AGENT ASSIGNMENT STRATEGY:")
    IO.puts("├── Agent-081: Critical Error Resolution")
    IO.puts("├── Agent-082: High-Severity Warning Elimination")
    IO.puts("├── Agent-083: Variable and Function Optimization")
    IO.puts("└── Agent-084: Code Quality and Modernization")
  end

  defp calculate_success_rate(errors, warnings, files) when files > 0 do
    clean_files = files - max(errors, warnings)
    Float.round(clean_files / files * 100, 1)
  end

  defp calculate_success_rate(_, _, _), do: 0.0

  defp get_top_error_type(by_type) do
    case Enum.max_by(by_type, fn {_, count} -> count end, fn -> {:none, 0} end) do
      {type, _} -> type
      _ -> :none
    end
  end

  defp get_top_error_files(by_file, limit) do
    by_file
    |> Enum.take(limit)
    |> Enum.map(fn {file, _} -> Path.basename(file) end)
    |> Enum.join(", ")
  end

  def save_analysis_results(analysis) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./data/tmp/#{timestamp}-comprehensive-compilation-analysis.json"

    File.write!(filename, Jason.encode!(analysis, pretty: true))
    IO.puts("\n💾 Analysis saved to: #{filename}")

    # Also save a human-readable summary
    summary_filename = "./data/tmp/#{timestamp}-compilation-analysis-summary.txt"
    summary_content = generate_text_summary(analysis)
    File.write!(summary_filename, summary_content)
    IO.puts("📄 Summary saved to: #{summary_filename}")
  end

  defp generate_text_summary(analysis) do
    """
    SOPv5.11 AEE Comprehensive Compilation Analysis Summary
    Generated: #{DateTime.utc_now()}

    CRITICAL METRICS:
    - Total Errors: #{analysis.errors.count}
    - Total Warnings: #{analysis.warnings.count}
    - Files Compiled: #{analysis.files_analyzed.count}
    - Success Rate: #{calculate_success_rate(analysis.errors.count, analysis.warnings.count, analysis.files_analyzed.count)}%

    TOP ERROR TYPES:
    #{format_type_counts(analysis.errors.by_type)}

    TOP WARNING TYPES:
    #{format_type_counts(analysis.warnings.by_type)}

    WARNING SEVERITY DISTRIBUTION:
    #{format_severity_counts(analysis.warnings.by_severity)}

    AGENT DEPLOYMENT PRIORITY:
    1. Critical Error Resolution (#{analysis.errors.count} errors)
    2. High-Severity Warnings (#{Map.get(analysis.warnings.by_severity, :high, 0)} warnings)
    3. Medium-Severity Warnings (#{Map.get(analysis.warnings.by_severity, :medium, 0)} warnings)
    4. Low-Severity Warnings (#{Map.get(analysis.warnings.by_severity, :low, 0)} warnings)

    RECOMMENDED NEXT ACTIONS:
    - Deploy 4-agent error resolution system
    - Implement systematic variable renaming
    - Apply function clause consolidation
    - Execute deprecated pattern modernization
    """
  end

  defp format_type_counts(type_counts) do
    type_counts
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.map(fn {type, count} -> "- #{type}: #{count}" end)
    |> Enum.join("\n")
  end

  defp format_severity_counts(severity_counts) do
    severity_counts
    |> Enum.map(fn {severity, count} -> "- #{severity}: #{count}" end)
    |> Enum.join("\n")
  end
end

# Execute analysis
ComprehensiveCompilationAnalysis.main(System.argv())
