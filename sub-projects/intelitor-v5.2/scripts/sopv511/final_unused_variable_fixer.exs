#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FinalUnusedVariableFixer do
  @moduledoc """
  SOPv5.11 Final Unused Variable Fixer - Fix all remaining unused variable warnings
  """

  def main(_args) do
    IO.puts("🚀 SOPv5.11 FINAL UNUSED VARIABLE FIXER STARTING")
    IO.puts("🎯 TARGET: Fix all remaining 68 unused variable warnings")

    # Read the compilation log to get current warnings
    compilation_log = read_compilation_log()

    # Extract unused variable warnings
    unused_vars = extract_unused_variable_warnings(compilation_log)

    IO.puts("📊 Found #{length(unused_vars)} unused variable warnings")

    # Group by file
    warnings_by_file = Enum.group_by(unused_vars, & &1.file)

    IO.puts("📁 Files to fix: #{map_size(warnings_by_file)}")

    # Fix each file
    total_fixed =
      for {file, warnings} <- warnings_by_file, reduce: 0 do
        acc ->
          IO.puts("🔧 Fixing #{length(warnings)} warnings in #{Path.basename(file)}")
          fixed = fix_file_warnings(file, warnings)
          acc + fixed
      end

    IO.puts("✅ FINAL UNUSED VARIABLE FIXING COMPLETE")
    IO.puts("📊 Total fixes applied: #{total_fixed}")

    # Run validation compilation
    run_validation_compile()
  end

  defp read_compilation_log do
    case File.read("3-compile.log") do
      {:ok, content} -> content
      {:error, _} ->
        case File.read("2-compile.log") do
          {:ok, content} -> content
          {:error, _} -> ""
        end
    end
  end

  defp extract_unused_variable_warnings(log_content) do
    # Look for lines like: warning: variable "_opts" is unused
    lines = String.split(log_content, "\n")

    {_warnings, __} = Enum.reduce(lines, {[], nil}, fn line, {acc, current_warning} ->
      cond do
        String.contains?(line, "warning: variable") and String.contains?(line, "is unused") ->
          # Extract variable name
          case Regex.run(~r/variable "([^"]+)" is unused/, line) do
            [_, var_name] ->
              {acc, %{variable: var_name, file: nil, line: nil}}
            _ ->
              {acc, current_warning}
          end

        String.contains?(line, "warning: the underscored variable") ->
          # Extract underscored variable name
          case Regex.run(~r/underscored variable "([^"]+)" is used/, line) do
            [_, var_name] ->
              {acc, %{variable: var_name, file: nil, line: nil, type: :underscored_used}}
            _ ->
              {acc, current_warning}
          end

        String.contains?(line, "└─ ") and current_warning != nil ->
          # Extract file and line info
          case Regex.run(~r/└─ ([^:]+):(\d+)/, line) do
            [_, file, line_num] ->
              warning = %{current_warning | file: file, line: String.to_integer(line_num)}
              {[warning | acc], nil}
            _ ->
              {acc, current_warning}
          end

        true ->
          {acc, current_warning}
      end
    end)

    warnings
    |> Enum.reverse()
    |> Enum.filter(&(&1.file != nil))
  end

  defp fix_file_warnings(file_path, warnings) do
    case File.read(file_path) do
      {:ok, content} ->
        # Apply fixes for each unused variable warning
        _fixed_content =
          Enum.reduce(warnings, _content, fn warning, acc ->
            fix_unused_variable_in_content(acc, warning)
          end)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("   ✅ Fixed #{length(warnings)} warnings in #{Path.basename(file_path)}")
          length(warnings)
        else
          IO.puts("   ⚠️  No changes made to #{Path.basename(file_path)}")
          0
        end

      {:error, reason} ->
        IO.puts("   ❌ Could not read #{file_path}: #{reason}")
        0
    end
  end

  defp fix_unused_variable_in_content(content, %{variable: variable, type: :underscored_used}) do
    # Remove underscore from variables that are actually used
    underscored_var = "_#{variable}"

    content
    |> String.replace(~r/\b#{Regex.escape(underscored_var)}\b/, variable)
  end

  defp fix_unused_variable_in_content(content, %{variable: variable}) do
    # Add underscore prefix to unused variables
    underscore_var = "_#{variable}"

    # Pattern for function parameters and variable assignments
    content
    |> String.replace(~r/\bdef\s+([^(]+)\(([^)]*)\b#{Regex.escape(variable)}\b([^)]*)\)/, fn match ->
      String.replace(match, variable, underscore_var)
    end)
    |> String.replace(~r/\bdefp\s+([^(]+)\(([^)]*)\b#{Regex.escape(variable)}\b([^)]*)\)/, fn match ->
      String.replace(match, variable, underscore_var)
    end)
    # Also handle variable assignments like "__state = %{}"
    |> String.replace(~r/^\s*#{Regex.escape(variable)}\s*=/, fn match ->
      String.replace(match, variable, underscore_var)
    end, global: true)
  end

  defp run_validation_compile do
    IO.puts("🔍 Running final validation compilation...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful - Zero warnings achieved!")
      {output, _} ->
        warning_count = count_warnings_in_output(output)
        IO.puts("⚠️  Compilation warnings remaining: #{warning_count}")

        # Save remaining warnings
        File.write!("./__data/tmp/remaining_warnings_#{timestamp()}.log", output)
    end
  end

  defp count_warnings_in_output(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "warning:"))
  end

  defp timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Run if called directly
FinalUnusedVariableFixer.main(System.argv())