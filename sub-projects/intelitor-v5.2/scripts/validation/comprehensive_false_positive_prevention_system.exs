#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveFalsePositivePr__eventionSystem do
  @moduledoc """
  Comprehensive False Positive Pr__evention System (CFPPS)

  Implements mandatory comprehensive file scanning for all error patterns
  with zero-error validation as final checkpoint in systematic elimination workflow.

  Pr__events EP-110 style false positives through multi-method consensus validation.
  """

  __require Logger

  # All possible error patterns that can cause compilation failures
  @error_patterns [
    # Standard compilation errors
    "error:", "** (", "CompileError", "cannot compile module",
    "== Compilation error", "syntax error", "type specification",

    # Variable and function errors
    "undefined variable", "undefined function", "function .* is undefined",
    "variable .* is unused", "unused import", "unused alias",

    # Parameter and argument errors
    "wrong number of arguments", "no function clause matching",
    "argument error", "bad argument", "no match of right hand side",

    # Atom and string errors
    "invalid atom", "atom .* not found", "string .* not valid",

    # Type and spec errors
    "type .* undefined", "spec .* not found", "@type .* not defined",
    "invalid type specification", "dialyzer",

    # Module and import errors
    "module .* not found", "import .* failed", "__require .* failed",
    "alias .* not found", "use .* failed",

    # Pattern matching errors
    "no pattern matches", "pattern match failed", "badmatch",

    # Structural errors
    "missing end", "unexpected token", "unexpected end of file",
    "invalid syntax", "parse error"
  ]

  # Enhanced warning patterns for comprehensive scanning
  @warning_patterns [
    "warning:", "deprecated", "TODO:", "FIXME:", "HACK:",
    "is unused", "not used", "unused variable", "unused function",
    "unused import", "unused alias", "unused module attribute",
    "variable .* is unused", "function .* is unused"
  ]

  # Parameter patterns that commonly cause issues
  @parameter_patterns [
    # Space instead of underscore in parameters
    ~r/def\s+\w+\([^)]*\s+\w+[^)]*\)/,
    ~r/defp\s+\w+\([^)]*\s+\w+[^)]*\)/,

    # Underscore prefix mismatch (parameter defined with _ but used without)
    ~r/def\s+\w+\([^)]*_\w+[^)]*\).*?\b\w+\b/,
    ~r/defp\s+\w+\([^)]*_\w+[^)]*\).*?\b\w+\b/,

    # Invalid atom syntax with spaces
    ~r/\{:\s+\w+/,
    ~r/:\s+\w+/,

    # Type specification errors
    ~r/@type\s+\w+\s+\w+\s+::/,
    ~r/@spec\s+\w+\([^)]*\s+\w+[^)]*\)/
  ]

  def main(args \\ []) do
    case args do
      ["--validate"] -> run_comprehensive_validation()
      ["--scan"] -> scan_all_files()
      ["--zero-error-check"] -> run_zero_error_validation()
      ["--pattern-analysis"] -> run_comprehensive_pattern_analysis()
      ["--emergency-scan"] -> run_emergency_comprehensive_scan()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts """
    Comprehensive False Positive Pr__evention System (CFPPS)

    Usage:
      --validate           Run comprehensive validation with all methods
      --scan              Scan all files for error patterns
      --zero-error-check  Run zero-error validation checkpoint
      --pattern-analysis  Run comprehensive pattern analysis
      --emergency-scan    Emergency comprehensive scan (when false positives detected)
    """
  end

  defp run_comprehensive_validation do
    IO.puts "🔍 Running Comprehensive False Positive Pr__evention Validation"

    # Method 1: Pattern-based scanning
    pattern_result = scan_with_patterns()

    # Method 2: AST-based analysis
    ast_result = scan_with_ast_analysis()

    # Method 3: Line-by-line analysis
    line_result = scan_line_by_line()

    # Method 4: Binary pattern scanning
    binary_result = scan_with_binary_patterns()

    # Method 5: Statistical analysis
    statistical_result = run_statistical_analysis()

    # Comprehensive consensus check
    results = [pattern_result, ast_result, line_result, binary_result, statistical_result]

    if consensus_achieved?(results) do
      save_validation_report(results, :consensus_achieved)
      IO.puts "✅ Consensus achieved across all validation methods"
      System.halt(0)
    else
      save_validation_report(results, :consensus_failed)
      IO.puts "❌ CRITICAL: Validation methods disagree - FALSE POSITIVE RISK"
      IO.puts "Detailed analysis __required - check validation report"
      System.halt(2)
    end
  end

  defp run_zero_error_validation do
    IO.puts "🎯 Running Zero-Error Validation Checkpoint"

    # Run actual compilation and capture output
    compilation_result = run_patient_mode_compilation()

    case compilation_result do
      {:ok, output} ->
        error_count = count_errors_comprehensive(output)
        warning_count = count_warnings_comprehensive(output)

        if error_count == 0 do
          IO.puts "✅ ZERO-ERROR VALIDATION PASSED"
          IO.puts "   Errors: #{error_count}"
          IO.puts "   Warnings: #{warning_count}"
          save_zero_error_achievement(output, error_count, warning_count)
          System.halt(0)
        else
          IO.puts "❌ ZERO-ERROR VALIDATION FAILED"
          IO.puts "   Errors: #{error_count}"
          IO.puts "   Warnings: #{warning_count}"
          save_error_analysis(output, error_count, warning_count)
          System.halt(1)
        end

      {:error, reason} ->
        IO.puts "❌ COMPILATION FAILED: #{reason}"
        System.halt(3)
    end
  end

  defp run_comprehensive_pattern_analysis do
    IO.puts "🔬 Running Comprehensive Pattern Analysis"

    all_files = get_all_elixir_files()

    _analysis_results = Enum.map(all_files, fn file ->
      content = File.read!(file)

      %{
        file: file,
        error_patterns: scan_error_patterns(content),
        warning_patterns: scan_warning_patterns(content),
        parameter_issues: scan_parameter_patterns(content),
        structural_issues: scan_structural_issues(content),
        dependency_issues: scan_dependency_issues(content)
      }
    end)

    total_issues = Enum.reduce(analysis_results, 0, fn result, acc ->
      acc + length(result.error_patterns) + length(result.warning_patterns) +
            length(result.parameter_issues) + length(result.structural_issues) +
            length(result.dependency_issues)
    end)

    IO.puts "📊 Pattern Analysis Results:"
    IO.puts "   Files scanned: #{length(all_files)}"
    IO.puts "   Total potential issues: #{total_issues}"

    if total_issues > 0 do
      save_pattern_analysis(analysis_results)
      IO.puts "⚠️  Issues found - detailed analysis saved"
      System.halt(1)
    else
      IO.puts "✅ No pattern issues detected"
      System.halt(0)
    end
  end

  defp run_emergency_comprehensive_scan do
    IO.puts "🚨 EMERGENCY: Comprehensive Scan for False Positive Detection"

    # This is run when false positives are suspected
    # Perform exhaustive scanning with maximum detail

    compilation_output = run_patient_mode_compilation()

    case compilation_output do
      {:ok, output} ->
        # Exhaustive error detection
        errors_method1 = scan_errors_method1(output)
        errors_method2 = scan_errors_method2(output)
        errors_method3 = scan_errors_method3(output)
        errors_method4 = scan_errors_method4(output)
        errors_method5 = scan_errors_method5(output)

        all_methods = [errors_method1, errors_method2, errors_method3, errors_method4, errors_method5]

        if all_methods_agree?(all_methods) do
          error_count = hd(all_methods)
          IO.puts "✅ All methods agree: #{error_count} errors"
          save_emergency_scan_report(output, all_methods, :consensus)
          System.halt(if error_count == 0, do: 0, else: 1)
        else
          IO.puts "❌ CRITICAL: Methods disagree - FALSE POSITIVE DETECTED"
          IO.puts "Method results: #{inspect(all_methods)}"
          save_emergency_scan_report(output, all_methods, :disagreement)
          System.halt(2)
        end

      {:error, reason} ->
        IO.puts "❌ EMERGENCY SCAN FAILED: #{reason}"
        System.halt(3)
    end
  end

  # Error detection methods
  defp scan_errors_method1(output) do
    # Method 1: Simple string matching
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "error:"))
  end

  defp scan_errors_method2(output) do
    # Method 2: Regex pattern matching
    error_patterns = [
      ~r/error:/,
      ~r/\*\* \(/,
      ~r/CompileError/,
      ~r/undefined variable/,
      ~r/undefined function/
    ]

    lines = String.split(output, "\n")

    Enum.reduce(lines, 0, fn line, acc ->
      if Enum.any?(error_patterns, &Regex.match?(&1, line)) do
        acc + 1
      else
        acc
      end
    end)
  end

  defp scan_errors_method3(output) do
    # Method 3: Context-aware scanning
    lines = String.split(output, "\n")
    error_count = 0

    Enum.reduce(lines, error_count, fn line, acc ->
      cond do
        String.contains?(line, "error:") and not String.contains?(line, "warning:") -> acc + 1
        String.contains?(line, "** (") and String.contains?(line, "Error") -> acc + 1
        String.contains?(line, "undefined variable") -> acc + 1
        String.contains?(line, "undefined function") -> acc + 1
        true -> acc
      end
    end)
  end

  defp scan_errors_method4(output) do
    # Method 4: Binary scanning
    error_count = 0

    @error_patterns
    |> Enum.reduce(error_count, fn pattern, acc ->
      case String.split(output, pattern) do
        [_] -> acc  # Pattern not found
        parts -> acc + (length(parts) - 1)  # Count occurrences
      end
    end)
  end

  defp scan_errors_method5(output) do
    # Method 5: Statistical analysis
    lines = String.split(output, "\n")

    # Keywords that indicate errors
    error_keywords = ["error", "undefined", "CompileError", "cannot compile", "failed"]

    error_lines = Enum.filter(lines, fn line ->
      line_lower = String.downcase(line)
      Enum.any?(error_keywords, &String.contains?(line_lower, &1)) and
      not String.contains?(line_lower, "warning")
    end)

    length(error_lines)
  end

  defp all_methods_agree?(methods) do
    unique_results = Enum.uniq(methods)
    length(unique_results) == 1
  end

  defp run_patient_mode_compilation do
    IO.puts "⏱️  Running Patient Mode Compilation..."

    case System.cmd("mix", ["compile", "--verbose"], stderr_to_stdout: true, cd: ".") do
      {output, 0} ->
        {:ok, output}
      {output, exit_code} ->
        if String.contains?(output, "error:") do
          {:ok, output}  # Compilation ran but had errors
        else
          {:error, "Compilation failed with exit code #{exit_code}"}
        end
    end
  rescue
    error ->
      {:error, "Failed to run compilation: #{inspect(error)}"}
  end

  defp count_errors_comprehensive(output) do
    # Use multiple methods and ensure they agree
    method1 = scan_errors_method1(output)
    method2 = scan_errors_method2(output)
    method3 = scan_errors_method3(output)

    if method1 == method2 and method2 == method3 do
      method1
    else
      # Methods disagree - this is a false positive risk
      raise "ERROR COUNT METHODS DISAGREE: #{method1}, #{method2}, #{method3}"
    end
  end

  defp count_warnings_comprehensive(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "warning:"))
  end

  # File scanning methods
  defp scan_with_patterns do
    all_files = get_all_elixir_files()

    total_issues = Enum.reduce(all_files, 0, fn file, acc ->
      content = File.read!(file)
      error_count = count_pattern_matches(content, @error_patterns)
      acc + error_count
    end)

    %{method: :pattern_based, total_issues: total_issues}
  end

  defp scan_with_ast_analysis do
    # Simplified AST analysis - would use Code.string_to_quoted in real implementation
    all_files = get_all_elixir_files()

    total_issues = Enum.reduce(all_files, 0, fn file, acc ->
      content = File.read!(file)

      # Check for basic structural issues
      issues = 0

      # Count unclosed blocks
      def_count = length(Regex.scan(~r/\bdef\b/, content))
      end_count = length(Regex.scan(~r/\bend\b/, content))

      if def_count > end_count do
        issues = issues + (def_count - end_count)
      end

      acc + issues
    end)

    %{method: :ast_based, total_issues: total_issues}
  end

  defp scan_line_by_line do
    all_files = get_all_elixir_files()

    total_issues = Enum.reduce(all_files, 0, fn file, acc ->
      content = File.read!(file)

      lines = String.split(content, "\n")

      line_issues = Enum.reduce(lines, 0, fn line, line_acc ->
        if line_has_error_indicators?(line) do
          line_acc + 1
        else
          line_acc
        end
      end)

      acc + line_issues
    end)

    %{method: :line_by_line, total_issues: total_issues}
  end

  defp scan_with_binary_patterns do
    all_files = get_all_elixir_files()

    total_issues = Enum.reduce(all_files, 0, fn file, acc ->
      content = File.read!(file)

      # Binary pattern scanning for specific error indicators
      issues = 0

      # Check for parameter space issues
      if Regex.match?(~r/def\s+\w+\([^)]*\s+\w+/, content) do
        issues = issues + 1
      end

      # Check for undefined variable patterns
      if String.contains?(content, "_") and not String.contains?(content, "#{") do
        # More sophisticated check needed in real implementation
        issues = issues + 0
      end

      acc + issues
    end)

    %{method: :binary_patterns, total_issues: total_issues}
  end

  defp run_statistical_analysis do
    all_files = get_all_elixir_files()

    # Statistical analysis based on file characteristics
    total_issues = Enum.reduce(all_files, 0, fn file, acc ->
      content = File.read!(file)

      # Statistical indicators of problems
      line_count = length(String.split(content, "\n"))
      function_count = length(Regex.scan(~r/def\s+\w+/, content))

      # Very basic heuristic - files with many functions but few lines might have issues
      if function_count > 10 and line_count / function_count < 5 do
        acc + 1
      else
        acc
      end
    end)

    %{method: :statistical, total_issues: total_issues}
  end

  # Helper functions
  defp get_all_elixir_files do
    Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")
  end

  defp consensus_achieved?(results) do
    issue_counts = Enum.map(results, &Map.get(&1, :total_issues))
    unique_counts = Enum.uniq(issue_counts)
    length(unique_counts) == 1
  end

  defp line_has_error_indicators?(line) do
    error_indicators = ["error:", "undefined", "** (", "CompileError"]
    Enum.any?(error_indicators, &String.contains?(line, &1))
  end

  defp count_pattern_matches(content, patterns) do
    Enum.reduce(patterns, 0, fn pattern, acc ->
      case String.split(content, pattern) do
        [_] -> acc
        parts -> acc + (length(parts) - 1)
      end
    end)
  end

  # Save and reporting functions
  defp save_validation_report(results, status) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "./__data/tmp/cfpps_validation_report_#{timestamp}.json"

    report = %{
      timestamp: timestamp,
      status: status,
      results: results,
      consensus: status == :consensus_achieved
    }

    File.write!(filename, Jason.encode!(report, pretty: true))
    IO.puts "📄 Validation report saved: #{filename}"
  end

  defp save_zero_error_achievement(output, error_count, warning_count) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "./__data/tmp/zero_error_achievement_#{timestamp}.log"

    content = """
    # Zero-Error Validation Achievement

    Timestamp: #{timestamp}
    Status: ZERO ERRORS ACHIEVED

    Error Count: #{error_count}
    Warning Count: #{warning_count}

    Compilation Output:
    #{output}
    """

    File.write!(filename, content)
    IO.puts "🏆 Zero-error achievement documented: #{filename}"
  end

  defp save_error_analysis(output, error_count, warning_count) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "./__data/tmp/error_analysis_#{timestamp}.log"

    content = """
    # Error Analysis Report

    Timestamp: #{timestamp}
    Status: ERRORS DETECTED

    Error Count: #{error_count}
    Warning Count: #{warning_count}

    Compilation Output:
    #{output}

    Action Required: Systematic error elimination needed
    """

    File.write!(filename, content)
    IO.puts "❌ Error analysis saved: #{filename}"
  end

  defp save_emergency_scan_report(output, method_results, status) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "./__data/tmp/emergency_scan_#{timestamp}.json"

    report = %{
      timestamp: timestamp,
      status: status,
      method_results: method_results,
      compilation_output: output,
      consensus: status == :consensus
    }

    File.write!(filename, Jason.encode!(report, pretty: true))
    IO.puts "🚨 Emergency scan report saved: #{filename}"
  end

  defp save_pattern_analysis(analysis_results) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "./__data/tmp/pattern_analysis_#{timestamp}.json"

    File.write!(filename, Jason.encode!(analysis_results, pretty: true))
    IO.puts "🔬 Pattern analysis saved: #{filename}"
  end

  # Additional scanning methods for comprehensive coverage
  defp scan_error_patterns(content) do
    Enum.filter(@error_patterns, &String.contains?(content, &1))
  end

  defp scan_warning_patterns(content) do
    Enum.filter(@warning_patterns, &String.contains?(content, &1))
  end

  defp scan_parameter_patterns(content) do
    Enum.filter(@parameter_patterns, &Regex.match?(&1, content))
  end

  defp scan_structural_issues(content) do
    issues = []

    # Check for mismatched def/end
    def_count = length(Regex.scan(~r/\bdef\b/, content))
    end_count = length(Regex.scan(~r/\bend\b/, content))

    if def_count != end_count do
      issues = ["def_end_mismatch" | issues]
    end

    issues
  end

  defp scan_dependency_issues(content) do
    issues = []

    # Check for potential dependency issues
    if String.contains?(content, "alias") and String.contains?(content, "not found") do
      issues = ["alias_not_found" | issues]
    end

    issues
  end
end

# Run the script
ComprehensiveFalsePositivePr__eventionSystem.main(System.argv())