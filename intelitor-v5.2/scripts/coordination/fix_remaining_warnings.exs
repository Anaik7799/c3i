#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule RemainingWarningsFixer do
  def run do
    IO.puts("🔧 Fixing Remaining Compilation Warnings")
    IO.puts(String.duplicate("=", 60))

    # Get compilation output
    {output, _} = System.cmd("sh", ["-c", "export ELIXIR_ERL_OPTIONS='+S 16' && mix compile --jobs 16 --warnings-as-errors 2>&1"],
                             env: [{"MIX_ENV", "dev"}])

    # Fix different types of warnings
    fix_unused_variables(output)
    fix_underscored_variables_used(output)

    IO.puts("\n✅ Complete! Re-run compilation to see remaining warnings")
  end

  defp fix_unused_variables(output) do
    IO.puts("\n📝 Fixing unused variable warnings...")

    warnings = extract_unused_var_warnings(output)
    IO.puts("Found #{length(warnings)} unused variable warnings")

    warnings
    |> Enum.group_by(& &1.file)
    |> Enum.each(fn {file, file_warnings} ->
      if File.exists?(file) do
        fix_unused_in_file(file, file_warnings)
      end
    end)
  end

  defp fix_underscored_variables_used(output) do
    IO.puts("\n📝 Fixing underscored variables being used...")

    warnings = extract_underscored_var_warnings(output)
    IO.puts("Found #{length(warnings)} underscored variable usage warnings")

    warnings
    |> Enum.group_by(& &1.file)
    |> Enum.each(fn {file, file_warnings} ->
      if File.exists?(file) do
        fix_underscored_in_file(file, file_warnings)
      end
    end)
  end

  defp extract_unused_var_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.chunk_every(10, 1, :discard)
    |> Enum.filter(fn chunk ->
      Enum.any?(chunk, &(String.contains?(&1, "variable") &&
                         String.contains?(&1, "is unused") &&
                         !String.contains?(&1, "function")))
    end)
    |> Enum.map(&parse_unused_var_warning/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_underscored_var_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.chunk_every(10, 1, :discard)
    |> Enum.filter(fn chunk ->
      Enum.any?(chunk, &String.contains?(&1, "underscored variable"))
    end)
    |> Enum.map(&parse_underscored_var_warning/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_unused_var_warning(chunk) do
    footer = Enum.find(chunk, &String.contains?(&1, "└─"))
    warning = Enum.find(chunk, &(String.contains?(&1, "variable") && String.contains?(&1, "is unused")))
    code_line = Enum.find(chunk, fn line ->
      String.match?(line, ~r/^\s*\d+\s*│/) && !String.contains?(line, "warning:")
    end)

    if footer && warning && code_line do
      case {extract_file_line(footer), extract_var_name(warning), extract_line_num(code_line)} do
        {{file, _}, var, line_num} when not is_nil(var) and not is_nil(line_num) ->
          %{file: file, line: line_num, var: var}
        _ -> nil
      end
    end
  end

  defp parse_underscored_var_warning(chunk) do
    footer = Enum.find(chunk, &String.contains?(&1, "└─"))
    warning = Enum.find(chunk, &String.contains?(&1, "underscored variable"))
    code_line = Enum.find(chunk, fn line ->
      String.match?(line, ~r/^\s*\d+\s*│/) && !String.contains?(line, "warning:")
    end)

    if footer && warning && code_line do
      case {extract_file_line(footer), extract_underscored_var(warning), extract_line_num(code_line)} do
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

  defp extract_var_name(warning) do
    case Regex.run(~r/variable "([^"]+)" is unused/, warning) do
      [_, var] -> var
      _ -> nil
    end
  end

  defp extract_underscored_var(warning) do
    case Regex.run(~r/underscored variable "([^"]+)" is used/, warning) do
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

  defp fix_unused_in_file(file, warnings) do
    IO.puts("  📝 #{file}")

    content = File.read!(file)
    lines = String.split(content, "\n")

    fixed_lines = Enum.with_index(lines, 1)
    |> Enum.map(fn {line, num} ->
      warning = Enum.find(warnings, & &1.line == num)

      if warning do
        # Only fix if it's a function definition line
        if String.contains?(line, "def ") || String.contains?(line, "defp ") do
          fixed = Regex.replace(
            ~r/\b#{Regex.escape(warning.var)}\b/,
            line,
            "_#{warning.var}",
            global: false
          )
          IO.puts("     ✓ Line #{num}: #{warning.var} -> _#{warning.var}")
          fixed
        else
          line
        end
      else
        line
      end
    end)

    fixed_content = Enum.join(fixed_lines, "\n")

    if fixed_content != content do
      File.write!(file, fixed_content)
    end
  end

  defp fix_underscored_in_file(file, warnings) do
    IO.puts("  📝 #{file}")

    content = File.read!(file)
    lines = String.split(content, "\n")

    fixed_lines = Enum.with_index(lines, 1)
    |> Enum.map(fn {line, num} ->
      warning = Enum.find(warnings, & &1.line == num)

      if warning do
        # Remove underscore prefix from variable that's being used
        var_without_underscore = String.replace_prefix(warning.var, "_", "")
        fixed = String.replace(line, warning.var, var_without_underscore)
        IO.puts("     ✓ Line #{num}: #{warning.var} -> #{var_without_underscore}")
        fixed
      else
        line
      end
    end)

    fixed_content = Enum.join(fixed_lines, "\n")

    if fixed_content != content do
      File.write!(file, fixed_content)
    end
  end
end

RemainingWarningsFixer.run()