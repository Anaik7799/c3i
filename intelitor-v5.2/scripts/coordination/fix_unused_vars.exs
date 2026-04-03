#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule UnusedVariableFixer do
  def run do
    IO.puts("🔧 Unused Variable Fixer")
    IO.puts(String.duplicate("=", 60))

    warnings = extract_warnings()
    IO.puts("\nFound #{length(warnings)} unused variable warnings\n")

    warnings
    |> Enum.group_by(& &1.file)
    |> Enum.each(fn {file, file_warnings} ->
      fix_file(file, file_warnings)
    end)

    IO.puts("\n✅ Complete!")
  end

  defp extract_warnings do
    File.read!("10-compile.log")
    |> String.split("\n")
    |> Enum.chunk_every(10, 1, :discard)
    |> Enum.filter(fn chunk ->
      Enum.any?(chunk, &(String.contains?(&1, "is unused") && String.contains?(&1, "variable")))
    end)
    |> Enum.map(&parse_warning/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_warning(chunk) do
    footer = Enum.find(chunk, &String.starts_with?(&1, "     └─"))
    warning = Enum.find(chunk, &(String.contains?(&1, "variable") && String.contains?(&1, "is unused")))

    if footer && warning do
      case {extract_file_line(footer), extract_var(warning)} do
        {{file, line}, var} when not is_nil(var) -> %{file: file, line: line, var: var}
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

  defp fix_file(file, warnings) do
    IO.puts("📝 #{file}")
    content = File.read!(file)
    lines = String.split(content, "\n")

    fixed = Enum.with_index(lines, 1)
    |> Enum.map(fn {line, num} ->
      w = Enum.find(warnings, & &1.line == num)
      if w && (String.contains?(line, "def ") || String.contains?(line, "defp ")) do
        Regex.replace(~r/\b#{Regex.escape(w.var)}\b/, line, "_#{w.var}", global: false)
      else
        line
      end
    end)
    |> Enum.join("\n")

    if fixed != content do
      File.write!(file, fixed)
      IO.puts("   ✓ Fixed #{length(warnings)} variables")
    end
  end
end

UnusedVariableFixer.run()