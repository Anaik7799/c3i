#!/usr/bin/env elixir

defmodule TargetedCompilationErrorFixer do
  @moduledoc """
  Analyzes compilation log and makes targeted fixes for undefined variable errors.
  Specifically handles underscore prefix mismatches between function parameters and body usage.
  """

  def run(log_file \\ "9-compile-after-fixes.log") do
    IO.puts("🔍 Analyzing compilation errors from #{log_file}...")

    errors = parse_compilation_errors(log_file)
    IO.puts("📊 Found #{length(errors)} undefined variable errors to fix")

    # Group errors by file
    errors_by_file = Enum.group_by(errors, & &1.file)

    IO.puts("\n📁 Files to fix:")
    for {file, file_errors} <- errors_by_file do
      IO.puts("  • #{file}: #{length(file_errors)} errors")
    end

    # Apply fixes
    total_fixes = 0
    for {file, file_errors} <- errors_by_file do
      case apply_targeted_fixes(file, file_errors) do
        {:ok, count} ->
          total_fixes = total_fixes + count
          IO.puts("✅ Fixed #{count} errors in #{file}")
        {:error, reason} ->
          IO.puts("❌ Failed to fix #{file}: #{reason}")
      end
    end

    IO.puts("\n✨ Applied #{total_fixes} targeted fixes")
    IO.puts("🔄 Run compilation again to verify fixes")
  end

  defp parse_compilation_errors(log_file) do
    if not File.exists?(log_file) do
      IO.puts("❌ Log file not found: #{log_file}")
      []
    else
      content = File.read!(log_file)

      # Parse undefined variable errors with their context
      # Pattern: error: undefined variable "variable_name"
      # Followed by line number and code context

      regex = ~r/error: undefined variable "([^"]+)"[^│]*\n[^\d]*(\d+) │\s*([^\n]+)/m

      Regex.scan(regex, content)
      |> Enum.map(fn [_full, var_name, line_num, code_line] ->
        # Extract file path from the error context (appears before the error)
        file_regex = ~r/== Compilation error in file ([^\s]+) ==/
        file_match = Regex.run(file_regex,
          String.slice(content, 0..String.length(content)))

        file = case file_match do
          [_, path] -> path
          _ ->
            # Alternative pattern for file path
            case Regex.run(~r/Compiling.*\n.*error.*\n[^\n]*([^\s:]+):(\d+)/, content) do
              [_, path, _] -> path
              _ -> "unknown"
            end
        end

        # Determine context - if we're looking for "context" but have "_context" or vice versa
        needs_underscore = not String.starts_with?(var_name, "_") and
                          String.contains?(code_line, var_name)

        %{
          file: extract_file_from_context(content, var_name, line_num),
          variable: var_name,
          line: String.to_integer(line_num),
          code: String.trim(code_line),
          needs_underscore: needs_underscore
        }
      end)
      |> Enum.filter(& &1.file != "unknown")
    end
  end

  defp extract_file_from_context(content, var_name, line_num) do
    # Look for file path in compilation error headers
    lines = String.split(content, "\n")

    # Find the error line
    error_index = Enum.find_index(lines, fn line ->
      String.contains?(line, "undefined variable \"#{var_name}\"")
    end)

    if error_index do
      # Look backwards for file path
      Enum.slice(lines, max(0, error_index - 20)..error_index)
      |> Enum.reverse()
      |> Enum.find_value(fn line ->
        cond do
          String.contains?(line, "== Compilation error in file") ->
            case Regex.run(~r/== Compilation error in file ([^\s]+) ==/, line) do
              [_, path] -> path
              _ -> nil
            end
          String.starts_with?(line, "Compiling") ->
            case Regex.run(~r/Compiling \d+ files? \(\.ex\)\n?([^\n]+)?/, line) do
              [_, _] -> nil
              _ -> nil
            end
          true -> nil
        end
      end)
    end || begin
      # Alternative: Look for most recent file pattern
      case Regex.run(~r/lib\/indrajaal\/[^:]+\.ex/, content) do
        [path] -> path
        _ -> "unknown"
      end
    end
  end

  defp apply_targeted_fixes(file, errors) when file == "unknown" do
    {:error, "Cannot determine file path"}
  end

  defp apply_targeted_fixes(file, errors) do
    if not File.exists?(file) do
      {:error, "File not found"}
    else
      content = File.read!(file)
      lines = String.split(content, "\n")

      # Sort errors by line number in reverse to avoid offset issues
      sorted_errors = Enum.sort_by(errors, & &1.line, :desc)

      fixed_lines = Enum.reduce(sorted_errors, lines, fn error, acc ->
        fix_line_variable(acc, error)
      end)

      fixed_content = Enum.join(fixed_lines, "\n")
      File.write!(file, fixed_content)

      {:ok, length(errors)}
    end
  end

  defp fix_line_variable(lines, error) do
    line_index = error.line - 1

    if line_index < length(lines) do
      line = Enum.at(lines, line_index)

      # Smart fix based on the error context
      fixed_line = cond do
        # If variable is "context" and we need "_context"
        error.variable == "context" and String.contains?(line, "context") ->
          # Check if this is in a function signature or body
          if String.contains?(line, "def") or String.contains?(line, "defp") do
            # Don't change function signatures here
            line
          else
            # In function body, change context to _context if that's what's defined
            String.replace(line, ~r/\bcontext\b/, "_context")
          end

        # If variable is "opts" and we need "_opts"
        error.variable == "opts" and String.contains?(line, "opts") ->
          String.replace(line, ~r/\bopts\b/, "_opts")

        # If variable is "data" and we need "_data"
        error.variable == "data" and String.contains?(line, "data") ->
          String.replace(line, ~r/\bdata\b/, "_data")

        # If variable has underscore but shouldn't
        String.starts_with?(error.variable, "_") ->
          var_without_underscore = String.slice(error.variable, 1..-1)
          String.replace(line, ~r/\b#{error.variable}\b/, var_without_underscore)

        true ->
          line
      end

      List.replace_at(lines, line_index, fixed_line)
    else
      lines
    end
  end
end

# Run the targeted fixer
TargetedCompilationErrorFixer.run()