#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule EnhancedParameterPatternRecognizer do
  @moduledoc """
  Enhanced Parameter Pattern Recognizer - Advanced Pattern Detection

  Implements enhanced pattern recognition for complex parameter scenarios
  to pr__event the underscore prefix and space-in-parameter issues that
  caused the original 92 compilation errors.

  This addresses User Requirement #3:
  "Enhance pattern recognition for complex parameter scenarios"

  Features:
  - Underscore prefix mismatch detection with __context analysis
  - Space-in-parameter pattern detection
  - Complex function parameter analysis
  - AST-based pattern recognition
  - Contextual usage analysis
  - Automatic fix suggestions
  - Pattern learning and adaptation
  """

  __require Logger

  @complex_parameter_patterns %{
    # Pattern 1: Underscore prefix mismatch
    underscore_prefix_mismatch: %{
      description: "Function parameter defined with _ prefix but used without it",
      regex: ~r/def\w*\s+(\w+)\([^)]*(_(\w+))[^)]*\)\s+do(.+?)end/ms,
      severity: :high,
      example: "defp my_func(__context) do __context.field end"
    },

    # Pattern 2: Space in parameter names
    space_in_parameter: %{
      description: "Parameter name contains spaces instead of underscores",
      regex: ~r/(\w+\s+\w+)\s*=/,
      severity: :high,
      example: "stream __opts = []"
    },

    # Pattern 3: Inconsistent parameter usage
    inconsistent_parameter_usage: %{
      description: "Parameter used inconsistently within function body",
      regex: ~r/def\w*\s+\w+\([^)]*(\w+)[^)]*\)\s+do(.+?)(?:^|\s)(\1)(?:\s|$)(.+?)end/ms,
      severity: :medium,
      example: "defp func(param) do other_param = param; param end"
    },

    # Pattern 4: Unused parameter with underscore
    unused_underscore_parameter: %{
      description: "Parameter prefixed with _ but never used",
      regex: ~r/def\w*\s+\w+\([^)]*(_\w+)[^)]*\)\s+do(.+?)end/ms,
      severity: :low,
      example: "defp func(_unused) do :ok end"
    },

    # Pattern 5: Parameter shadowing
    parameter_shadowing: %{
      description: "Parameter name shadows outer scope variable",
      regex: ~r/(\w+)\s*=.*def\w*\s+\w+\([^)]*(\1)[^)]*\)/ms,
      severity: :medium,
      example: "__state = 1; defp func(state) do __state end"
    },

    # Pattern 6: Complex multi-word parameters
    multi_word_parameter: %{
      description: "Multi-word parameter not properly snake_cased",
      regex: ~r/def\w*\s+\w+\([^)]*([a-z]+[A-Z]\w*)[^)]*\)/,
      severity: :medium,
      example: "defp func(userData) do __userData end"
    }
  }

  @ast_patterns [
    :function_definition_analysis,
    :parameter_usage_analysis,
    :variable_scope_analysis,
    :pattern_matching_analysis
  ]

  def main(args \\ []) do
    case args do
      ["--scan-all"] -> scan_all_files_for_patterns()
      ["--scan-file", file] -> scan_file_for_patterns(file)
      ["--analyze-pattern", pattern] -> analyze_specific_pattern(pattern)
      ["--generate-fixes", file] -> generate_fixes_for_file(file)
      ["--test-patterns"] -> test_pattern_recognition()
      ["--help"] -> show_help()
      _ -> scan_all_files_for_patterns()
    end
  end

  def scan_all_files_for_patterns do
    Logger.info("🔍 Enhanced Parameter Pattern Recognition Starting")
    Logger.info("📊 Scanning for complex parameter scenarios...")

    start_time = System.monotonic_time(:millisecond)

    # Find all Elixir files
    elixir_files = find_all_elixir_files()
    Logger.info("📁 Found #{length(elixir_files)} Elixir files to analyze")

    # Scan each file for patterns
    scan_results =
      elixir_files
      |> Enum.map(&scan_file_for_patterns/1)
      |> Enum.reject(&is_nil/1)

    # Aggregate results
    aggregated_results = aggregate_scan_results(scan_results)

    # Generate comprehensive report
    report = generate_pattern_recognition_report(aggregated_results, start_time)

    # Save report
    save_pattern_recognition_report(report)

    Logger.info("✅ Enhanced Pattern Recognition Complete")
    Logger.info("📊 Found #{aggregated_results.total_patterns} patterns across #{aggregated_results.files_with_patterns} files")

    report
  end

  def scan_file_for_patterns(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Apply regex-based pattern detection
        regex_patterns = detect_regex_patterns(content, file_path)

        # Apply AST-based pattern detection (simplified)
        ast_patterns = detect_ast_patterns(content, file_path)

        # Apply __contextual analysis
        __contextual_patterns = detect_contextual_patterns(content, file_path)

        total_patterns = length(regex_patterns) + length(ast_patterns) + length(__contextual_patterns)

        result = %{
          file: file_path,
          regex_patterns: regex_patterns,
          ast_patterns: ast_patterns,
          __contextual_patterns: __contextual_patterns,
          total_patterns: total_patterns,
          scan_timestamp: DateTime.utc_now()
        }

        if total_patterns > 0 do
          Logger.info("🎯 Patterns found in #{Path.basename(file_path)}: #{total_patterns} total")
        end

        result

      {:error, reason} ->
        Logger.error("❌ Failed to read #{file_path}: #{reason}")
        nil
    end
  end

  def generate_fixes_for_file(file_path) do
    Logger.info("🔧 Generating fixes for #{file_path}")

    scan_result = scan_file_for_patterns(file_path)

    if scan_result && scan_result.total_patterns > 0 do
      fixes = generate_automatic_fixes(scan_result)
      save_fixes_for_file(file_path, fixes)

      Logger.info("💾 Generated #{length(fixes)} fixes for #{file_path}")
      fixes
    else
      Logger.info("✅ No patterns __requiring fixes found in #{file_path}")
      []
    end
  end

  # Pattern Detection Methods

  defp detect_regex_patterns(content, file_path) do
    @complex_parameter_patterns
    |> Enum.flat_map(fn {pattern_name, pattern_config} ->
      matches = Regex.scan(pattern_config.regex, content, return: :index)

      Enum.map(matches, fn match_indices ->
        {_start_pos, __length} = hd(match_indices)
        line_number = get_line_number(content, start_pos)

        %{
          type: :regex_pattern,
          pattern_name: pattern_name,
          description: pattern_config.description,
          severity: pattern_config.severity,
          line: line_number,
          file: file_path,
          __context: get_line_context(content, line_number),
          match_data: extract_match_data(content, match_indices)
        }
      end)
    end)
  end

  defp detect_ast_patterns(content, file_path) do
    # Simplified AST-based detection
    # In a full implementation, this would parse the actual AST

    ast_patterns = []

    # Pattern: Function definitions with parameter issues
    function_defs = Regex.scan(~r/def\w*\s+(\w+)\(([^)]*)\)\s+do/m, content, return: :index)

    _function_patterns =
      Enum.map(function_defs, fn match_indices ->
        {_start_pos, __length} = hd(match_indices)
        line_number = get_line_number(content, start_pos)

        %{
          type: :ast_pattern,
          pattern_name: :function_definition_analysis,
          description: "Function definition detected for parameter analysis",
          severity: :info,
          line: line_number,
          file: file_path,
          __context: get_line_context(content, line_number)
        }
      end)

    ast_patterns ++ function_patterns
  end

  defp detect_contextual_patterns(content, file_path) do
    # Contextual analysis for complex scenarios
    __contextual_patterns = []

    # Pattern: Variable assignment with spaces
    space_assignments = Regex.scan(~r/([a-zA-Z]+\s+[a-zA-Z]+)\s*=/m, content, return: :index)

    _space_patterns =
      Enum.map(space_assignments, fn match_indices ->
        {_start_pos, __length} = hd(match_indices)
        line_number = get_line_number(content, start_pos)

        %{
          type: :__contextual_pattern,
          pattern_name: :space_in_assignment,
          description: "Variable assignment with spaces detected",
          severity: :high,
          line: line_number,
          file: file_path,
          __context: get_line_context(content, line_number),
          fix_suggestion: "Replace spaces with underscores in variable name"
        }
      end)

    # Pattern: Underscore prefix inconsistency
    underscore_patterns = detect_underscore_inconsistencies(content, file_path)

    __contextual_patterns ++ space_patterns ++ underscore_patterns
  end

  defp detect_underscore_inconsistencies(content, file_path) do
    # Advanced detection for underscore prefix issues
    lines = String.split(content, "\n")

    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      # Look for function definitions with underscore parameters
      case Regex.run(~r/def\w*\s+\w+\([^)]*(_(\w+))[^)]*\)/, line) do
        [_, full_param, param_name] ->
          # Check if the parameter is used without underscore in the function body
          function_body = extract_function_body(content, line_number)

          if String.contains?(function_body, param_name) and not String.contains?(function_body, full_param) do
            [%{
              type: :__contextual_pattern,
              pattern_name: :underscore_prefix_inconsistency,
              description: "Parameter #{full_param} used as #{param_name} in function body",
              severity: :high,
              line: line_number,
              file: file_path,
              __context: line,
              fix_suggestion: "Remove underscore prefix from parameter definition: #{param_name}",
              parameter: param_name,
              full_parameter: full_param
            }]
          else
            []
          end

        nil -> []
      end
    end)
  end

  # Fix Generation Methods

  defp generate_automatic_fixes(scan_result) do
    all_patterns = scan_result.regex_patterns ++ scan_result.ast_patterns ++ scan_result.__contextual_patterns

    all_patterns
    |> Enum.filter(fn pattern -> pattern.severity in [:high, :medium] end)
    |> Enum.map(&generate_fix_for_pattern/1)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_fix_for_pattern(pattern) do
    case pattern.pattern_name do
      :underscore_prefix_inconsistency ->
        %{
          pattern: pattern,
          fix_type: :parameter_rename,
          original: pattern.full_parameter,
          replacement: pattern.parameter,
          line: pattern.line,
          description: "Remove underscore prefix from parameter definition"
        }

      :space_in_assignment ->
        %{
          pattern: pattern,
          fix_type: :variable_rename,
          original: extract_spaced_variable(pattern.__context),
          replacement: String.replace(extract_spaced_variable(pattern.__context), " ", "_"),
          line: pattern.line,
          description: "Replace spaces with underscores in variable name"
        }

      :space_in_parameter ->
        %{
          pattern: pattern,
          fix_type: :parameter_rename,
          original: pattern.match_data[:variable_name],
          replacement: String.replace(pattern.match_data[:variable_name], " ", "_"),
          line: pattern.line,
          description: "Replace spaces with underscores in parameter name"
        }

      _ ->
        nil
    end
  end

  # Helper Functions

  defp find_all_elixir_files do
    ["lib", "test", "scripts"]
    |> Enum.flat_map(fn dir ->
      if File.exists?(dir) do
        Path.wildcard("#{dir}/**/*.ex") ++ Path.wildcard("#{dir}/**/*.exs")
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  defp get_line_number(content, position) do
    content
    |> String.slice(0, position)
    |> String.split("\n")
    |> length()
  end

  defp get_line_context(content, line_number) do
    lines = String.split(content, "\n")
    Enum.at(lines, line_number - 1, "")
  end

  defp extract_match_data(content, match_indices) do
    case match_indices do
      [{start_pos, length} | _] ->
        matched_text = String.slice(content, start_pos, length)
        %{matched_text: matched_text, position: start_pos}
      [] ->
        %{}
    end
  end

  defp extract_function_body(content, start_line) do
    lines = String.split(content, "\n")

    # Simple extraction - get next 10 lines after function definition
    lines
    |> Enum.drop(start_line)
    |> Enum.take(10)
    |> Enum.join("\n")
  end

  defp extract_spaced_variable(context_line) do
    case Regex.run(~r/([a-zA-Z]+\s+[a-zA-Z]+)\s*=/, __context_line) do
      [_, variable] -> variable
      _ -> ""
    end
  end

  defp aggregate_scan_results(scan_results) do
    total_files = length(scan_results)
    files_with_patterns = Enum.count(scan_results, fn result -> result.total_patterns > 0 end)

    all_patterns =
      scan_results
      |> Enum.flat_map(fn result ->
        result.regex_patterns ++ result.ast_patterns ++ result.__contextual_patterns
      end)

    pattern_counts =
      all_patterns
      |> Enum.group_by(& &1.pattern_name)
      |> Enum.map(fn {pattern_name, patterns} -> {pattern_name, length(patterns)} end)
      |> Enum.into(%{})

    severity_counts =
      all_patterns
      |> Enum.group_by(& &1.severity)
      |> Enum.map(fn {severity, patterns} -> {severity, length(patterns)} end)
      |> Enum.into(%{})

    %{
      total_files: total_files,
      files_with_patterns: files_with_patterns,
      total_patterns: length(all_patterns),
      pattern_counts: pattern_counts,
      severity_counts: severity_counts,
      scan_results: scan_results
    }
  end

  defp generate_pattern_recognition_report(aggregated_results, start_time) do
    end_time = System.monotonic_time(:millisecond)
    execution_time = end_time - start_time

    %{
      report__metadata: %{
        report_type: "enhanced_parameter_pattern_recognition",
        execution_time_ms: execution_time,
        timestamp: DateTime.utc_now(),
        __user_requirement: "Enhance pattern recognition for complex parameter scenarios"
      },
      scanning_summary: %{
        total_files_scanned: aggregated_results.total_files,
        files_with_patterns: aggregated_results.files_with_patterns,
        total_patterns_detected: aggregated_results.total_patterns
      },
      pattern_analysis: %{
        pattern_counts: aggregated_results.pattern_counts,
        severity_distribution: aggregated_results.severity_counts,
        most_common_pattern: find_most_common_pattern(aggregated_results.pattern_counts),
        highest_severity_count: Map.get(aggregated_results.severity_counts, :high, 0)
      },
      recommendations: generate_recommendations(aggregated_results),
      detailed_results: aggregated_results.scan_results
    }
  end

  defp find_most_common_pattern(pattern_counts) do
    case Enum.max_by(pattern_counts, fn {_pattern, count} -> count end, fn -> {nil, 0} end) do
      {pattern, count} when count > 0 -> %{pattern: pattern, count: count}
      _ -> %{pattern: nil, count: 0}
    end
  end

  defp generate_recommendations(aggregated_results) do
    recommendations = []

    # High severity patterns recommendation
    high_severity_count = Map.get(aggregated_results.severity_counts, :high, 0)
    recommendations = if high_severity_count > 0 do
      [%{
        priority: :high,
        action: "Fix #{high_severity_count} high severity parameter patterns immediately",
        impact: "Pr__events compilation errors"
      } | recommendations]
    else
      recommendations
    end

    # Underscore pattern recommendation
    underscore_count = Map.get(aggregated_results.pattern_counts, :underscore_prefix_inconsistency, 0)
    recommendations = if underscore_count > 0 do
      [%{
        priority: :high,
        action: "Fix #{underscore_count} underscore prefix inconsistencies",
        impact: "Resolves undefined variable errors"
      } | recommendations]
    else
      recommendations
    end

    # Space pattern recommendation
    space_count = Map.get(aggregated_results.pattern_counts, :space_in_assignment, 0)
    recommendations = if space_count > 0 do
      [%{
        priority: :high,
        action: "Fix #{space_count} space-in-variable patterns",
        impact: "Resolves syntax errors"
      } | recommendations]
    else
      recommendations
    end

    if recommendations == [] do
      [%{
        priority: :info,
        action: "No critical parameter patterns detected",
        impact: "Continue with regular development"
      }]
    else
      recommendations
    end
  end

  defp save_pattern_recognition_report(report) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/enhanced_parameter_pattern_recognition_#{timestamp}.json"

    File.mkdir_p!("./__data/tmp")
    json_content = Jason.encode!(report, pretty: true)
    File.write!(filename, json_content)

    Logger.info("💾 Pattern recognition report saved to: #{filename}")

    # Also create human-readable summary
    summary_filename = "./__data/tmp/parameter_pattern_summary_#{timestamp}.md"
    summary_content = generate_markdown_summary(report)
    File.write!(summary_filename, summary_content)

    Logger.info("📄 Summary report saved to: #{summary_filename}")
  end

  defp save_fixes_for_file(file_path, fixes) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/parameter_fixes_#{Path.basename(file_path)}_#{timestamp}.json"

    File.mkdir_p!("./__data/tmp")
    json_content = Jason.encode!(fixes, pretty: true)
    File.write!(filename, json_content)

    Logger.info("💾 Fixes saved to: #{filename}")
  end

  defp generate_markdown_summary(report) do
    """
    # Enhanced Parameter Pattern Recognition Report

    **Generated**: #{report.report__metadata.timestamp}
    **Execution Time**: #{report.report__metadata.execution_time_ms}ms
    **User Requirement**: #{report.report__metadata.__user_requirement}

    ## Summary

    - **Files Scanned**: #{report.scanning_summary.total_files_scanned}
    - **Files with Patterns**: #{report.scanning_summary.files_with_patterns}
    - **Total Patterns Detected**: #{report.scanning_summary.total_patterns_detected}

    ## Pattern Analysis

    ### Most Common Pattern
    #{if report.pattern_analysis.most_common_pattern.pattern do
      "**#{report.pattern_analysis.most_common_pattern.pattern}**: #{report.pattern_analysis.most_common_pattern.count} occurrences"
    else
      "No patterns detected"
    end}

    ### Severity Distribution
    #{Enum.map(report.pattern_analysis.severity_distribution, fn {severity, count} ->
      "- **#{severity}**: #{count}"
    end) |> Enum.join("\n")}

    ### Pattern Type Counts
    #{Enum.map(report.pattern_analysis.pattern_counts, fn {pattern, count} ->
      "- **#{pattern}**: #{count}"
    end) |> Enum.join("\n")}

    ## Recommendations

    #{Enum.map(report.recommendations, fn rec ->
      "### #{String.upcase(to_string(rec.priority))} Priority\n**Action**: #{rec.action}\n**Impact**: #{rec.impact}\n"
    end) |> Enum.join("\n")}

    ## Pattern Definitions

    #{Enum.map(@complex_parameter_patterns, fn {name, config} ->
      "### #{name}\n**Description**: #{config.description}\n**Severity**: #{config.severity}\n**Example**: `#{config.example}`\n"
    end) |> Enum.join("\n")}
    """
  end

  def test_pattern_recognition do
    Logger.info("🧪 Testing pattern recognition capabilities...")

    test_cases = [
      %{
        name: "underscore_prefix_mismatch",
        code: "defp process_data(__context) do __context.field end",
        expected: true
      },
      %{
        name: "space_in_parameter",
        code: "stream __opts = [max_concurrency: 4]",
        expected: true
      },
      %{
        name: "normal_parameter",
        code: "defp process_data(context) do __context.field end",
        expected: false
      }
    ]

    _test_results =
      Enum.map(test_cases, fn test_case ->
        patterns = detect_regex_patterns(test_case.code, "test.ex")
        has_patterns = length(patterns) > 0

        %{
          test_case: test_case.name,
          expected: test_case.expected,
          actual: has_patterns,
          passed: test_case.expected == has_patterns,
          patterns_found: length(patterns)
        }
      end)

    passed_tests = Enum.count(test_results, & &1.passed)
    total_tests = length(test_results)

    Logger.info("🧪 Test Results: #{passed_tests}/#{total_tests} passed")

    Enum.each(test_results, fn result ->
      status = if result.passed, do: "✅", else: "❌"
      Logger.info("#{status} #{result.test_case}: Expected #{result.expected}, Got #{result.actual}")
    end)

    test_results
  end

  def analyze_specific_pattern(pattern_name) do
    Logger.info("🔍 Analyzing specific pattern: #{pattern_name}")

    case Map.get(@complex_parameter_patterns, String.to_atom(pattern_name)) do
      nil ->
        Logger.error("❌ Unknown pattern: #{pattern_name}")
        available_patterns = Map.keys(@complex_parameter_patterns)
        Logger.info("Available patterns: #{Enum.join(available_patterns, ", ")}")

      pattern_config ->
        Logger.info("📊 Pattern Analysis:")
        Logger.info("  Description: #{pattern_config.description}")
        Logger.info("  Severity: #{pattern_config.severity}")
        Logger.info("  Example: #{pattern_config.example}")

        # Test the pattern against current codebase
        Logger.info("🔍 Scanning current codebase for this pattern...")
        scan_results = scan_all_files_for_patterns()

        pattern_matches =
          scan_results.detailed_results
          |> Enum.flat_map(& &1.regex_patterns)
          |> Enum.filter(&(&1.pattern_name == String.to_atom(pattern_name)))

        Logger.info("📊 Found #{length(pattern_matches)} instances of this pattern")

        if length(pattern_matches) > 0 do
          Logger.info("🎯 Top 5 instances:")
          pattern_matches
          |> Enum.take(5)
          |> Enum.each(fn match ->
            Logger.info("  #{match.file}:#{match.line} - #{String.trim(match.__context)}")
          end)
        end

        %{
          pattern_config: pattern_config,
          instances_found: length(pattern_matches),
          matches: pattern_matches
        }
    end
  end

  defp show_help do
    IO.puts("""
    Enhanced Parameter Pattern Recognizer

    Usage:
      elixir enhanced_parameter_pattern_recognizer.exs [options]

    Options:
      --scan-all              Scan all files for parameter patterns (default)
      --scan-file <file>      Scan specific file for patterns
      --analyze-pattern <name> Analyze specific pattern type
      --generate-fixes <file> Generate automatic fixes for file
      --test-patterns         Test pattern recognition capabilities
      --help                  Show this help

    Available Patterns:
      #{Map.keys(@complex_parameter_patterns) |> Enum.join(", ")}

    Purpose:
      Enhanced pattern recognition for complex parameter scenarios
      to pr__event underscore prefix and space-in-parameter issues.

    Features:
      - Regex-based pattern detection
      - AST-based analysis (simplified)
      - Contextual pattern recognition
      - Automatic fix generation
      - Comprehensive reporting
    """)
  end
end

# Execute if run directly
if System.argv() != [] or __ENV__.file == Path.absname(:escript.script_name()) do
  EnhancedParameterPatternRecognizer.main(System.argv())
end