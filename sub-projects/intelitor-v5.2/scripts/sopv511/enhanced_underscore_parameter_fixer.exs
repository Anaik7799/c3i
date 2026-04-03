#!/usr/bin/env elixir

defmodule EnhancedUnderscoreParameterFixer do
  @moduledoc """
  SOPv5.11 Enhanced Underscore Parameter Fixer

  Systematically fixes underscore parameter misuse with:
  - Priority-based fixing (files with most errors first)
  - Double-underscore pattern handling (__variable)
  - State variable error prioritization (_state → state)
  - Comprehensive pattern matching

  Prevents EP-001 (Undefined Variable) compilation errors.
  """

  def main(args \\ []) do
    case args do
      ["--scan"] -> scan_all_files()
      ["--fix"] -> fix_all_files()
      ["--fix-priority"] -> fix_priority_files()
      ["--analyze", file] -> analyze_specific_file(file)
      _ -> show_help()
    end
  end

  defp scan_all_files do
    IO.puts("🔍 Scanning all Elixir files for underscore parameter issues...")

    files = get_all_elixir_files()

    file_issues = Enum.map(files, fn file ->
      issues = scan_file(file)
      {file, issues}
    end)
    |> Enum.filter(fn {_file, issues} -> length(issues) > 0 end)
    |> Enum.sort_by(fn {_file, issues} -> -length(issues) end)  # Sort by issue count

    total_issues = Enum.reduce(file_issues, 0, fn {_file, issues}, acc ->
      acc + length(issues)
    end)

    IO.puts("\n📊 Found #{total_issues} issues in #{length(file_issues)} files\n")

    Enum.each(file_issues, fn {file, issues} ->
      IO.puts("⚠️  #{file}: #{length(issues)} issues")

      # Group issues by type
      state_issues = Enum.filter(issues, &(&1.parameter =~ ~r/state|ctx|context/))
      double_underscore = Enum.filter(issues, &(&1.parameter =~ ~r/^_/))

      if length(state_issues) > 0 do
        IO.puts("    🔴 #{length(state_issues)} state/context parameter issues (HIGH PRIORITY)")
      end

      if length(double_underscore) > 0 do
        IO.puts("    🟡 #{length(double_underscore)} double-underscore issues")
      end
    end)
  end

  defp fix_priority_files do
    IO.puts("🔧 Fixing files with priority (most errors first)...")

    files = get_all_elixir_files()

    file_issues = Enum.map(files, fn file ->
      issues = scan_file(file)
      {file, issues}
    end)
    |> Enum.filter(fn {_file, issues} -> length(issues) > 0 end)
    |> Enum.sort_by(fn {_file, issues} -> -length(issues) end)

    fixed_count = 0

    Enum.each(file_issues, fn {file, issues} ->
      IO.puts("\n🔧 Fixing #{file} (#{length(issues)} issues)...")

      if fix_file(file) do
        fixed_count = fixed_count + 1
        IO.puts("✅ Fixed: #{file}")
      else
        IO.puts("⚠️  No changes needed: #{file}")
      end
    end)

    IO.puts("\n🎯 Fixed #{fixed_count} files")
  end

  defp fix_all_files do
    IO.puts("🔧 Fixing all underscore parameter issues...")

    files = get_all_elixir_files()
    fixed_count = 0

    Enum.each(files, fn file ->
      if fix_file(file) do
        fixed_count = fixed_count + 1
        IO.puts("✅ Fixed: #{file}")
      end
    end)

    IO.puts("🎯 Fixed #{fixed_count} files")
  end

  defp get_all_elixir_files do
    Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")
  end

  defp scan_file(file_path) do
    content = File.read!(file_path)
    lines = String.split(content, "\n")

    issues = []

    # Find function definitions with underscore parameters
    Enum.with_index(lines, 1)
    |> Enum.reduce(issues, fn {line, line_number}, acc ->
      # Pattern 1: Single underscore (_state, _attrs, etc.)
      case Regex.run(~r/def[p]?\s+(\w+)\s*\([^)]*_(\w+)[^)]*\)\s*do/, line) do
        [_, function_name, parameter_name] ->
          if parameter_used_in_function?(lines, line_number, parameter_name) do
            issue = %{
              line: line_number,
              function: function_name,
              parameter: parameter_name,
              pattern: :single_underscore,
              full_line: line
            }
            [issue | acc]
          else
            acc
          end
        nil ->
          # Pattern 2: Double underscore (__event_data, __params, etc.)
          case Regex.run(~r/def[p]?\s+(\w+)\s*\([^)]*__(\w+)[^)]*\)\s*do/, line) do
            [_, function_name, parameter_name] ->
              if parameter_used_in_function?(lines, line_number, parameter_name, true) do
                issue = %{
                  line: line_number,
                  function: function_name,
                  parameter: parameter_name,
                  pattern: :double_underscore,
                  full_line: line
                }
                [issue | acc]
              else
                acc
              end
            nil ->
              acc
          end
      end
    end)
  end

  defp parameter_used_in_function?(lines, start_line, parameter_name, double_underscore \\ false) do
    function_lines = extract_function_body(lines, start_line)

    prefix = if double_underscore, do: "__", else: "_"

    Enum.any?(function_lines, fn line ->
      # Check if parameter is used without underscore prefix
      if double_underscore do
        # For __variable, check if variable is used alone
        String.contains?(line, parameter_name) and
        not String.contains?(line, "__#{parameter_name}") and
        not String.contains?(line, "def")
      else
        # For _variable, check if variable is used alone
        String.contains?(line, parameter_name) and
        not String.contains?(line, "_#{parameter_name}") and
        not String.contains?(line, "def")
      end
    end)
  end

  defp extract_function_body(lines, start_line) do
    lines
    |> Enum.drop(start_line)
    |> Enum.take_while(fn line ->
      not (String.match?(line, ~r/^\s*def[p]?\s/) or
           String.match?(line, ~r/^\s*end\s*$/))
    end)
    |> Enum.take(50)
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
    content
    # Fix single underscore patterns
    |> fix_single_underscore()
    # Fix double underscore patterns
    |> fix_double_underscore()
  end

  defp fix_single_underscore(content) do
    # Pattern: def func(_param) where param is used
    Regex.replace(
      ~r/(def[p]?\s+\w+\s*\([^)]*?)_(\w+)([^)]*\)\s*do)/,
      content,
      fn full_match, before, param, suffix ->
        function_body = extract_function_body_string(content, full_match)

        if String.contains?(function_body, param) and
           not String.contains?(function_body, "_#{param}") do
          "#{before}#{param}#{suffix}"
        else
          full_match
        end
      end
    )
  end

  defp fix_double_underscore(content) do
    # Pattern: def func(__param) where param is used
    Regex.replace(
      ~r/(def[p]?\s+\w+\s*\([^)]*?)__(\w+)([^)]*\)\s*do)/,
      content,
      fn full_match, before, param, suffix ->
        function_body = extract_function_body_string(content, full_match)

        if String.contains?(function_body, param) and
           not String.contains?(function_body, "__#{param}") do
          "#{before}#{param}#{suffix}"
        else
          full_match
        end
      end
    )
  end

  defp extract_function_body_string(content, function_def) do
    case String.split(content, function_def, parts: 2) do
      [_, rest] ->
        rest
        |> String.split("\n")
        |> Enum.take(50)
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

      # Group by pattern type
      single = Enum.filter(issues, &(&1.pattern == :single_underscore))
      double = Enum.filter(issues, &(&1.pattern == :double_underscore))

      if length(single) > 0 do
        IO.puts("\n  Single underscore issues (#{length(single)}):")
        Enum.each(single, fn issue ->
          IO.puts("    Line #{issue.line}: #{issue.function} - '_#{issue.parameter}' is used")
          IO.puts("      #{String.trim(issue.full_line)}")
        end)
      end

      if length(double) > 0 do
        IO.puts("\n  Double underscore issues (#{length(double)}):")
        Enum.each(double, fn issue ->
          IO.puts("    Line #{issue.line}: #{issue.function} - '__#{issue.parameter}' is used")
          IO.puts("      #{String.trim(issue.full_line)}")
        end)
      end
    else
      IO.puts("✅ No issues found")
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Enhanced Underscore Parameter Fixer

    Usage:
      elixir enhanced_underscore_parameter_fixer.exs [command]

    Commands:
      --scan                  Scan all files for issues (with priority analysis)
      --fix                   Fix all detected issues
      --fix-priority          Fix files in priority order (most errors first)
      --analyze <file>        Analyze specific file

    This tool fixes EP-001 (Undefined Variable) errors caused by:
    - Single underscore parameter misuse (_state → state)
    - Double underscore parameter misuse (__params → params)

    Priority is given to:
    - Files with most errors
    - State/context variable errors (critical for GenServer patterns)
    """)
  end
end

EnhancedUnderscoreParameterFixer.main(System.argv())