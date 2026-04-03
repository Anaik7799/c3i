#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveUnusedVarFixer do
  def run do
    IO.puts("🔧 Comprehensive Unused Variable Fixer")
    IO.puts(String.duplicate("=", 60))

    # Get fresh compilation warnings
    {output, _} = System.cmd("sh", ["-c", "export ELIXIR_ERL_OPTIONS='+S 16' && mix compile --jobs 16 --warnings-as-errors 2>&1"],
                             env: [{"MIX_ENV", "dev"}])

    warnings = extract_warnings(output)
    IO.puts("\nFound #{length(warnings)} unused variable warnings\n")

    warnings
    |> Enum.group_by(& &1.file)
    |> Enum.each(fn {file, file_warnings} ->
      fix_file(file, file_warnings)
    end)

    IO.puts("\n✅ Complete! Fixed #{length(warnings)} warnings")
  end

  defp extract_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.chunk_every(10, 1, :discard)
    |> Enum.filter(fn chunk ->
      Enum.any?(chunk, &(String.contains?(&1, "is unused") && String.contains?(&1, "variable")))
    end)
    |> Enum.map(&parse_warning/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_warning(chunk) do
    # Find the footer line with file path and line number
    footer = Enum.find(chunk, &String.contains?(&1, "└─"))
    # Find the warning message with variable name
    warning = Enum.find(chunk, &(String.contains?(&1, "variable") && String.contains?(&1, "is unused")))
    # Find the line with the actual code (shows the variable)
    code_line = Enum.find(chunk, fn line ->
      String.match?(line, ~r/^\s*\d+\s*│/) && !String.contains?(line, "warning:")
    end)

    if footer && warning && code_line do
      case {extract_file_line(footer), extract_var(warning), extract_line_num(code_line)} do
        {{file, _}, var, line_num} when not is_nil(var) and not is_nil(line_num) ->
          %{file: file, line: line_num, var: var}
        _ -> nil
      end
    end
  end

  defp extract_file_line(footer) do
    case Regex.run(~r/(lib\/[^:]+\.ex):(\d+)/, footer) do
      [_, file, line] -> {file, String.to_integer(line)}
      _ -> nil
    end
  end

  defp extract_var(warning) do
    case Regex.run(~r/"([^"]+)" is unused/, warning) do
      [_, var] -> var
      _ -> nil
    end
  end

  defp extract_line_num(code_line) do
    case Regex.run(~r/^\s*(\d+)\s*│/, code_line) do
      [_, num] -> String.to_integer(num)
      _ -> nil
    end
  end

  defp fix_file(file, warnings) do
    IO.puts("📝 #{file}")

    if not File.exists?(file) do
      IO.puts("   ⚠️  File not found, skipping")
    else
      do_fix_file(file, warnings)
    end
  end

  defp do_fix_file(file, warnings) do

    content = File.read!(file)
    lines = String.split(content, "\n")

    fixed_lines = Enum.with_index(lines, 1)
    |> Enum.map(fn {line, num} ->
      warning = Enum.find(warnings, & &1.line == num)

      if warning do
        # Only fix if it's a function definition line
        cond do
          String.contains?(line, "def ") || String.contains?(line, "defp ") ->
            # Replace the exact variable name with underscore prefix
            fixed = Regex.replace(
              ~r/\b#{Regex.escape(warning.var)}\b/,
              line,
              "_#{warning.var}",
              global: false
            )
            IO.puts("   ✓ Line #{num}: #{warning.var} -> _#{warning.var}")
            fixed

          true ->
            line
        end
      else
        line
      end
    end)

    fixed_content = Enum.join(fixed_lines, "\n")

    if fixed_content != content do
      File.write!(file, fixed_content)
      IO.puts("   ✅ Fixed #{length(warnings)} variables in #{file}")
    else
      IO.puts("   ℹ️  No changes needed")
    end
  end
end

ComprehensiveUnusedVarFixer.run()