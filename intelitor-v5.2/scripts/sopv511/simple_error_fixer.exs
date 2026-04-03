#!/usr/bin/env elixir

defmodule SimpleErrorFixer do
  @moduledoc """
  Simple and direct fix for undefined variable errors based on compilation log.
  """

  def run do
    IO.puts("🔍 Analyzing compilation errors...")

    # Parse the log to find all undefined variable errors
    log_content = File.read!("9-compile-after-fixes.log")

    # Extract file paths and their errors
    errors = parse_errors(log_content)

    # Group errors by file
    errors_by_file = Enum.group_by(errors, & &1.file)

    IO.puts("📊 Found errors in #{map_size(errors_by_file)} files")

    # Apply fixes to each file
    for {file, file_errors} <- errors_by_file do
      IO.puts("\n📁 Fixing #{file}:")
      IO.puts("   #{length(file_errors)} errors found")

      apply_fixes_to_file(file, file_errors)
    end

    IO.puts("\n✨ Fixes complete!")
  end

  defp parse_errors(log_content) do
    # First find all file sections
    file_sections = Regex.split(~r/Compiling \d+ files? \(.ex\)/, log_content)

    Enum.flat_map(file_sections, fn section ->
      # Try to extract the file being compiled
      lines = String.split(section, "\n")

      # Find undefined variable errors
      errors = []

      current_file = nil
      Enum.reduce(lines, {current_file, errors}, fn line, {file, acc} ->
        cond do
          # Check for file path in warning/error headers
          String.contains?(line, "warning:") and String.contains?(line, ".ex:") ->
            file_match = Regex.run(~r/([^\s]+\.ex):\d+/, line)
            new_file = if file_match, do: Enum.at(file_match, 1), else: file
            {new_file, acc}

          # Check for undefined variable error
          String.contains?(line, "error: undefined variable") ->
            var_match = Regex.run(~r/error: undefined variable "([^"]+)"/, line)
            if var_match do
              var_name = Enum.at(var_match, 1)
              {file, [{file, var_name} | acc]}
            else
              {file, acc}
            end

          true ->
            {file, acc}
        end
      end)
      |> elem(1)
    end)
    |> Enum.reject(fn {file, _} -> is_nil(file) end)
    |> Enum.map(fn {file, var} -> %{file: file, variable: var} end)
  end

  defp apply_fixes_to_file(nil, _), do: :ok

  defp apply_fixes_to_file(file, errors) do
    if File.exists?(file) do
      content = File.read!(file)

      # Apply all fixes
      fixed_content = Enum.reduce(errors, content, fn error, acc ->
        apply_variable_fix(acc, error.variable)
      end)

      File.write!(file, fixed_content)
      IO.puts("   ✅ Applied #{length(errors)} fixes")
    else
      IO.puts("   ❌ File not found")
    end
  end

  defp apply_variable_fix(content, variable) do
    case variable do
      "context" ->
        # Replace context with _context where it appears as a standalone variable
        String.replace(content, ~r/\bcontext\b(?!:)/, "_context")

      "opts" ->
        # Replace opts with _opts
        String.replace(content, ~r/\bopts\b/, "_opts")

      "data" ->
        # Replace data with _data
        String.replace(content, ~r/\bdata\b/, "_data")

      "_" <> rest ->
        # If it starts with underscore, remove it
        String.replace(content, ~r/\b#{Regex.escape(variable)}\b/, rest)

      _ ->
        # Otherwise add underscore
        String.replace(content, ~r/\b#{Regex.escape(variable)}\b/, "_#{variable}")
    end
  end
end

# Run the fixer
SimpleErrorFixer.run()