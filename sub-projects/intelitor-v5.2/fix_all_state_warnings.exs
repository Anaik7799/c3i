#!/usr/bin/env elixir

# Comprehensive State Warning Fixer
# Following TPS methodology for systematic batch processing

Mix.install([{:jason, "~> 1.4"}])

IO.puts("🔧 Starting comprehensive state warning elimination...")

# Read the compilation log and extract all state warnings
log_content = File.read!("phase1_completion_check.log")

# Use regex to find all file:line combinations with state warnings
state_warning_locations =
  Regex.scan(~r/lib\/[^\s]+\.ex:(\d+):\d+:/, log_content)
  |> Enum.map(fn [full_match, line_num_str] ->
    # Extract file path from full match
    file_path = String.replace(full_match, ~r/:(\d+):\d+:$/, "")
    [file_path, String.to_integer(line_num_str)]
  end)
  |> Enum.uniq()

IO.puts("📊 Found #{length(state_warning_locations)} unique state parameter locations to fix")

# Process each file systematically
Enum.with_index(state_warning_locations, 1)
|> Enum.each(fn {[file_path, line_num], index} ->
  IO.puts("📝 Processing #{index}/#{length(state_warning_locations)}: #{file_path}:#{line_num}")

  if File.exists?(file_path) do
    content = File.read!(file_path)
    lines = String.split(content, "\n", parts: :infinity)

    if line_num <= length(lines) do
      target_line = Enum.at(lines, line_num - 1)
      original_line = target_line

      # Multiple fix patterns for different scenarios
      fixed_line =
        target_line
        |> String.replace(~r/(\bdefp?\s+[^(]+\([^)]*),\s+state(\))/, "\\1, _state\\2")
        |> String.replace(~r/(\bdefp?\s+[^(]+\([^)]*),\s+state(\s*,)/, "\\1, _state\\2")
        |> String.replace(~r/(\bdefp?\s+[^(]+\(\s*)state(\))/, "\\1_state\\2")
        |> String.replace(~r/(\bdefp?\s+[^(]+\(\s*)state(\s*,)/, "\\1_state\\2")

      if fixed_line != original_line do
        updated_lines = List.replace_at(lines, line_num - 1, fixed_line)
        File.write!(file_path, Enum.join(updated_lines, "\n"))
        IO.puts("✅ Fixed: #{file_path}:#{line_num}")
        IO.puts("    Before: #{String.trim(original_line)}")
        IO.puts("    After:  #{String.trim(fixed_line)}")
      else
        IO.puts("⚠️  No pattern match: #{file_path}:#{line_num}")
        IO.puts("    Line: #{String.trim(target_line)}")
      end
    else
      IO.puts("❌ Invalid line number: #{file_path}:#{line_num}")
    end
  else
    IO.puts("❌ File not found: #{file_path}")
  end
end)

IO.puts("🎯 Comprehensive state warning elimination completed!")
