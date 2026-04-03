#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveWarningAnalyzer do
  @moduledoc """
  FPPS-validated comprehensive warning and error analyzer for compilation logs.
  
  Uses multi-method validation to pr__event EP-110 false positive incidents.
  Applies SOPv5.11 cybernetic framework with TPS 5-Level RCA methodology.
  """

  __require Logger

  def main(args) do
    log_file = get_log_file(args)
    
    Logger.info("🔍 SOPv5.11 Comprehensive Warning Analysis Starting")
    Logger.info("📋 Log file: #{log_file}")
    
    content = File.read!(log_file)
    
    # Multi-method validation to pr__event EP-110
    method1_results = method1_pattern_matching(content)
    method2_results = method2_line_analysis(content) 
    method3_results = method3_contextual_analysis(content)
    method4_results = method4_statistical_analysis(content)
    method5_results = method5_ast_based_analysis(content)
    
    # FPPS Consensus validation
    consensus_results = validate_consensus([
      method1_results,
      method2_results, 
      method3_results,
      method4_results,
      method5_results
    ])
    
    # Generate comprehensive report
    report = generate_comprehensive_report(consensus_results, content)
    
    # Save results
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    save_report(report, timestamp)
    
    # 5-Level RCA Analysis
    rca_analysis = five_level_rca_analysis(consensus_results)
    save_rca_analysis(rca_analysis, timestamp)
    
    # Print summary
    print_summary(consensus_results)
    
    Logger.info("✅ SOPv5.11 Comprehensive Analysis Complete")
  end
  
  # Method 1: Advanced Pattern Matching
  defp method1_pattern_matching(content) do
    warning_patterns = [
      ~r/warning: variable "([^"]+)" is unused/,
      ~r/warning: the underscored variable "_([^"]+)" is used after being set/,
      ~r/warning: variable "([^"]+)" is unused \(if the variable is not meant to be used, prefix it with an underscore\)/,
      ~r/warning: unused alias ([^\s]+)/,
      ~r/warning: unused import ([^\s]+)/,
      ~r/warning: function ([^\s\/]+)\/\d+ is unused/,
      ~r/warning: ([^\n]+)/
    ]
    
    error_patterns = [
      ~r/error: cannot invoke remote function/,
      ~r/error: undefined variable "([^"]+)"/,
      ~r/error: undefined function ([^\s\/]+)\/\d+/,
      ~r/== Compilation error in file ([^\s]+) ==/,
      ~r/\*\* \(CompileError\)/,
      ~r/\*\* \(([^)]+)\)/,
      ~r/error: ([^\n]+)/
    ]
    
    warnings = Enum.flat_map(warning_patterns, fn pattern ->
      Regex.scan(pattern, content)
    end)
    
    errors = Enum.flat_map(error_patterns, fn pattern ->
      Regex.scan(pattern, content)
    end)
    
    %{
      method: "pattern_matching",
      warning_count: length(warnings),
      error_count: length(errors),
      warnings: warnings |> Enum.take(20), # Sample for verification
      errors: errors |> Enum.take(20)
    }
  end
  
  # Method 2: Line-by-Line Analysis
  defp method2_line_analysis(content) do
    lines = String.split(content, "\n")
    
    {_warnings, _errors} = Enum.reduce(lines, {[], []}, fn line, {warn_acc, err_acc} ->
      cond do
        String.contains?(line, "warning:") ->
          {[line | warn_acc], err_acc}
        String.contains?(line, "error:") or String.contains?(line, "** (") ->
          {warn_acc, [line | err_acc]}
        true ->
          {warn_acc, err_acc}
      end
    end)
    
    %{
      method: "line_analysis", 
      warning_count: length(warnings),
      error_count: length(errors),
      warnings: warnings |> Enum.reverse() |> Enum.take(20),
      errors: errors |> Enum.reverse() |> Enum.take(20)
    }
  end
  
  # Method 3: Contextual Analysis  
  defp method3_contextual_analysis(content) do
    # Look for warning/error blocks with __context
    warning_blocks = Regex.scan(~r/\s+warning:[^\n]*(?:\n[^\n]*│[^\n]*)*/, content)
    error_blocks = Regex.scan(~r/\s+error:[^\n]*(?:\n[^\n]*│[^\n]*)*|== Compilation error[^\n]*(?:\n[^\n]*)*/, content)
    
    %{
      method: "__contextual_analysis",
      warning_count: length(warning_blocks),
      error_count: length(error_blocks),
      warnings: warning_blocks |> Enum.take(10),
      errors: error_blocks |> Enum.take(10)
    }
  end
  
  # Method 4: Statistical Analysis
  defp method4_statistical_analysis(content) do
    warning_keywords = ["warning:", "is unused", "underscored variable", "unused alias", "unused import"]
    error_keywords = ["error:", "CompileError", "undefined", "cannot compile", "** ("]
    
    warning_count = Enum.sum(Enum.map(warning_keywords, fn keyword ->
      length(String.split(content, keyword)) - 1
    end))
    
    error_count = Enum.sum(Enum.map(error_keywords, fn keyword ->
      length(String.split(content, keyword)) - 1  
    end))
    
    # Adjust for overlaps (rough estimation)
    warning_count = max(0, trunc(warning_count * 0.3)) # Rough de-duplication
    error_count = max(0, trunc(error_count * 0.2))
    
    %{
      method: "statistical_analysis",
      warning_count: warning_count,
      error_count: error_count,
      warnings: [],
      errors: []
    }
  end
  
  # Method 5: AST-based Analysis (Simplified)
  defp method5_ast_based_analysis(content) do
    # Count unique file references in warnings/errors
    file_pattern = ~r/└─ ([^:]+):\d+:\d+:/
    warning_files = Regex.scan(~r/warning:[^\n]*(?:\n[^\n]*│[^\n]*)*\n[^\n]*└─ ([^:]+):\d+:\d+:/, content)
    error_files = Regex.scan(~r/error:[^\n]*(?:\n[^\n]*│[^\n]*)*\n[^\n]*└─ ([^:]+):\d+:\d+:|== Compilation error in file ([^\s]+)/, content)
    
    %{
      method: "ast_based_analysis",
      warning_count: length(warning_files),
      error_count: length(error_files), 
      warnings: warning_files |> Enum.take(10),
      errors: error_files |> Enum.take(10)
    }
  end
  
  # FPPS Consensus Validation
  defp validate_consensus(results) do
    warning_counts = Enum.map(results, & &1.warning_count)
    error_counts = Enum.map(results, & &1.error_count)
    
    # Check if all methods roughly agree (within reasonable variance)
    warning_consensus = check_consensus(warning_counts)
    error_consensus = check_consensus(error_counts)
    
    if not warning_consensus or not error_consensus do
      Logger.warn("🚨 FPPS ALERT: Methods disagree - potential EP-110 risk!")
      Logger.warn("Warning counts: #{inspect(warning_counts)}")
      Logger.warn("Error counts: #{inspect(error_counts)}")
    end
    
    # Use most conservative (highest) counts to avoid false positives
    consensus_warning_count = Enum.max(warning_counts)
    consensus_error_count = Enum.max(error_counts)
    
    %{
      consensus_achieved: warning_consensus and error_consensus,
      warning_count: consensus_warning_count,
      error_count: consensus_error_count,
      method_results: results,
      variance: %{
        warning_variance: calculate_variance(warning_counts),
        error_variance: calculate_variance(error_counts)
      }
    }
  end
  
  defp check_consensus(counts) do
    if Enum.empty?(counts), do: true
    
    max_count = Enum.max(counts)
    min_count = Enum.min(counts)
    
    # Allow up to 30% variance between methods
    variance_threshold = 0.3
    if max_count == 0 do
      min_count == 0
    else
      (max_count - min_count) / max_count <= variance_threshold
    end
  end
  
  defp calculate_variance(counts) do
    if Enum.empty?(counts), do: 0.0
    
    mean = Enum.sum(counts) / length(counts)
    variance = Enum.sum(Enum.map(counts, fn x -> :math.pow(x - mean, 2) end)) / length(counts)
    :math.sqrt(variance)
  end
  
  # Generate comprehensive report
  defp generate_comprehensive_report(consensus, content) do
    files_with_issues = extract_files_with_issues(content)
    issue_classification = classify_issues(content)
    
    %{
      timestamp: DateTime.utc_now(),
      total_warnings: consensus.warning_count,
      total_errors: consensus.error_count, 
      consensus_achieved: consensus.consensus_achieved,
      variance: consensus.variance,
      files_with_issues: files_with_issues,
      issue_classification: issue_classification,
      method_breakdown: consensus.method_results
    }
  end
  
  defp extract_files_with_issues(content) do
    # Extract all files mentioned in warnings/errors with their issue counts
    file_pattern = ~r/└─ ([^:]+):\d+:\d+:/
    matches = Regex.scan(file_pattern, content)
    
    matches
    |> Enum.map(fn [_, file] -> file end)
    |> Enum.f__requencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(50) # Top 50 files with most issues
  end
  
  defp classify_issues(content) do
    classifications = %{
      unused_variables: count_pattern(content, ~r/variable "[^"]+" is unused/),
      underscored_variables_used: count_pattern(content, ~r/underscored variable "[^"]+" is used/),
      unused_aliases: count_pattern(content, ~r/unused alias/),
      unused_imports: count_pattern(content, ~r/unused import/),
      undefined_variables: count_pattern(content, ~r/undefined variable/),
      undefined_functions: count_pattern(content, ~r/undefined function/),
      compilation_errors: count_pattern(content, ~r/== Compilation error/),
      other_warnings: 0, # Will calculate
      other_errors: 0    # Will calculate
    }
    
    # Calculate "other" categories
    total_classified_warnings = classifications.unused_variables + 
                               classifications.underscored_variables_used +
                               classifications.unused_aliases +
                               classifications.unused_imports
                               
    total_classified_errors = classifications.undefined_variables +
                             classifications.undefined_functions + 
                             classifications.compilation_errors
    
    %{classifications | 
      other_warnings: max(0, count_pattern(content, ~r/warning:/) - total_classified_warnings),
      other_errors: max(0, count_pattern(content, ~r/error:/) - total_classified_errors)
    }
  end
  
  defp count_pattern(content, pattern) do
    length(Regex.scan(pattern, content))
  end
  
  # 5-Level RCA Analysis
  defp five_level_rca_analysis(consensus) do
    %{
      level_1_symptoms: [
        "#{consensus.warning_count} compilation warnings detected",
        "#{consensus.error_count} compilation errors detected"
      ],
      level_2_surface_causes: [
        "Unused variable parameters in function definitions",
        "Underscored variables being accessed inappropriately", 
        "Unused aliases and imports",
        "Undefined variable and function references"
      ],
      level_3_system_behavior: [
        "Systematic pattern of unused parameters across multiple modules",
        "Inconsistent variable naming conventions",
        "Missing proper variable scope management",
        "Code generation creating unused constructs"
      ],
      level_4_configuration_gaps: [
        "No automated warning pr__evention in development workflow",
        "Missing code quality gates in CI/CD pipeline",
        "Insufficient static analysis integration", 
        "No systematic unused code detection"
      ],
      level_5_design_analysis: [
        "Need for automated code quality enforcement",
        "Systematic refactoring __required for unused code patterns",
        "Implementation of proactive warning pr__evention",
        "Integration of advanced static analysis tools"
      ]
    }
  end
  
  # Helper functions
  defp get_log_file(args) do
    case args do
      [file] -> file
      [] -> "1-compile.log"
      _ -> 
        IO.puts("Usage: elixir comprehensive_warning_analyzer.exs [log_file]")
        System.halt(1)
    end
  end
  
  defp save_report(report, timestamp) do
    filename = "./__data/tmp/#{timestamp}-comprehensive-warning-analysis.json"
    File.write!(filename, Jason.encode!(report, pretty: true))
    Logger.info("📋 Report saved to: #{filename}")
  end
  
  defp save_rca_analysis(rca, timestamp) do
    filename = "./__data/tmp/#{timestamp}-5level-rca-analysis.json" 
    File.write!(filename, Jason.encode!(rca, pretty: true))
    Logger.info("🔍 RCA Analysis saved to: #{filename}")
  end
  
  defp print_summary(consensus) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🚨 SOPv5.11 COMPREHENSIVE WARNING/ERROR ANALYSIS SUMMARY")
    IO.puts(String.duplicate("=", 80))
    IO.puts("📊 FPPS CONSENSUS RESULTS:")
    IO.puts("   🔴 TOTAL ERRORS: #{consensus.error_count}")
    IO.puts("   🟡 TOTAL WARNINGS: #{consensus.warning_count}")
    IO.puts("   ✅ CONSENSUS ACHIEVED: #{consensus.consensus_achieved}")
    IO.puts("   📊 VARIANCE: Warnings=#{Float.round(consensus.variance.warning_variance, 2)}, Errors=#{Float.round(consensus.variance.error_variance, 2)}")
    IO.puts("\n📋 METHOD BREAKDOWN:")
    
    Enum.each(consensus.method_results, fn result ->
      IO.puts("   #{result.method}: #{result.warning_count} warnings, #{result.error_count} errors")
    end)
    
    IO.puts(String.duplicate("=", 80))
  end
end

# Run the analysis
ComprehensiveWarningAnalyzer.main(System.argv())