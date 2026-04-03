#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule DirectParameterFixer do
  @moduledoc """
  SOPv5.11 Direct Parameter Fixer - Fix all undefined variable errors systematically
  """

  def main(_args) do
    IO.puts("🚀 SOPv5.11 DIRECT PARAMETER FIXER STARTING")
    IO.puts("🎯 TARGET: Fix all undefined variable errors systematically")

    # Read the compilation log to get current errors
    compilation_log = read_compilation_log()

    # Extract undefined variable errors
    undefined_vars = extract_undefined_variables(compilation_log)

    IO.puts("📊 Found #{length(undefined_vars)} undefined variable errors")

    # Group by file
    errors_by_file = Enum.group_by(undefined_vars, & &1.file)

    IO.puts("📁 Files to fix: #{map_size(errors_by_file)}")

    # Fix each file
    total_fixed =
      for {file, errors} <- errors_by_file, reduce: 0 do
        acc ->
          IO.puts("🔧 Fixing #{length(errors)} errors in #{Path.basename(file)}")
          fixed = fix_file_errors(file, errors)
          acc + fixed
      end

    IO.puts("✅ DIRECT PARAMETER FIXING COMPLETE")
    IO.puts("📊 Total fixes applied: #{total_fixed}")

    # Run validation compilation
    run_validation_compile()
  end

  defp read_compilation_log do
    case File.read("2-compile.log") do
      {:ok, content} -> content
      {:error, _} ->
        case File.read("1-compile.log") do
          {:ok, content} -> content
          {:error, _} -> ""
        end
    end
  end

  defp extract_undefined_variables(log_content) do
    # Look for lines like: error: undefined variable "__opts"
    lines = String.split(log_content, "\n")

    {_errors, __} = Enum.reduce(lines, {[], nil}, fn line, {acc, current_error} ->
      cond do
        String.contains?(line, "error: undefined variable") ->
          # Extract variable name
          case Regex.run(~r/undefined variable "([^"]+)"/, line) do
            [_, var_name] ->
              {acc, %{variable: var_name, file: nil, line: nil}}
            _ ->
              {acc, current_error}
          end

        String.contains?(line, "└─ ") and current_error != nil ->
          # Extract file and line info
          case Regex.run(~r/└─ ([^:]+):(\d+)/, line) do
            [_, file, line_num] ->
              error = %{current_error | file: file, line: String.to_integer(line_num)}
              {[error | acc], nil}
            _ ->
              {acc, current_error}
          end

        true ->
          {acc, current_error}
      end
    end)

    errors
    |> Enum.reverse()
    |> Enum.filter(&(&1.file != nil))
  end

  defp fix_file_errors(file_path, errors) do
    case File.read(file_path) do
      {:ok, content} ->
        # Apply fixes for each undefined variable
        _fixed_content =
          Enum.reduce(errors, _content, fn error, acc ->
            fix_undefined_variable_in_content(acc, error)
          end)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("   ✅ Fixed #{length(errors)} errors in #{Path.basename(file_path)}")
          length(errors)
        else
          IO.puts("   ⚠️  No changes made to #{Path.basename(file_path)}")
          0
        end

      {:error, reason} ->
        IO.puts("   ❌ Could not read #{file_path}: #{reason}")
        0
    end
  end

  defp fix_undefined_variable_in_content(content, %{variable: variable}) do
    # Look for function definitions that use _variable but the body references variable
    underscore_param = "_#{variable}"

    # Pattern 1: def function(_opts) but body uses __opts
    content
    |> String.replace(~r/\bdef\s+([^(]+)\(([^)]*)\b#{Regex.escape(underscore_param)}\b([^)]*)\)/, fn match ->
      # Remove underscore from parameter
      String.replace(match, underscore_param, variable)
    end)
    # Pattern 2: defp function(_opts) but body uses __opts
    |> String.replace(~r/\bdefp\s+([^(]+)\(([^)]*)\b#{Regex.escape(underscore_param)}\b([^)]*)\)/, fn match ->
      # Remove underscore from parameter
      String.replace(match, underscore_param, variable)
    end)
  end

  defp run_validation_compile do
    IO.puts("🔍 Running validation compilation...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful!")
      {output, _} ->
        error_count = count_errors_in_output(output)
        warning_count = count_warnings_in_output(output)
        IO.puts("⚠️  Compilation issues remaining:")
        IO.puts("   📊 Errors: #{error_count}")
        IO.puts("   📊 Warnings: #{warning_count}")

        # Save remaining issues
        File.write!("./__data/tmp/remaining_issues_#{timestamp()}.log", output)
    end
  end

  defp count_errors_in_output(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "error:"))
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
if __ENV__.file == :stdin do
  DirectParameterFixer.main(System.argv())
else
  DirectParameterFixer.main(System.argv())
end