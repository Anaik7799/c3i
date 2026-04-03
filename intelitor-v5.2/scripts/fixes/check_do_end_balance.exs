#!/usr/bin/env elixir

defmodule CheckDoEndBalance do
  @spec check_file(any()) :: any()
  def check_file(file) do
    content = File.read!(file)

    # Count "do" keywords (but not in comments or strings)
    dos = Regex.scan(~r/\bdo\b/, content) |> length()

    # Count "end" keywords
    ends = Regex.scan(~r/\bend\b/, content) |> length()

    IO.puts("File: #{file}")
    IO.puts("  do count: #{dos}")
    IO.puts("  end count: #{ends}")
    IO.puts("  difference: #{dos-ends}")

    if dos != ends do
      IO.puts("  ⚠️  UNBALANCED!")
      # Try to find the problematic section
      lines = String.split(content, "\n")

      # Track nesting level
      level = 0
      Enum.with_index(lines) |> Enum.each(fn {line, idx} ->
        if Regex.match?(~r/\bdo\b/, line) && !String.contains?(line, "#") do
          level = level + 1
        end
        if Regex.match?(~r/\bend\b/, line) && !String.contains?(line, "#") do
          level = level-1
          if level < 0 do
            IO.puts("  Found extra 'end' at line #{idx + 1}: #{String.trim(line)}
          end
        end
      end)

      if level > 0 do
        IO.puts("  Missing #{level} 'end' keyword(s)")
      end
    else
      IO.puts("  ✅ Balanced")
    end

    IO.puts("")
  end
end

# Check the problematic file
CheckDoEndBalance.check_file("lib/indrajaal/compliance/document.ex")
end
end
