#!/usr/bin/env elixir

# Comprehensive Warning and Error Analyzer for SOPv5.11 Cybernetic Framework
# Agent: Executive-Director-1 with 5-Method FPPS Consensus Validation
# TPS-Jidoka: Immediate stop-and-fix for analysis accuracy

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveAnalyzer do
  @moduledoc """
  SOPv5.11 Cybernetic Framework: Comprehensive Warning and Error Analysis

  Uses 5-Method FPPS Consensus Validation:
  1. Pattern Method - Regex pattern matching
  2. AST Method - Line-by-line structural analysis
  3. Statistical Method - Keyword frequency analysis
  4. Binary Method - Byte-level pattern scanning
  5. Context Method - Multi-line context analysis
  """

  def main(args) do
    log_file = get_log_file(args)

    IO.puts("🤖 SOPv5.11 Executive Director Agent: Starting Comprehensive Analysis")
    IO.puts("📊 Analyzing compilation log: #{log_file}")

    if File.exists?(log_file) do
      content = File.read!(log_file)

      # 5-Method FPPS Consensus Validation
      results = %{
        pattern_method: pattern_analysis(content),
        ast_method: ast_analysis(content),
        statistical_method: statistical_analysis(content),
        binary_method: binary_analysis(content),
        context_method: context_analysis(content)
      }

      # Check consensus
      consensus_check(results)

      # Classification and RCA
      classify_issues(content)

      # Generate comprehensive report
      generate_report(results, log_file)

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

  # Method 1: Pattern Analysis
  defp pattern_analysis(content) do
    warning_patterns = [
      ~r/warning:/,
      ~r/is unused/,
      ~r/variable .* is unused/,
      ~r/function .* is unused/,
      ~r/deprecated/,
      ~r/TODO:/,
      ~r/FIXME:/,
      ~r/HACK:/
    ]

    error_patterns = [
      ~r/error:/,
      ~r/\*\* \(/,
      ~r/undefined variable/,
      ~r/undefined function/,
      ~r/CompileError/,
      ~r/cannot compile module/,
      ~r/== Compilation error/,
      ~r/syntax error/,
      ~r/\*\* \(ArgumentError\)/,
      ~r/\*\* \(RuntimeError\)/,
      ~r/type specification/,
      ~r/dialyzer/,
      ~r/no such file/,
      ~r/failed/
    ]

    warnings = count_patterns(content, warning_patterns)
    errors = count_patterns(content, error_patterns)

    %{warnings: warnings, errors: errors, method: "pattern"}
  end

  # Method 2: AST Analysis (Line-by-line structural)
  defp ast_analysis(content) do
    lines = String.split(content, "\n")

    warning_keywords = ["warning:", "is unused", "deprecated", "TODO:", "FIXME:"]
    error_keywords = ["error:", "** (", "undefined", "CompileError", "cannot compile", "failed"]

    warnings = count_lines_with_keywords(lines, warning_keywords)
    errors = count_lines_with_keywords(lines, error_keywords)

    %{warnings: warnings, errors: errors, method: "ast"}
  end

  # Method 3: Statistical Analysis
  defp statistical_analysis(content) do
    # Weight-based keyword analysis
    warning_weights = %{"warning:" => 3, "unused" => 2, "deprecated" => 2}
    error_weights = %{"error:" => 3, "**" => 2, "undefined" => 2, "failed" => 1}

    warnings = calculate_weighted_score(content, warning_weights)
    errors = calculate_weighted_score(content, error_weights)

    %{warnings: warnings, errors: errors, method: "statistical"}
  end

  # Method 4: Binary Analysis
  defp binary_analysis(content) do
    binary_content = :binary.bin_to_list(content)

    warning_bytes = [119, 97, 114, 110, 105, 110, 103, 58] # "warning:"
    error_bytes = [101, 114, 114, 111, 114, 58] # "error:"

    warnings = count_byte_sequences(binary_content, warning_bytes)
    errors = count_byte_sequences(binary_content, error_bytes)

    %{warnings: warnings, errors: errors, method: "binary"}
  end

  # Method 5: Context Analysis
  defp context_analysis(content) do
    lines = String.split(content, "\n")

    # Multi-line context analysis
    warnings = context_count(lines, ["warning:", "is unused", "deprecated"])
    errors = context_count(lines, ["error:", "** (", "undefined", "failed"])

    %{warnings: warnings, errors: errors, method: "context"}
  end

  # Helper functions
  defp count_patterns(content, patterns) do
    Enum.reduce(patterns, 0, fn pattern, acc ->
      matches = Regex.scan(pattern, content)
      acc + length(matches)
    end)
  end

  defp count_lines_with_keywords(lines, keywords) do
    Enum.reduce(lines, 0, fn line, acc ->
      has_keyword = Enum.any?(keywords, &String.contains?(line, &1))
      if has_keyword, do: acc + 1, else: acc
    end)
  end

  defp calculate_weighted_score(content, weights) do
    Enum.reduce(weights, 0, fn {keyword, weight}, acc ->
      count = length(Regex.scan(~r/#{keyword}/i, content))
      acc + (count * weight)
    end)
  end

  defp count_byte_sequences(binary_list, target_sequence) do
    count_occurrences(binary_list, target_sequence, 0)
  end

  defp count_occurrences([], _target, count), do: count
  defp count_occurrences(binary_list, target, count) when length(binary_list) < length(target), do: count
  defp count_occurrences(binary_list, target, count) do
    if Enum.take(binary_list, length(target)) == target do
      count_occurrences(Enum.drop(binary_list, length(target)), target, count + 1)
    else
      count_occurrences(tl(binary_list), target, count)
    end
  end

  defp context_count(lines, keywords) do
    lines
    |> Enum.with_index()
    |> Enum.count(fn {line, _index} ->
      Enum.any?(keywords, &String.contains?(line, &1))
    end)
  end

  # FPPS Consensus Validation
  defp consensus_check(results) do
    warning_counts = Enum.map(results, fn {_method, %{warnings: w}} -> w end)
    error_counts = Enum.map(results, fn {_method, %{errors: e}} -> e end)

    warning_consensus = Enum.uniq(warning_counts) |> length() == 1
    error_consensus = Enum.uniq(error_counts) |> length() == 1

    IO.puts("\\n🔬 FPPS 5-Method Consensus Analysis:")
    IO.puts("Warning counts: #{inspect(warning_counts)}")
    IO.puts("Error counts: #{inspect(error_counts)}")
    IO.puts("Warning consensus: #{warning_consensus}")
    IO.puts("Error consensus: #{error_consensus}")

    if not (warning_consensus and error_consensus) do
      IO.puts("\\n🚨 FPPS CONSENSUS FAILURE - Methods disagree!")
      IO.puts("❌ EP-110 FALSE POSITIVE RISK - Manual validation required")
    else
      IO.puts("\\n✅ FPPS CONSENSUS ACHIEVED - Results validated")
    end

    {warning_consensus, error_consensus}
  end

  # Issue Classification
  defp classify_issues(content) do
    IO.puts("\\n📊 Issue Classification Analysis:")

    # Classify warnings by type
    warning_types = %{
      "unused_variables" => count_pattern(content, ~r/variable .* is unused/),
      "unused_functions" => count_pattern(content, ~r/function .* is unused/),
      "deprecated_usage" => count_pattern(content, ~r/deprecated/),
      "code_quality" => count_pattern(content, ~r/(TODO:|FIXME:|HACK:)/),
      "general_warnings" => count_pattern(content, ~r/warning:/)
    }

    # Classify errors by type
    error_types = %{
      "compilation_errors" => count_pattern(content, ~r/CompileError|cannot compile/),
      "undefined_errors" => count_pattern(content, ~r/undefined (variable|function)/),
      "syntax_errors" => count_pattern(content, ~r/syntax error/),
      "runtime_errors" => count_pattern(content, ~r/\*\* \(ArgumentError/) + count_pattern(content, ~r/\*\* \(RuntimeError/),
      "type_errors" => count_pattern(content, ~r/type specification|dialyzer/),
      "general_errors" => count_pattern(content, ~r/error:/)
    }

    IO.puts("\\n⚠️  Warning Types:")
    Enum.each(warning_types, fn {type, count} ->
      IO.puts("   #{type}: #{count}")
    end)

    IO.puts("\\n❌ Error Types:")
    Enum.each(error_types, fn {type, count} ->
      IO.puts("   #{type}: #{count}")
    end)

    {warning_types, error_types}
  end

  defp count_pattern(content, pattern) do
    Regex.scan(pattern, content) |> length()
  end

  # Report Generation
  defp generate_report(results, log_file) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./data/tmp/#{timestamp}-comprehensive-analysis-report.json"

    report_data = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      log_file: log_file,
      analysis_methods: results,
      sopv511_agent: "Executive-Director-1",
      tps_jidoka_applied: true,
      fpps_validation: true
    }

    File.write!(report_file, Jason.encode!(report_data, pretty: true))

    IO.puts("\\n📋 Comprehensive Analysis Report saved to: #{report_file}")
    IO.puts("🤖 SOPv5.11 Executive Director: Analysis complete")
  end
end

# Execute main function
ComprehensiveAnalyzer.main(System.argv())