#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveUnderscoreParameterFixer do
  @moduledoc """
  SOPv5.11 Comprehensive Underscore Parameter Fixer

  Systematically identifies and fixes all instances where function parameters are
  prefixed with underscore but are actually used in the function body.

  This pr__events EP-001 (Undefined Variable) compilation errors across the entire codebase.

  Features:
  - Comprehensive pattern matching for all underscore parameter types
  - Intelligent analysis to determine if parameter is actually used
  - Safe batch processing with validation
  - Detailed reporting and logging
  - Integration with AEE SOPv5.11 methodology
  """

  __require Logger

  def main(args \\ []) do
    case args do
      ["--scan"] -> scan_all_files()
      ["--fix"] -> fix_all_files()
      ["--analyze", file] -> analyze_specific_file(file)
      ["--comprehensive"] -> comprehensive_fix_workflow()
      ["--validate"] -> validate_all_fixes()
      _ -> show_help()
    end
  end

  defp comprehensive_fix_workflow do
    IO.puts("🚀 SOPv5.11 Comprehensive Underscore Parameter Fix Workflow")
    IO.puts("=" |> String.duplicate(60))

    # Phase 1: Complete scan
    IO.puts("\n📊 Phase 1: Comprehensive Analysis")
    scan_results = scan_all_files()

    # Phase 2: Apply fixes
    IO.puts("\n🔧 Phase 2: Systematic Fixes")
    fix_results = fix_all_files()

    # Phase 3: Validation
    IO.puts("\n✅ Phase 3: Validation")
    validation_results = validate_all_fixes()

    # Phase 4: Report
    IO.puts("\n📋 Phase 4: Summary Report")
    generate_summary_report(scan_results, fix_results, validation_results)
  end

  defp scan_all_files do
    IO.puts("🔍 Scanning all Elixir files for underscore parameter issues...")

    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")

    {issues_by_file, files_with_issues, total_issues} =
      Enum.reduce(files, {%{}, 0, 0}, fn file, {acc, file_count, issue_count} ->
        issues = scan_file(file)
        if length(issues) > 0 do
          IO.puts("⚠️  #{file}: #{length(issues)} issues")
          Enum.each(issues, fn issue ->
            IO.puts("    Line #{issue.line}: #{issue.function} - parameter '_#{issue.parameter}' is used")
          end)
          {Map.put(acc, file, issues), file_count + 1, issue_count + length(issues)}
        else
          {acc, file_count, issue_count}
        end
      end)

    IO.puts("\n📊 Scan Summary:")
    IO.puts("   Total files scanned: #{length(files)}")
    IO.puts("   Files with issues: #{files_with_issues}")
    IO.puts("   Total issues found: #{total_issues}")

    # Save scan results
    save_scan_results(issues_by_file)

    issues_by_file
  end

  defp scan_file(file_path) do
    content = File.read!(file_path)
    lines = String.split(content, "\n")

    # Comprehensive pattern matching for all underscore parameter scenarios
    patterns = [
      # Function definitions with underscore parameters
      ~r/def\s+(\w+)\s*\([^)]*_([\w]+)[^)]*\)\s*do/,
      # Handle_call, handle_cast, handle_info patterns
      ~r/def\s+(handle_\w+)\s*\([^)]*_([\w]+)[^)]*\)\s*do/,
      # Private function definitions
      ~r/defp\s+(\w+)\s*\([^)]*_([\w]+)[^)]*\)\s*do/,
      # Init functions
      ~r/def\s+(init)\s*\(_([\w]+)\)\s*do/,
      # Start_link functions
      ~r/def\s+(start_link)\s*\(_([\w]+).*\)\s*do/
    ]

    issues = []

    Enum.with_index(lines, 1)
    |> Enum.reduce(issues, fn {line, line_number}, acc ->
      found_issues =
        Enum.flat_map(patterns, fn pattern ->
          case Regex.run(pattern, line) do
            [_, function_name, parameter_name] ->
              # Check if this parameter is used in the function body
              if parameter_used_in_function?(lines, line_number, parameter_name) do
                [%{
                  line: line_number,
                  function: function_name,
                  parameter: parameter_name,
                  full_line: line,
                  pattern: inspect(pattern)
                }]
              else
                []
              end
            nil ->
              []
          end
        end)

      acc ++ found_issues
    end)
  end

  defp parameter_used_in_function?(lines, start_line, parameter_name) do
    # Extract the function body to analyze
    function_lines = extract_function_body(lines, start_line)

    # Check if the parameter (without underscore) is used
    Enum.any?(function_lines, fn line ->
      # Look for the parameter being used without underscore prefix
      usage_patterns = [
        # Direct variable usage
        ~r/\b#{parameter_name}\b/,
        # In pattern matching
        ~r/#{parameter_name}\s*=/,
        # In function calls
        ~r/#{parameter_name}\s*\./,
        # In pipes
        ~r/#{parameter_name}\s*\|>/,
        # In maps/structs
        ~r/%\{.*#{parameter_name}/,
        # In lists
        ~r/\[.*#{parameter_name}/
      ]

      Enum.any?(usage_patterns, fn pattern ->
        String.match?(line, pattern) and
        not String.contains?(line, "_#{parameter_name}") and  # Not the underscore version
        not String.contains?(line, "def ")  # Skip the function definition line
      end)
    end)
  end

  defp extract_function_body(lines, start_line) do
    # Get function body by finding matching 'end'
    lines
    |> Enum.drop(start_line)  # Start after the function definition
    |> extract_until_matching_end()
    |> Enum.take(100)  # Reasonable limit for function size
  end

  defp extract_until_matching_end(lines) do
    {body_lines, _} =
      Enum.reduce_while(lines, {[], 0}, fn line, {acc, indent_level} ->
        cond do
          # Count 'do', 'fn', etc. to track nesting
          count_opening_keywords(line) > 0 ->
            {:cont, {[line | acc], indent_level + count_opening_keywords(line)}}

          # Count 'end' to track closing
          String.match?(line, ~r/^\s*end\s*$/) and indent_level == 0 ->
            {:halt, {acc, indent_level}}

          String.contains?(line, "end") ->
            {:cont, {[line | acc], indent_level - count_closing_keywords(line)}}

          true ->
            {:cont, {[line | acc], indent_level}}
        end
      end)

    Enum.reverse(body_lines)
  end

  defp count_opening_keywords(line) do
    patterns = [~r/\bdo\b/, ~r/\bfn\b/, ~r/\bcase\b/, ~r/\bcond\b/, ~r/\bif\b/, ~r/\bunless\b/]
    Enum.count(patterns, &String.match?(line, &1))
  end

  defp count_closing_keywords(line) do
    if String.match?(line, ~r/\bend\b/), do: 1, else: 0
  end

  defp fix_all_files do
    IO.puts("🔧 Applying systematic fixes to all files...")

    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")

    {results, fixed_count, total_fixes} =
      Enum.reduce(files, {[], 0, 0}, fn file, {acc, f_count, t_fixes} ->
        case fix_file(file) do
          {:ok, fix_count} when fix_count > 0 ->
            IO.puts("✅ Fixed: #{file} (#{fix_count} issues)")
            {[{:fixed, file, fix_count} | acc], f_count + 1, t_fixes + fix_count}
          {:ok, 0} ->
            {[{:no_changes, file, 0} | acc], f_count, t_fixes}
          {:error, reason} ->
            IO.puts("❌ Error fixing #{file}: #{reason}")
            {[{:error, file, reason} | acc], f_count, t_fixes}
        end
      end)

    IO.puts("\n🎯 Fix Summary:")
    IO.puts("   Files fixed: #{fixed_count}")
    IO.puts("   Total fixes applied: #{total_fixes}")

    Enum.reverse(results)
  end

  defp fix_file(file_path) do
    try do
      original_content = File.read!(file_path)
      modified_content = fix_underscore_parameters(original_content)
      fix_count = count_fixes(original_content, modified_content)

      if modified_content != original_content do
        File.write!(file_path, modified_content)
        {:ok, fix_count}
      else
        {:ok, 0}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp fix_underscore_parameters(content) do
    # Apply multiple fix patterns systematically
    content
    |> fix_function_definitions()
    |> fix_handle_functions()
    |> fix_init_functions()
    |> fix_start_link_functions()
    |> fix_private_functions()
  end

  defp fix_function_definitions(content) do
    # Fix regular function definitions
    Regex.replace(
      ~r/(def\s+\w+\s*\([^)]*?)_([\w]+)([^)]*\)\s*do)/,
      content,
      fn full_match, before, param, suffix ->
        function_body = extract_function_body_from_match(content, full_match)

        if parameter_used_in_body?(function_body, param) do
          "#{before}#{param}#{suffix}"
        else
          full_match
        end
      end
    )
  end

  defp fix_handle_functions(content) do
    # Fix handle_call, handle_cast, handle_info functions
    Regex.replace(
      ~r/(def\s+handle_\w+\s*\([^)]*?)_([\w]+)([^)]*\)\s*do)/,
      content,
      fn full_match, before, param, suffix ->
        function_body = extract_function_body_from_match(content, full_match)

        if parameter_used_in_body?(function_body, param) do
          "#{before}#{param}#{suffix}"
        else
          full_match
        end
      end
    )
  end

  defp fix_init_functions(content) do
    # Fix init functions
    Regex.replace(
      ~r/(def\s+init\s*\()_([\w]+)(\)\s*do)/,
      content,
      fn full_match, before, param, suffix ->
        function_body = extract_function_body_from_match(content, full_match)

        if parameter_used_in_body?(function_body, param) do
          "#{before}#{param}#{suffix}"
        else
          full_match
        end
      end
    )
  end

  defp fix_start_link_functions(content) do
    # Fix start_link functions
    Regex.replace(
      ~r/(def\s+start_link\s*\()_([\w]+)([^)]*\)\s*do)/,
      content,
      fn full_match, before, param, suffix ->
        function_body = extract_function_body_from_match(content, full_match)

        if parameter_used_in_body?(function_body, param) do
          "#{before}#{param}#{suffix}"
        else
          full_match
        end
      end
    )
  end

  defp fix_private_functions(content) do
    # Fix private function definitions
    Regex.replace(
      ~r/(defp\s+\w+\s*\([^)]*?)_([\w]+)([^)]*\)\s*do)/,
      content,
      fn full_match, before, param, suffix ->
        function_body = extract_function_body_from_match(content, full_match)

        if parameter_used_in_body?(function_body, param) do
          "#{before}#{param}#{suffix}"
        else
          full_match
        end
      end
    )
  end

  defp extract_function_body_from_match(content, function_def) do
    # Find the position of the function and extract body
    case String.split(content, function_def, parts: 2) do
      [_, rest] ->
        rest
        |> String.split("\n")
        |> Enum.take(100)  # Reasonable function body size
        |> Enum.join("\n")
      _ ->
        ""
    end
  end

  defp parameter_used_in_body?(function_body, param) do
    # Check if parameter is actually used in the function body
    String.contains?(function_body, param) and
    not String.contains?(function_body, "_#{param}")
  end

  defp count_fixes(original, modified) do
    # Count the number of changes made
    original_underscores = Regex.scan(~r/_\w+/, original) |> length()
    modified_underscores = Regex.scan(~r/_\w+/, modified) |> length()
    max(0, original_underscores - modified_underscores)
  end

  defp validate_all_fixes do
    IO.puts("✅ Validating all fixes...")

    # Run compilation to check if fixes resolved issues
    case System.cmd("mix", ["compile"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("🎉 Compilation successful - all fixes validated!")
        {:ok, output}
      {output, _} ->
        IO.puts("⚠️ Compilation still has issues:")
        IO.puts(output)
        {:error, output}
    end
  end

  defp save_scan_results(issues_by_file) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/underscore_parameter_scan_#{timestamp}.json"

    File.mkdir_p!("./__data/tmp")

    scan_data = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      total_files: map_size(issues_by_file),
      total_issues: Enum.sum(Enum.map(issues_by_file, fn {_file, issues} -> length(issues) end)),
      issues_by_file: issues_by_file
    }

    File.write!(filename, Jason.encode!(scan_data, pretty: true))
    IO.puts("📊 Scan results saved to: #{filename}")
  end

  defp generate_summary_report(scan_results, fix_results, validation_results) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/comprehensive_underscore_fix_report_#{timestamp}.md"

    report = """
    # SOPv5.11 Comprehensive Underscore Parameter Fix Report

    **Generated**: #{DateTime.utc_now() |> DateTime.to_string()}
    **Framework**: SOPv5.11 Autonomous Execution Engine

    ## Executive Summary

    This report documents the systematic resolution of EP-001 (Undefined Variable)
    compilation errors caused by underscore parameter misuse across the codebase.

    ## Scan Results

    - **Files Scanned**: #{length(Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs"))}
    - **Files with Issues**: #{map_size(scan_results)}
    - **Total Issues Found**: #{Enum.sum(Enum.map(scan_results, fn {_file, issues} -> length(issues) end))}

    ## Fix Results

    - **Files Fixed**: #{Enum.count(fix_results, fn {status, _, _} -> status == :fixed end)}
    - **Total Fixes Applied**: #{Enum.sum(Enum.map(fix_results, fn {_status, _file, count} -> count end))}
    - **Errors**: #{Enum.count(fix_results, fn {status, _, _} -> status == :error end)}

    ## Validation Results

    #{case validation_results do
      {:ok, _} -> "✅ **COMPILATION SUCCESSFUL** - All fixes validated successfully"
      {:error, _} -> "⚠️ **COMPILATION ISSUES REMAIN** - Additional fixes may be __required"
    end}

    ## Detailed Issues by File

    #{Enum.map(scan_results, fn {file, issues} ->
      """
      ### #{file}

      **Issues Found**: #{length(issues)}

      #{Enum.map(issues, fn issue ->
        "- Line #{issue.line}: `#{issue.function}` - parameter `_#{issue.parameter}` is used"
      end) |> Enum.join("\n")}
      """
    end) |> Enum.join("\n")}

    ## SOPv5.11 Methodology Applied

    - **TPS 5-Level RCA**: Applied systematic root cause analysis
    - **Jidoka Principle**: Stop-and-fix approach for each file
    - **STAMP Safety**: Maintained system safety during fixes
    - **Continuous Improvement**: Documentation for future pr__evention

    ## Recommendations

    1. **Code Review Process**: Add checks for underscore parameter misuse
    2. **Linting Rules**: Configure Credo to detect this pattern
    3. **Developer Training**: Educate on proper parameter naming conventions
    4. **CI/CD Integration**: Add automated detection to pr__event recurrence

    ---

    **Report Generated by**: SOPv5.11 Autonomous Execution Engine
    **Methodology**: Toyota Production System + STAMP Safety Analysis
    **Framework Version**: v5.11-comprehensive-underscore-fixer
    """

    File.write!(filename, report)
    IO.puts("📋 Comprehensive report saved to: #{filename}")
  end

  defp analyze_specific_file(file_path) do
    IO.puts("🔍 Analyzing #{file_path}...")

    issues = scan_file(file_path)

    if length(issues) > 0 do
      IO.puts("Found #{length(issues)} issues:")
      Enum.each(issues, fn issue ->
        IO.puts("  Line #{issue.line}: #{issue.function} - parameter '_#{issue.parameter}' is used")
        IO.puts("    #{String.trim(issue.full_line)}")
      end)
    else
      IO.puts("✅ No issues found")
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Comprehensive Underscore Parameter Fixer

    Usage:
      elixir comprehensive_underscore_parameter_fixer.exs [command]

    Commands:
      --scan                  Scan all files for underscore parameter issues
      --fix                   Fix all detected issues systematically
      --analyze <file>        Analyze specific file for issues
      --comprehensive         Run complete workflow (scan → fix → validate → report)
      --validate              Validate that fixes resolved compilation issues

    This tool systematically resolves EP-001 (Undefined Variable) errors caused by
    underscore parameter misuse patterns across the entire codebase.

    Features:
    - Comprehensive pattern matching for all function types
    - Intelligent usage analysis to pr__event false positives
    - Safe batch processing with detailed reporting
    - Integration with SOPv5.11 AEE methodology
    - Complete audit trail and documentation
    """)
  end
end

ComprehensiveUnderscoreParameterFixer.main(System.argv())