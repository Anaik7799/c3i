#!/usr/bin/env elixir

# Simple but Reliable Log Analyzer for SOPv5.11 Cybernetic Framework
# TPS-Jidoka: Immediate stop-and-fix for analysis accuracy

defmodule SimpleLogAnalyzer do
  def main(args) do
    log_file = get_log_file(args)

    IO.puts("🤖 SOPv5.11 Executive Director Agent: Starting Simple Analysis")
    IO.puts("📊 Analyzing compilation log: #{log_file}")

    if File.exists?(log_file) do
      content = File.read!(log_file)
      lines = String.split(content, "\n")

      # Method 1: Direct string counting
      warning_count = count_occurrences(content, "warning:")
      error_count = count_occurrences(content, "error:")

      # Method 2: Line-by-line analysis
      warning_lines = count_lines_with_substring(lines, "warning:")
      error_lines = count_lines_with_substring(lines, "error:")

      # Method 3: Unused variable specific
      unused_variable = count_occurrences(content, "is unused")
      undefined_variable = count_occurrences(content, "undefined variable")
      undefined_function = count_occurrences(content, "undefined function")

      IO.puts("\n📊 ANALYSIS RESULTS:")
      IO.puts("Method 1 - String Count:")
      IO.puts("  Warnings: #{warning_count}")
      IO.puts("  Errors: #{error_count}")

      IO.puts("\nMethod 2 - Line Count:")
      IO.puts("  Warning lines: #{warning_lines}")
      IO.puts("  Error lines: #{error_lines}")

      IO.puts("\nSpecific Issues:")
      IO.puts("  Unused variables: #{unused_variable}")
      IO.puts("  Undefined variables: #{undefined_variable}")
      IO.puts("  Undefined functions: #{undefined_function}")

      IO.puts("\n🔍 TOP WARNING FILES:")
      analyze_files_with_warnings(lines)

      IO.puts("\n🔍 TOP ERROR FILES:")
      analyze_files_with_errors(lines)

      # Generate simple report
      generate_simple_report(warning_count, error_count, log_file)

    else
      IO.puts("❌ CRITICAL: Log file #{log_file} not found")
      System.halt(1)
    end
  end

  defp get_log_file(args) do
    case args do
      [file | _] -> file
      [] -> "1-compile.log"
    end
  end

  defp count_occurrences(content, substring) do
    content
    |> String.split(substring)
    |> length()
    |> Kernel.-(1)
  end

  defp count_lines_with_substring(lines, substring) do
    Enum.count(lines, &String.contains?(&1, substring))
  end

  defp analyze_files_with_warnings(lines) do
    lines
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.take(10)
    |> Enum.with_index(1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  #{index}. #{String.slice(line, 0, 80)}...")
    end)
  end

  defp analyze_files_with_errors(lines) do
    lines
    |> Enum.filter(&String.contains?(&1, "error:"))
    |> Enum.take(10)
    |> Enum.with_index(1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  #{index}. #{String.slice(line, 0, 80)}...")
    end)
  end

  defp generate_simple_report(warnings, errors, log_file) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./data/tmp/#{timestamp}-simple-analysis-report.txt"

    report_content = """
    SOPv5.11 Simple Analysis Report
    Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    Log File: #{log_file}

    RESULTS:
    --------
    Total Warnings: #{warnings}
    Total Errors: #{errors}
    Total Issues: #{warnings + errors}

    AGENT: Executive-Director-1
    METHOD: TPS-Jidoka Simple Analysis
    STATUS: #{if warnings + errors > 10000, do: "CRITICAL", else: "HIGH"} Priority
    """

    File.write!(report_file, report_content)

    IO.puts("\n📋 Simple Analysis Report saved to: #{report_file}")
    IO.puts("🎯 TOTAL ISSUES TO FIX: #{warnings + errors}")
    IO.puts("🤖 SOPv5.11 Executive Director: Simple Analysis complete")
  end
end

# Execute main function
SimpleLogAnalyzer.main(System.argv())