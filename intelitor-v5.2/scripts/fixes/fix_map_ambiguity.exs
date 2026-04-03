#!/usr/bin/env elixir

defmodule MapAmbiguityFixer do
  @moduledoc """
  Fixes ambiguous map/2 import errors in test files.
  The issue: Both PropCheck.BasicTypes and StreamData export map/2
  Solution: In PropCheck forall contexts, use PropCheck.BasicTypes.map()
            In ExUnitProperties contexts, use StreamData.map()
  """

  def run do
    IO.puts("🔧 Fixing ambiguous map/2 imports...")
    IO.puts("============================================================")

    test_files = Path.wildcard("test/**/*.exs")

    total_fixes =
      test_files
      |> Enum.map(&fix_file/1)
      |> Enum.filter(&(&1 != nil))
      |> Enum.reduce(0, fn {:fixed, count}, acc -> acc + count end)

    IO.puts("============================================================")
    IO.puts("✅ Total map() calls fixed: #{total_fixes}")
    IO.puts("✅ Fix completed!")
  end

  defp fix_file(file) do
    content = File.read!(file)

    # Only process files that use both PropCheck and ExUnitProperties
    uses_both = String.contains?(content, "use PropCheck") and
                String.contains?(content, "use ExUnitProperties")

    if uses_both do
      original_content = content

      # Fix map() calls inside PropCheck forall blocks
      # Pattern: forall ... <- { ... map(atom(), term()) ... }
      # Replace with PropCheck.BasicTypes.map(atom(), term())
      content = fix_propcheck_map_calls(content)

      if content != original_content do
        File.write!(file, content)
        fix_count = count_fixes(original_content, content)
        IO.puts("✅ Fixed #{fix_count} map() calls in: #{file}")
        {:fixed, fix_count}
      else
        nil
      end
    else
      nil
    end
  end

  defp fix_propcheck_map_calls(content) do
    # Find forall blocks and fix map() calls within them
    # Pattern: Inside forall blocks, map(atom(), ...) should use PropCheck.BasicTypes.map

    # Simple pattern: map(atom(), followed by any character until closing paren
    # We need to prefix with PropCheck.BasicTypes. in PropCheck contexts

    # Split by forall to find PropCheck contexts
    lines = String.split(content, "\n")

    {fixed_lines, _in_forall} =
      Enum.reduce(lines, {[], false}, fn line, {acc, in_forall} ->
        new_in_forall = cond do
          String.contains?(line, "forall") and String.contains?(line, "<-") -> true
          String.contains?(line, "end") and in_forall and not String.contains?(line, "def") -> false
          true -> in_forall
        end

        fixed_line = if in_forall or (String.contains?(line, "forall") and String.contains?(line, "<-")) do
          # Fix map(atom(), term()) pattern - but not already prefixed
          line
          |> fix_map_in_propcheck_line()
        else
          line
        end

        {acc ++ [fixed_line], new_in_forall}
      end)

    Enum.join(fixed_lines, "\n")
  end

  defp fix_map_in_propcheck_line(line) do
    # Don't modify if already has a module prefix for map
    if String.contains?(line, "PropCheck.BasicTypes.map") or
       String.contains?(line, "StreamData.map") or
       String.contains?(line, "Enum.map") or
       String.contains?(line, "Map.") do
      line
    else
      # Fix map(atom(), term()) pattern in forall context
      # This should use PropCheck.BasicTypes.map
      Regex.replace(
        ~r/(?<!\.)(?<!\w)map\(atom\(\),\s*term\(\)\)/,
        line,
        "PropCheck.BasicTypes.map(atom(), term())"
      )
    end
  end

  defp count_fixes(original, fixed) do
    original_count = length(Regex.scan(~r/(?<!\.)(?<!\w)map\(atom\(\),\s*term\(\)\)/, original))
    fixed_count = length(Regex.scan(~r/(?<!\.)(?<!\w)map\(atom\(\),\s*term\(\)\)/, fixed))
    original_count - fixed_count
  end
end

MapAmbiguityFixer.run()
