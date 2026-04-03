#!/usr/bin/env elixir

defmodule SystematicUnderscoreParameterFixer do
  @moduledoc """
  SOPv5.11 Systematic Underscore Parameter Fixer

  Identifies and fixes all instances where function parameters are prefixed
  with underscore but are actually used in the function body.

  This pr__events EP-001 (Undefined Variable) compilation errors.
  """

  def main(args \\ []) do
    case args do
      ["--scan"] -> scan_all_files()
      ["--fix"] -> fix_all_files()
      ["--analyze", file] -> analyze_specific_file(file)
      _ -> show_help()
    end
  end

  defp scan_all_files do
    IO.puts("🔍 Scanning all Elixir files for underscore parameter issues...")

    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")

    issues_found = []

    Enum.each(files, fn file ->
      issues = scan_file(file)
      if length(issues) > 0 do
        IO.puts("⚠️  #{file}: #{length(issues)} issues")
        Enum.each(issues, fn issue ->
          IO.puts("    Line #{issue.line}: #{issue.function} - parameter '#{issue.parameter}'")
        end)
      end
    end)
  end

  defp fix_all_files do
    IO.puts("🔧 Fixing all underscore parameter issues...")

    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")
    fixed_count = 0

    Enum.each(files, fn file ->
      if fix_file(file) do
        fixed_count = fixed_count + 1
        IO.puts("✅ Fixed: #{file}")
      end
    end)

    IO.puts("🎯 Fixed #{fixed_count} files")
  end

  defp scan_file(file_path) do
    content = File.read!(file_path)
    lines = String.split(content, "\n")

    issues = []

    # Find function definitions with underscore parameters
    Enum.with_index(lines, 1)
    |> Enum.reduce(issues, fn {line, line_number}, acc ->
      case Regex.run(~r/def\s+(\w+)\s*\([^)]*_(\w+)[^)]*\)\s*do/, line) do
        [_, function_name, parameter_name] ->
          # Check if this parameter is used in the function body
          if parameter_used_in_function?(lines, line_number, parameter_name) do
            issue = %{
              line: line_number,
              function: function_name,
              parameter: parameter_name,
              full_line: line
            }
            [issue | acc]
          else
            acc
          end
        nil ->
          acc
      end
    end)
  end

  defp parameter_used_in_function?(lines, start_line, parameter_name) do
    # Look for the end of the function (next "def" or "end" at same indentation level)
    function_lines = extract_function_body(lines, start_line)

    Enum.any?(function_lines, fn line ->
      # Check if parameter is used without underscore prefix
      String.contains?(line, parameter_name) and
      not String.contains?(line, "_#{parameter_name}") and
      not String.contains?(line, "def")  # Skip the function definition line
    end)
  end

  defp extract_function_body(lines, start_line) do
    # Simple heuristic: take lines until next function or significant dedent
    lines
    |> Enum.drop(start_line)  # Start after the function definition
    |> Enum.take_while(fn line ->
      not (String.match?(line, ~r/^\s*def\s/) or
           String.match?(line, ~r/^\s*end\s*$/))
    end)
    |> Enum.take(50)  # Limit to reasonable function size
  end

  defp fix_file(file_path) do
    original_content = File.read!(file_path)
    modified_content = fix_underscore_parameters(original_content)

    if modified_content != original_content do
      File.write!(file_path, modified_content)
      true
    else
      false
    end
  end

  defp fix_underscore_parameters(content) do
    # Fix patterns like: def func(_param) do ... when param is used
    content
    |> fix_pattern(~r/(def\s+\w+\s*\([^)]*?)_(\w+)([^)]*\)\s*do)/, fn full_match, before, param, suffix ->
      function_body = extract_function_body_string(content, full_match)

      if String.contains?(function_body, param) and
         not String.contains?(function_body, "_#{param}") do
        "#{before}#{param}#{suffix}"
      else
        full_match
      end
    end)
  end

  defp fix_pattern(content, regex, replacer_fn) do
    Regex.replace(regex, content, fn full_match, before, param, suffix ->
      replacer_fn.(full_match, before, param, suffix)
    end)
  end

  defp extract_function_body_string(content, function_def) do
    # Find position of function definition and extract reasonable body
    case String.split(content, function_def, parts: 2) do
      [_, rest] ->
        rest
        |> String.split("\n")
        |> Enum.take(50)  # Take reasonable function body size
        |> Enum.join("\n")
      _ ->
        ""
    end
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
    SOPv5.11 Systematic Underscore Parameter Fixer

    Usage:
      elixir systematic_underscore_parameter_fixer.exs [command]

    Commands:
      --scan                  Scan all files for issues
      --fix                   Fix all detected issues
      --analyze <file>        Analyze specific file

    This tool fixes EP-001 (Undefined Variable) errors caused by
    parameter underscore misuse patterns.
    """)
  end
end

SystematicUnderscoreParameterFixer.main(System.argv())