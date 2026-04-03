#!/usr/bin/env elixir

# Fix all 'p' instead of 'defp' typos in advanced_multi_agent_coordinator.ex

file_path = "lib/indrajaal/coordination/advanced_multi_agent_coordinator.ex"

content = File.read!(file_path)

# Replace all lines starting with '  p ' (two spaces, p, space) with '  defp '
fixed_content = String.replace(content, ~r/^  p /m, "  defp ")

File.write!(file_path, fixed_content)

IO.puts("✅ Fixed all 'p' typos to 'defp' in #{file_path}")
