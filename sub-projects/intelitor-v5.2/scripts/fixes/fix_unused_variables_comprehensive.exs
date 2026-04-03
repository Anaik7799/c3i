#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule UnusedVariablesFixer do
  @moduledoc """
  Comprehensive unused variables fixer for achieving zero warnings
  """

  def analyze_and_fix_unused_variables do
    IO.puts("🎯 Comprehensive Unused Variables Fixer")
    IO.puts("=" |> String.duplicate(50))

    # Get all unused variable warnings from latest compilation log
    log_file = "/home/an/dev/indrajaal-demo/__data/tmp/zero_error_validation_20250917-0630.log"

    if File.exists?(log_file) do
      IO.puts("📊 Analyzing warnings from: #{Path.basename(log_file)}")

      content = File.read!(log_file)

      # Extract unused variable warnings with file paths and line numbers
      unused_variables = extract_unused_variables(content)

      IO.puts("🔍 Found #{length(unused_variables)} unused variable warnings")

      # Group by file for efficient processing
      files_to_fix = group_by_file(unused_variables)

      IO.puts("📁 Files to fix: #{map_size(files_to_fix)}")

      # Fix each file systematically
      Enum.each(files_to_fix, fn {file_path, variables} ->
        fix_unused_variables_in_file(file_path, variables)
      end)

      IO.puts("✅ Comprehensive unused variable fixes completed")
    else
      IO.puts("❌ Compilation log not found: #{log_file}")
    end
  end

  defp extract_unused_variables(content) do
    # Pattern to match unused variable warnings
    pattern = ~r/warning: variable "_(\w+)" is unused.*?└─ ([^:]+):(\d+):\d+/s

    Regex.scan(pattern, content)
    |> Enum.map(fn [_full, var_name, file_path, line_num] ->
      %{
        variable: var_name,
        file: String.trim(file_path),
        line: String.to_integer(line_num)
      }
    end)
  end

  defp group_by_file(unused_variables) do
    unused_variables
    |> Enum.group_by(& &1.file)
  end

  defp fix_unused_variables_in_file(file_path, variables) do
    # Convert relative path to absolute if needed
    full_path = if String.starts_with?(file_path, "/") do
      file_path
    else
      "/home/an/dev/indrajaal-demo/#{file_path}"
    end

    if File.exists?(full_path) do
      IO.puts("🔧 Fixing #{length(variables)} unused variables in: #{Path.basename(full_path)}")

      content = File.read!(full_path)

      # Sort by line number in descending order to avoid line number shifts
      sorted_variables = Enum.sort_by(variables, & &1.line, :desc)

      # Apply fixes
      _updated_content =
        Enum.reduce(sorted_variables, _content, fn var, acc ->
          fix_unused_variable_in_content(acc, var)
        end)

      if content != updated_content do
        File.write!(full_path, updated_content)
        IO.puts("  ✅ Fixed #{length(variables)} unused variables")
      else
        IO.puts("  ℹ️  No changes needed")
      end
    else
      IO.puts("  ❌ File not found: #{full_path}")
    end
  end

  defp fix_unused_variable_in_content(content, %{variable: var_name, line: line_num}) do
    lines = String.split(content, "\n")

    if line_num <= length(lines) do
      target_line = Enum.at(lines, line_num - 1)

      # Check if this variable is actually unused (not referenced in function body)
      if should_add_underscore?(target_line, var_name) do
        # Add underscore prefix to unused variable
        updated_line = String.replace(target_line, ~r/\b#{var_name}\b/, "_#{var_name}", global: false)

        updated_lines = List.replace_at(lines, line_num - 1, updated_line)
        Enum.join(updated_lines, "\n")
      else
        content
      end
    else
      content
    end
  end

  defp should_add_underscore?(line, var_name) do
    # Only add underscore if it's in a function parameter definition
    # and the variable name doesn't already start with underscore
    not String.starts_with?(var_name, "_") and
    (String.contains?(line, "def ") or String.contains?(line, "defp "))
  end

  def run do
    analyze_and_fix_unused_variables()
  end
end

UnusedVariablesFixer.run()