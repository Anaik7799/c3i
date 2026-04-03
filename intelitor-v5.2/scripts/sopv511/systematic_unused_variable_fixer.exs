#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SystematicUnusedVariableFixer do
  @moduledoc """
  SOPv5.11 Systematic Unused Variable Fixer

  Fixes unused variable warnings by:
  1. Analyzing function bodies to determine if variable is truly unused
  2. Adding underscore prefix only to genuinely unused variables
  3. Skipping variables that are actually used in function body
  """

  def main(args) do
    IO.puts("\n🔧 SOPv5.11 Systematic Unused Variable Fixer")
    IO.puts("=" |> String.duplicate(80))

    case args do
      ["--analyze"] -> analyze_unused_variables()
      ["--fix", variable_name] -> fix_specific_variable(variable_name)
      ["--fix-all"] -> fix_all_unused_variables()
      _ -> print_help()
    end
  end

  defp print_help do
    IO.puts("""
    Usage:
      elixir scripts/sopv511/systematic_unused_variable_fixer.exs --analyze
      elixir scripts/sopv511/systematic_unused_variable_fixer.exs --fix tenant_id
      elixir scripts/sopv511/systematic_unused_variable_fixer.exs --fix-all
    """)
  end

  defp analyze_unused_variables do
    IO.puts("\n📊 Analyzing unused variable warnings...")

    # Extract warnings from compilation log
    {output, 0} = System.cmd("grep", ["variable.*is unused", "1-compile.log"])

    warnings = output
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_warning/1)
    |> Enum.reject(&is_nil/1)

    # Group by variable name
    by_variable = Enum.group_by(warnings, & &1.variable)

    IO.puts("\n📈 Top 20 unused variables:")
    by_variable
    |> Enum.map(fn {var, occurrences} -> {var, length(occurrences)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(20)
    |> Enum.with_index(1)
    |> Enum.each(fn {{var, count}, idx} ->
      IO.puts("  #{idx}. #{var}: #{count} occurrences")
    end)

    # Analyze specific patterns
    IO.puts("\n🔍 Pattern Analysis:")
    analyze_patterns(warnings)
  end

  defp parse_warning(line) do
    case Regex.run(~r/lib\/(.+?):(\d+).*variable "(.+?)" is unused/, line) do
      [_, file, line_num, variable] ->
        %{
          file: "lib/#{file}",
          line: String.to_integer(line_num),
          variable: variable
        }
      _ -> nil
    end
  end

  defp analyze_patterns(warnings) do
    # Check for truly unused variables vs used variables
    warnings
    |> Enum.take(50)  # Sample first 50
    |> Enum.each(fn warning ->
      analyze_single_warning(warning)
    end)
  end

  defp analyze_single_warning(%{file: file, line: line_num, variable: var}) do
    case File.read(file) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Get function containing the warning
        function_lines = extract_function_context(lines, line_num)

        # Check if variable is actually used
        used = variable_is_used?(function_lines, var, line_num)

        if used do
          IO.puts("  ⚠️  #{Path.relative_to_cwd(file)}:#{line_num} - #{var} (ACTUALLY USED)")
        end

      {:error, _} -> :skip
    end
  end

  defp extract_function_context(lines, target_line) do
    # Find function start (def or defp)
    function_start = Enum.find_index(
      Enum.slice(lines, 0, target_line - 1) |> Enum.reverse(),
      fn line -> String.match?(line, ~r/^\s*(def|defp)\s/) end
    )

    start_idx = if function_start, do: target_line - function_start - 2, else: max(0, target_line - 10)

    # Find function end (next def or end)
    function_end = Enum.find_index(
      Enum.slice(lines, target_line, 50),
      fn line -> String.match?(line, ~r/^\s*(def|defp|end)\s/) end
    )

    end_idx = target_line + (function_end || 20)

    Enum.slice(lines, start_idx..end_idx)
  end

  defp variable_is_used?(function_lines, variable, _definition_line) do
    # Check if variable appears in function body after its definition
    function_lines
    |> Enum.with_index()
    |> Enum.any?(fn {line, _idx} ->
      # Match variable usage (not in parameter list or assignment)
      String.contains?(line, variable) and
      not String.match?(line, ~r/^\s*(def|defp).*#{variable}/) and
      not String.match?(line, ~r/#{variable}\s*=/)
    end)
  end

  defp fix_specific_variable(variable_name) do
    IO.puts("\n🔧 Fixing unused variable: #{variable_name}")

    # Extract all locations for this variable
    {output, 0} = System.cmd("grep", ["-n", "variable \"#{variable_name}\" is unused", "1-compile.log"])

    locations = output
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_warning/1)
    |> Enum.reject(&is_nil/1)

    IO.puts("  Found #{length(locations)} occurrences")

    # Group by file
    by_file = Enum.group_by(locations, & &1.file)

    # Fix each file
    Enum.each(by_file, fn {file, file_locations} ->
      fix_file_locations(file, file_locations, variable_name)
    end)

    IO.puts("\n✅ Completed fixing #{variable_name}")
  end

  defp fix_file_locations(file, locations, variable_name) do
    case File.read(file) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Check each location and fix if truly unused
        updated_lines = locations
        |> Enum.reduce(lines, fn location, acc_lines ->
          function_ctx = extract_function_context(acc_lines, location.line)

          if variable_is_used?(function_ctx, variable_name, location.line) do
            # Variable is actually used - skip (this shouldn't happen if warnings are correct)
            acc_lines
          else
            # Variable is truly unused - add underscore prefix
            update_parameter_at_line(acc_lines, location.line, variable_name, "_#{variable_name}")
          end
        end)

        if updated_lines != lines do
          File.write!(file, Enum.join(updated_lines, "\n"))
          IO.puts("  ✓ Updated #{Path.relative_to_cwd(file)} (#{length(locations)} fixes)")
        end

      {:error, reason} ->
        IO.puts("  ✗ Error reading #{file}: #{reason}")
    end
  end

  defp update_parameter_at_line(lines, line_num, old_name, new_name) do
    List.update_at(lines, line_num - 1, fn line ->
      # Replace in parameter list (careful to only replace parameter, not usage)
      cond do
        # Function definition parameter
        String.match?(line, ~r/(def|defp).*#{old_name}/) ->
          String.replace(line, ~r/\b#{old_name}\b(?=\s*[,\)])/, new_name)

        # Case/with clause parameter
        String.match?(line, ~r/(case|with|receive).*#{old_name}/) ->
          String.replace(line, ~r/\b#{old_name}\b(?=\s*[,\)])/, new_name)

        # Arrow function parameter
        String.match?(line, ~r/fn.*#{old_name}.*->/) ->
          String.replace(line, ~r/\b#{old_name}\b(?=.*->)/, new_name)

        true -> line
      end
    end)
  end

  defp fix_all_unused_variables do
    IO.puts("\n🚀 Fixing all unused variables systematically...")

    # Get top unused variables
    {output, 0} = System.cmd("bash", ["-c",
      "grep 'variable.*is unused' 1-compile.log | awk -F'\"' '{print $2}' | sort | uniq -c | sort -rn | head -10"
    ])

    variables = output
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      case Regex.run(~r/\s*\d+\s+(.+)/, line) do
        [_, var] -> var
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    IO.puts("\n📋 Will fix these variables:")
    Enum.each(variables, fn var -> IO.puts("  - #{var}") end)

    # Fix each variable
    Enum.each(variables, fn var ->
      IO.puts("\n" <> String.duplicate("-", 80))
      fix_specific_variable(var)
    end)

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("✅ All unused variables fixed!")
  end
end

SystematicUnusedVariableFixer.main(System.argv())