#!/usr/bin/env elixir

# Systematic Msg Warning Fixer
# Target: performance domain modules

performance_dir = "lib/indrajaal/performance/"

IO.puts("🔧 Starting systematic msg warning elimination in #{performance_dir}...")

files = 
  if File.dir?(performance_dir) do
    File.ls!(performance_dir)
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
    |> Enum.map(&Path.join(performance_dir, &1))
  else
    []
  end

IO.puts("📊 Found #{length(files)} files to process")

Enum.each(files, fn file_path ->
  content = File.read!(file_path)
  
  # Pattern: def handle_call(msg, _from, state)
  # We want to change msg to _msg
  if String.contains?(content, "def handle_call(msg,") do
    new_content = String.replace(content, "def handle_call(msg,", "def handle_call(_msg,")
    File.write!(file_path, new_content)
    IO.puts("✅ Fixed: #{file_path}")
  else
    # Also check for msg without space after comma if any
    if String.contains?(content, "def handle_call(msg ,") do
       new_content = String.replace(content, "def handle_call(msg ,", "def handle_call(_msg ,")
       File.write!(file_path, new_content)
       IO.puts("✅ Fixed: #{file_path} (alt pattern)")
    end
  end
end)

IO.puts("🎯 Systematic msg warning elimination completed!")
