#!/usr/bin/env elixir

# Systematic State Warning Fixer - Version 3
# Following TPS methodology for batch processing

IO.puts("🔧 Starting systematic state warning elimination...")

# Extract file paths and line numbers from the compilation log
{output, _} = System.cmd("grep", ["└─", "phase1_completion_check.log"])

file_locations =
  output
  |> String.split("\n")
  |> Enum.filter(&(String.trim(&1) != ""))
  |> Enum.map(fn line ->
    # Extract from format like "└─ lib/indrajaal/coordination/agent_manager.ex:531:42: ..."
    trimmed = String.trim(line)
    [_, file_part] = String.split(trimmed, "└─ ", parts: 2)
    [file_line | _] = String.split(file_part, ":")

    # Split file path and line number
    parts = String.split(file_line, ":")
    file_path = Enum.at(parts, 0)
    line_num = Enum.at(parts, 1) |> String.to_integer()

    [file_path, line_num]
  end)
  |> Enum.uniq()

IO.puts("📊 Found #{length(file_locations)} state parameter warnings to fix")

Enum.with_index(file_locations, 1)
|> Enum.each(fn {[file_path, line_num], index} ->
  IO.puts("📝 Processing #{index}/#{length(file_locations)}: #{file_path}:#{line_num}")

  if File.exists?(file_path) do
    content = File.read!(file_path)
    lines = String.split(content, "\n", parts: :infinity)

    if line_num <= length(lines) do
      target_line = Enum.at(lines, line_num - 1)

      # Fix pattern: replace " state" with "_state" in function definitions
      fixed_line =
        cond do
          String.contains?(target_line, "defp") and String.contains?(target_line, " state)") ->
            String.replace(target_line, " state)", "_state)")

          String.contains?(target_line, "defp") and String.contains?(target_line, " state,") ->
            String.replace(target_line, " state,", "_state,")

          String.contains?(target_line, "defp") and String.contains?(target_line, " state ") ->
            String.replace(target_line, " state ", "_state ")

          String.contains?(target_line, "def ") and String.contains?(target_line, " state)") ->
            String.replace(target_line, " state)", "_state)")

          String.contains?(target_line, "def ") and String.contains?(target_line, " state,") ->
            String.replace(target_line, " state,", "_state,")

          true ->
            target_line
        end

      if fixed_line != target_line do
        updated_lines = List.replace_at(lines, line_num - 1, fixed_line)
        File.write!(file_path, Enum.join(updated_lines, "\n"))
        IO.puts("✅ Fixed: #{file_path}:#{line_num}")
      else
        IO.puts("⚠️  Pattern not found: #{file_path}:#{line_num}")
        IO.puts("    Line: #{String.trim(target_line)}")
      end
    else
      IO.puts("❌ Invalid line number: #{file_path}:#{line_num}")
    end
  else
    IO.puts("❌ File not found: #{file_path}")
  end
end)

IO.puts("🎯 Systematic state warning elimination completed!")
