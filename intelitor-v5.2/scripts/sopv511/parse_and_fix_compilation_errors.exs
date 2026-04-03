#!/usr/bin/env elixir

defmodule ParseAndFixCompilationErrors do
  @moduledoc """
  Parses compilation log file to extract exact error locations and applies targeted fixes.
  Handles the specific pattern of underscore prefix mismatches.
  """

  def run do
    log_file = "9-compile-after-fixes.log"
    IO.puts("🔍 Parsing compilation errors from #{log_file}...")

    # Read the log file and extract errors with full context
    errors = extract_errors_from_log(log_file)

    IO.puts("📊 Found #{length(errors)} errors to fix")

    # Group by file and apply fixes
    errors_by_file = Enum.group_by(errors, & &1.file)

    for {file, file_errors} <- errors_by_file do
      IO.puts("\n📁 Fixing #{file}:")
      IO.puts("   Found #{length(file_errors)} errors")

      fix_file_errors(file, file_errors)
    end

    IO.puts("\n✨ Fixes applied! Run compilation to verify.")
  end

  defp extract_errors_from_log(log_file) do
    content = File.read!(log_file)

    # Split by compilation error blocks
    error_blocks = Regex.split(~r/== Compilation error in file/, content)
    |> Enum.drop(1) # Remove the part before first error

    Enum.flat_map(error_blocks, fn block ->
      # Extract file path
      file = case Regex.run(~r/^([^\s]+)/, block) do
        [_, path] -> String.trim(path)
        _ -> nil
      end

      if file do
        # Extract all undefined variable errors from this file block
        extract_undefined_variable_errors(file, block)
      else
        []
      end
    end)
  end

  defp extract_undefined_variable_errors(file, block) do
    # Pattern to match undefined variable errors with context
    # The error shows the line number and actual code
    regex = ~r/error: undefined variable "([^"]+)".*?\n\s*│\n\s*(\d+) │([^\n]+)/ms

    Regex.scan(regex, block)
    |> Enum.map(fn [_, var_name, line_num, code_context] ->
      %{
        file: file,
        variable: var_name,
        line: String.to_integer(line_num),
        code_context: String.trim(code_context)
      }
    end)
  end

  defp fix_file_errors(file, errors) do
    if File.exists?(file) do
      content = File.read!(file)
      lines = String.split(content, "\n")

      # Apply fixes to each error
      fixed_lines = Enum.reduce(errors, lines, fn error, current_lines ->
        apply_fix(current_lines, error)
      end)

      # Write back the fixed content
      fixed_content = Enum.join(fixed_lines, "\n")
      File.write!(file, fixed_content)

      IO.puts("   ✅ Applied #{length(errors)} fixes")
    else
      IO.puts("   ❌ File not found: #{file}")
    end
  end

  defp apply_fix(lines, error) do
    line_index = error.line - 1

    if line_index >= 0 and line_index < length(lines) do
      current_line = Enum.at(lines, line_index)

      # Determine what fix to apply based on the error
      fixed_line = cond do
        error.variable == "context" ->
          # The variable "context" is undefined, but "_context" exists
          # So replace "context" with "_context" in this line
          String.replace(current_line, ~r/\bcontext(?!:)/, "_context")

        error.variable == "opts" ->
          # The variable "opts" is undefined, but "_opts" exists
          String.replace(current_line, ~r/\bopts\b/, "_opts")

        error.variable == "data" ->
          # The variable "data" is undefined, but "_data" exists
          String.replace(current_line, ~r/\bdata\b/, "_data")

        String.starts_with?(error.variable, "_") ->
          # The underscored variable is undefined, so the non-underscored exists
          # Remove the underscore
          non_underscored = String.slice(error.variable, 1..-1)
          String.replace(current_line, ~r/\b#{error.variable}\b/, non_underscored)

        true ->
          # For other variables, try adding underscore
          String.replace(current_line, ~r/\b#{error.variable}\b/, "_#{error.variable}")
      end

      List.replace_at(lines, line_index, fixed_line)
    else
      IO.puts("   ⚠️ Invalid line number #{error.line} for error")
      lines
    end
  end
end

# Run the parser and fixer
ParseAndFixCompilationErrors.run()