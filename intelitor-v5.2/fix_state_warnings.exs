#!/usr/bin/env elixir

# Systematic State Warning Fixer
# Following TPS methodology for batch processing

# Extract state warnings from compilation log
{state_warnings, _} =
  System.cmd("grep", ["-A", "1", "variable \"state\" is unused", "phase1_completion_check.log"])

state_locations =
  state_warnings
  |> String.split("\n")
  |> Enum.filter(&String.contains?(&1, ".ex:"))
  |> Enum.map(fn line ->
    [file_line | _] = String.split(line, " ")
    [file_path, line_str] = String.split(file_line, ":")
    [file_path, String.to_integer(line_str)]
  end)
  |> Enum.uniq()

IO.puts("🔧 Starting systematic state warning elimination...")
IO.puts("📊 Found #{length(state_locations)} state parameter warnings to fix")

Enum.with_index(state_locations, 1)
|> Enum.each(fn {[file_path, line_num], index} ->
  IO.puts("📝 Processing #{index}/#{length(state_locations)}: #{file_path}:#{line_num}")

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
