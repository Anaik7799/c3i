#!/usr/bin/env elixir

# Systematic State Warning Fixer - Version 2
# Following TPS methodology for batch processing

IO.puts("🔧 Starting systematic state warning elimination...")

# Extract file paths and line numbers from the compilation log
log_content = File.read!("phase1_completion_check.log")

# Find lines with file paths that come after state variable warnings
file_locations =
  log_content
  |> String.split("\n")
  |> Enum.with_index()
  |> Enum.filter(fn {line, _} ->
    String.contains?(line, ".ex:") and String.contains?(line, "└─")
  end)
  |> Enum.map(fn {line, _} ->
    # Extract file:line from format like "└─ lib/indrajaal/coordination/agent_manager.ex:531:42:"
    [_, file_info] = String.split(line, "└─ ")
    [file_line | _] = String.split(file_info, ":")
    [file_path, line_str] = String.split(file_line, ":")
    [String.trim(file_path), String.to_integer(line_str)]
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
