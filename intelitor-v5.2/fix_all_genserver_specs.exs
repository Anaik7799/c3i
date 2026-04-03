#!/usr/bin/env elixir

# Comprehensive GenServer handle_call spec fixer
# SOPv5.1 systematic approach to fix ALL incorrect handle_call specs

IO.puts("🔧 Comprehensive GenServer handle_call spec fixer")
IO.puts("Finding all .ex files...")

# Find all .ex files
{files_output, 0} = System.cmd("find", ["lib/", "-name", "*.ex"])
all_files = files_output |> String.trim() |> String.split("\n")

IO.puts("Found #{length(all_files)} files to check")

fixed_files = 0
total_fixes = 0

# Patterns to fix - all GenServer handle_call specs should have exactly 3 parameters
fix_patterns = [
  # 4 parameters
  {~r/@spec handle_call\(term\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # 5 parameters
  {~r/@spec handle_call\(term\(\), term\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # 6 parameters
  {~r/@spec handle_call\(term\(\), term\(\), term\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # Binary/integer patterns with 4 parameters
  {~r/@spec handle_call\(term\(\), binary\(\) \| integer\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # Binary/integer patterns with 5 parameters  
  {~r/@spec handle_call\(term\(\), binary\(\) \| integer\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # Binary/integer patterns with 6 parameters
  {~r/@spec handle_call\(term\(\), binary\(\) \| integer\(\), term\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # Other mixed patterns
  {~r/@spec handle_call\(binary\(\) \| integer\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},
  {~r/@spec handle_call\(binary\(\) \| integer\(\), term\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},
  {~r/@spec handle_call\(binary\(\) \| integer\(\), term\(\), term\(\), term\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # Complex patterns with keyword/map
  {~r/@spec handle_call\(term\(\), binary\(\) \| integer\(\), keyword\(\) \| map\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},
  {~r/@spec handle_call\(term\(\), binary\(\) \| integer\(\), term\(\), keyword\(\) \| map\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},
  {~r/@spec handle_call\(binary\(\) \| integer\(\), keyword\(\) \| map\(\), term\(\), term\(\)\) :: term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},

  # Handle return type variations
  {~r/@spec handle_call\(term\(\), binary\(\) \| integer\(\), term\(\), keyword\(\) \| map\(\), term\(\), term\(\)\) ::[\s\n]*term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"},
  {~r/@spec handle_call\(term\(\), binary\(\) \| integer\(\), binary\(\) \| integer\(\), term\(\), term\(\), term\(\)\) ::[\s\n]*term\(\)/,
   "@spec handle_call(term(), term(), term()) :: term()"}
]

Enum.each(all_files, fn file_path ->
  case File.read(file_path) do
    {:ok, content} ->
      new_content =
        Enum.reduce(fix_patterns, content, fn {pattern, replacement}, acc ->
          if Regex.match?(pattern, acc) do
            total_fixes = total_fixes + 1
            String.replace(acc, pattern, replacement)
          else
            acc
          end
        end)

      if new_content != content do
        File.write!(file_path, new_content)
        IO.puts("✅ Fixed: #{file_path}")
        fixed_files = fixed_files + 1
      end

    {:error, reason} ->
      IO.puts("❌ Error reading #{file_path}: #{reason}")
  end
end)

IO.puts("\n🏁 GenServer spec fixing complete!")
IO.puts("Files fixed: #{fixed_files}")
IO.puts("Total patterns fixed: #{total_fixes}")
IO.puts("Files processed: #{length(all_files)}")
