#!/usr/bin/env elixir

defmodule TargetedUnusedVariableFixer do
  @moduledoc """
  Targeted fixer for unused variable warnings.
  Extracts file locations from compilation log and adds underscore prefixes.
  """

  def main(args) do
    IO.puts("\n🔧 Targeted Unused Variable Fixer")
    IO.puts("=" |> String.duplicate(80))

    case args do
      ["--fix", variable_name] -> fix_variable(variable_name)
      ["--fix-tenant-id"] -> fix_variable("tenant_id")
      ["--fix-state"] -> fix_variable("state")
      ["--fix-opts"] -> fix_variable("opts")
      _ -> print_help()
    end
  end

  defp print_help do
    IO.puts("""
    Usage:
      elixir scripts/sopv511/targeted_unused_variable_fixer.exs --fix VARIABLE_NAME
      elixir scripts/sopv511/targeted_unused_variable_fixer.exs --fix-tenant-id
      elixir scripts/sopv511/targeted_unused_variable_fixer.exs --fix-state
      elixir scripts/sopv511/targeted_unused_variable_fixer.exs --fix-opts
    """)
  end

  defp fix_variable(variable_name) do
    IO.puts("\n🎯 Fixing unused variable: #{variable_name}")

    # Extract warnings from log
    warnings = extract_warnings(variable_name)

    IO.puts("  Found #{length(warnings)} occurrences")

    # Group by file
    by_file = Enum.group_by(warnings, & &1.file)

    IO.puts("  Affecting #{map_size(by_file)} files")

    # Fix each file
    fixed_count = Enum.reduce(by_file, 0, fn {file, file_warnings}, acc ->
      case fix_file(file, file_warnings, variable_name) do
        :ok -> acc + length(file_warnings)
        :error -> acc
      end
    end)

    IO.puts("\n✅ Fixed #{fixed_count} occurrences in #{map_size(by_file)} files")
  end

  defp extract_warnings(variable_name) do
    # Read compilation log
    {:ok, content} = File.read("1-compile.log")

    lines = String.split(content, "\n")

    # Find all warnings for this variable
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} ->
      String.contains?(line, "variable \"#{variable_name}\" is unused")
    end)
    |> Enum.map(fn {_, idx} ->
      # Get context lines (warning + location info)
      context = Enum.slice(lines, idx, 6)
      parse_warning_context(context)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_warning_context(context_lines) do
    # Extract file and line number from context
    # Format: lib/path/to/file.ex:LINE:COL: Module.function/arity
    location_line = Enum.find(context_lines, fn line ->
      String.contains?(line, "└─ lib/")
    end)

    line_num_line = Enum.find(context_lines, fn line ->
      String.match?(line, ~r/^\s*\d+\s*│/)
    end)

    cond do
      is_nil(location_line) or is_nil(line_num_line) ->
        nil

      true ->
        file = extract_file(location_line)
        line_num = extract_line_number(line_num_line)

        if file && line_num do
          %{file: file, line: line_num}
        else
          nil
        end
    end
  end

  defp extract_file(line) do
    case Regex.run(~r/└─ (lib\/[^:]+\.ex)/, line) do
      [_, file] -> file
      _ -> nil
    end
  end

  defp extract_line_number(line) do
    case Regex.run(~r/^\s*(\d+)\s*│/, line) do
      [_, num] -> String.to_integer(num)
      _ -> nil
    end
  end

  defp fix_file(file_path, warnings, variable_name) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Update lines with underscore prefix
        updated_lines = Enum.reduce(warnings, lines, fn %{line: line_num}, acc ->
          update_line_at(acc, line_num, variable_name)
        end)

        if updated_lines != lines do
          File.write!(file_path, Enum.join(updated_lines, "\n"))
          IO.puts("  ✓ #{file_path} (#{length(warnings)} fixes)")
          :ok
        else
          IO.puts("  - #{file_path} (no changes needed)")
          :ok
        end

      {:error, reason} ->
        IO.puts("  ✗ Error reading #{file_path}: #{reason}")
        :error
    end
  end

  defp update_line_at(lines, line_num, variable_name) do
    List.update_at(lines, line_num - 1, fn line ->
      # Replace variable in function parameter list
      cond do
        # Function definition: defp func(tenant_id, ...) -> defp func(_tenant_id, ...)
        String.match?(line, ~r/(defp?|def)\s+\w+\([^)]*\b#{variable_name}\b/) ->
          String.replace(line, ~r/\b#{variable_name}\b/, "_#{variable_name}", global: false)

        # Pattern matching: {tenant_id, data} -> {_tenant_id, data}
        String.match?(line, ~r/[{(]\s*#{variable_name}\s*[,})]/) ->
          String.replace(line, ~r/\b#{variable_name}\b/, "_#{variable_name}", global: false)

        true -> line
      end
    end)
  end
end

TargetedUnusedVariableFixer.main(System.argv())