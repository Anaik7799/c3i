#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveLogAnalyzer do
  @moduledoc """
  SOPv5.11 Comprehensive Compilation Log Analyzer

  Analyzes complete 1-compile.log file to classify ALL errors and warnings
  for systematic batch processing according to SOPv5.11 protocol.
  """

  def main(args \\ []) do
    IO.puts("🔬 SOPv5.11 Comprehensive Log Analyzer")
    IO.puts("=" |> String.duplicate(50))

    case args do
      ["--analyze"] -> analyze_complete_log()
      ["--classify"] -> classify_patterns()
      ["--criticality"] -> criticality_analysis()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts("""
    Usage:
      elixir scripts/analysis/comprehensive_log_analyzer.exs --analyze
      elixir scripts/analysis/comprehensive_log_analyzer.exs --classify
      elixir scripts/analysis/comprehensive_log_analyzer.exs --criticality

    Options:
      --analyze      Complete analysis of 1-compile.log
      --classify     Classify all error and warning patterns
      --criticality  Perform criticality analysis of unused functions
    """)
  end

  defp analyze_complete_log do
    log_file = "1-compile.log"

    if File.exists?(log_file) do
      IO.puts("📊 Analyzing complete log: #{log_file}")

      content = File.read!(log_file)
      lines = String.split(content, "\n")

      analysis = %{
        total_lines: length(lines),
        errors: extract_errors(lines),
        warnings: extract_warnings(lines),
        files_affected: extract_affected_files(lines),
        patterns: classify_error_patterns(lines)
      }

      save_analysis(analysis)
      print_summary(analysis)

    else
      IO.puts("❌ File not found: #{log_file}")
    end
  end

  defp extract_errors(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "error:") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        line_number: line_num,
        content: String.trim(line),
        type: determine_error_type(line),
        file: extract_file_from_line(line),
        severity: "error"
      }
    end)
  end

  defp extract_warnings(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(line, "warning:") end)
    |> Enum.map(fn {line, line_num} ->
      %{
        line_number: line_num,
        content: String.trim(line),
        type: determine_warning_type(line),
        file: extract_file_from_line(line),
        severity: "warning"
      }
    end)
  end

  defp determine_error_type(line) do
    cond do
      String.contains?(line, "undefined variable") -> :undefined_variable
      String.contains?(line, "undefined function") -> :undefined_function
      String.contains?(line, "CompileError") -> :compile_error
      String.contains?(line, "cannot compile module") -> :module_error
      String.contains?(line, "** (") -> :exception_error
      String.contains?(line, "syntax error") -> :syntax_error
      true -> :other_error
    end
  end

  defp determine_warning_type(line) do
    cond do
      String.contains?(line, "is unused") -> :unused_variable
      String.contains?(line, "function") and String.contains?(line, "is unused") -> :unused_function
      String.contains?(line, "import") and String.contains?(line, "is unused") -> :unused_import
      String.contains?(line, "alias") and String.contains?(line, "is unused") -> :unused_alias
      String.contains?(line, "variable") and String.contains?(line, "shadowed") -> :variable_shadow
      String.contains?(line, "deprecated") -> :deprecated
      true -> :other_warning
    end
  end

  defp extract_file_from_line(line) do
    case Regex.run(~r/lib\/[^\s:]+\.ex/, line) do
      [file] -> file
      _ -> nil
    end
  end

  defp extract_affected_files(lines) do
    lines
    |> Enum.map(&extract_file_from_line/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp classify_error_patterns(lines) do
    error_lines = Enum.filter(lines, fn line ->
      String.contains?(line, "error:") or String.contains?(line, "warning:")
    end)

    %{
      undefined_variables: count_pattern(error_lines, "undefined variable"),
      undefined_functions: count_pattern(error_lines, "undefined function"),
      unused_variables: count_pattern(error_lines, "variable") |> Kernel.+(count_pattern(error_lines, "is unused")),
      unused_functions: count_pattern(error_lines, "function") |> Kernel.+(count_pattern(error_lines, "is unused")),
      compile_errors: count_pattern(error_lines, "CompileError"),
      syntax_errors: count_pattern(error_lines, "syntax error"),
      other_issues: count_other_patterns(error_lines)
    }
  end

  defp count_pattern(lines, pattern) do
    Enum.count(lines, &String.contains?(&1, pattern))
  end

  defp count_other_patterns(lines) do
    known_patterns = [
      "undefined variable", "undefined function", "is unused",
      "CompileError", "syntax error", "deprecated"
    ]

    Enum.count(lines, fn line ->
      (String.contains?(line, "error:") or String.contains?(line, "warning:")) and
      not Enum.any?(known_patterns, &String.contains?(line, &1))
    end)
  end

  defp print_summary(analysis) do
    IO.puts("\n📋 COMPREHENSIVE ANALYSIS SUMMARY")
    IO.puts("=" |> String.duplicate(40))

    IO.puts("Total log lines: #{analysis.total_lines}")
    IO.puts("Total errors: #{length(analysis.errors)}")
    IO.puts("Total warnings: #{length(analysis.warnings)}")
    IO.puts("Files affected: #{length(analysis.files_affected)}")

    IO.puts("\n🔍 ERROR PATTERN BREAKDOWN:")
    Enum.each(analysis.patterns, fn {pattern, count} ->
      IO.puts("  #{pattern}: #{count}")
    end)

    IO.puts("\n📁 TOP 10 MOST AFFECTED FILES:")
    file_counts = analysis.errors ++ analysis.warnings
    |> Enum.filter(fn %{file: file} -> file != nil end)
    |> Enum.group_by(fn %{file: file} -> file end)
    |> Enum.map(fn {file, issues} -> {file, length(issues)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(10)

    Enum.each(file_counts, fn {file, count} ->
      IO.puts("  #{file}: #{count} issues")
    end)
  end

  defp save_analysis(analysis) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./data/tmp/comprehensive_log_analysis_#{timestamp}.json"

    File.write!(filename, Jason.encode!(analysis, pretty: true))
    IO.puts("📝 Analysis saved to: #{filename}")
  end

  defp classify_patterns do
    IO.puts("🔍 Classifying patterns for batch processing...")

    # Read previous analysis or create new one
    if File.exists?("1-compile.log") do
      analyze_complete_log()
    else
      IO.puts("❌ 1-compile.log not found")
    end
  end

  defp criticality_analysis do
    IO.puts("⚖️ Performing criticality analysis of unused functions...")

    # This will analyze unused functions for safe removal/commenting
    # Based on SOPv5.11 agent-friendly methodology

    log_file = "1-compile.log"
    if File.exists?(log_file) do
      content = File.read!(log_file)

      unused_functions = extract_unused_functions(content)

      criticality_map = %{
        safe_to_remove: [],
        safe_to_comment: [],
        requires_review: [],
        keep_as_is: []
      }

      classified = classify_unused_functions(unused_functions, criticality_map)

      save_criticality_analysis(classified)
      print_criticality_summary(classified)

    else
      IO.puts("❌ File not found: #{log_file}")
    end
  end

  defp extract_unused_functions(content) do
    content
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "function") && String.contains?(&1, "is unused"))
    |> Enum.map(&parse_unused_function/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_unused_function(line) do
    # Extract function name and location from warning line
    case Regex.run(~r/function\s+(\w+\/\d+)\s+is unused.*└─\s+(lib\/[^\s:]+\.ex):(\d+)/, line) do
      [_, function, file, line_num] ->
        %{
          function: function,
          file: file,
          line: String.to_integer(line_num),
          context: String.trim(line)
        }
      _ -> nil
    end
  end

  defp classify_unused_functions(functions, classification) do
    Enum.reduce(functions, classification, fn func, acc ->
      criticality = assess_function_criticality(func)

      case criticality do
        :safe_remove -> %{acc | safe_to_remove: [func | acc.safe_to_remove]}
        :safe_comment -> %{acc | safe_to_comment: [func | acc.safe_to_comment]}
        :needs_review -> %{acc | requires_review: [func | acc.requires_review]}
        :keep -> %{acc | keep_as_is: [func | acc.keep_as_is]}
      end
    end)
  end

  defp assess_function_criticality(func) do
    # SOPv5.11 Agent-friendly criticality assessment
    cond do
      # Helper functions with no external dependencies
      String.contains?(func.function, "helper/") or
      String.contains?(func.function, "parse_") or
      String.contains?(func.function, "format_") -> :safe_comment

      # Test-related functions
      String.contains?(func.file, "test/") -> :safe_remove

      # Public API functions - keep for compatibility
      String.contains?(func.function, "/0") and
      String.contains?(func.file, "web/") -> :keep

      # Internal utilities - safe to comment
      String.contains?(func.function, "_") -> :safe_comment

      # Everything else needs review
      true -> :needs_review
    end
  end

  defp save_criticality_analysis(classification) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./data/tmp/criticality_analysis_#{timestamp}.json"

    File.write!(filename, Jason.encode!(classification, pretty: true))
    IO.puts("📝 Criticality analysis saved to: #{filename}")
  end

  defp print_criticality_summary(classification) do
    IO.puts("\n⚖️ CRITICALITY ANALYSIS SUMMARY")
    IO.puts("=" |> String.duplicate(40))

    IO.puts("Safe to remove: #{length(classification.safe_to_remove)}")
    IO.puts("Safe to comment: #{length(classification.safe_to_comment)}")
    IO.puts("Requires review: #{length(classification.requires_review)}")
    IO.puts("Keep as-is: #{length(classification.keep_as_is)}")

    if length(classification.safe_to_remove) > 0 do
      IO.puts("\n🗑️ SAFE TO REMOVE:")
      Enum.take(classification.safe_to_remove, 5)
      |> Enum.each(fn func ->
        IO.puts("  #{func.function} in #{func.file}:#{func.line}")
      end)
    end

    if length(classification.safe_to_comment) > 0 do
      IO.puts("\n💬 SAFE TO COMMENT:")
      Enum.take(classification.safe_to_comment, 5)
      |> Enum.each(fn func ->
        IO.puts("  #{func.function} in #{func.file}:#{func.line}")
      end)
    end
  end
end

# Execute with command line arguments
System.argv() |> ComprehensiveLogAnalyzer.main()