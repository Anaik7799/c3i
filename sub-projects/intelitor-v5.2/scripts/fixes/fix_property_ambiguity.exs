#!/usr/bin/env elixir

# SOPv5.11 Property Ambiguity Fix Script
# Fixes ambiguous property/2 calls in test files that use both PropCheck and ExUnitProperties
# This script adds explicit ExUnitProperties. prefix to property calls in ExUnitProperties sections

defmodule PropertyAmbiguityFixer do
  @moduledoc """
  Fixes the ambiguous property/2 import error that occurs when both PropCheck
  and ExUnitProperties are used in the same test file.

  The fix adds explicit `ExUnitProperties.property` qualification to property
  calls that are meant for ExUnitProperties (identified by using `check all`).
  """

  def run do
    IO.puts("SOPv5.11 Property Ambiguity Fix Script")
    IO.puts("=" |> String.duplicate(50))

    # Find all test files that use both PropCheck and ExUnitProperties
    files = find_dual_property_files()
    IO.puts("Found #{length(files)} files using both PropCheck and ExUnitProperties")

    fixed_count = Enum.reduce(files, 0, fn file, acc ->
      case fix_file(file) do
        {:fixed, count} ->
          IO.puts("✅ Fixed #{count} property calls in #{Path.basename(file)}")
          acc + count
        :no_changes ->
          acc
        {:error, reason} ->
          IO.puts("❌ Error in #{Path.basename(file)}: #{reason}")
          acc
      end
    end)

    IO.puts("")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("Total property calls fixed: #{fixed_count}")
    IO.puts("✅ Property ambiguity fix complete")
  end

  defp find_dual_property_files do
    Path.wildcard("test/**/*.exs")
    |> Enum.filter(&uses_both_property_libs?/1)
  end

  defp uses_both_property_libs?(file) do
    content = File.read!(file)
    String.contains?(content, "use PropCheck") and
    String.contains?(content, "use ExUnitProperties")
  end

  defp fix_file(file) do
    content = File.read!(file)

    # Only fix unqualified property calls that use check all pattern
    # This is the ExUnitProperties pattern, not PropCheck

    # Pattern 1: property at start of line followed by check all
    pattern1 = ~r/(\s+)(property\s+"[^"]+"\s+do\s*\n\s*check\s+all)/

    # Count matches before fixing
    matches = Regex.scan(pattern1, content) |> length()

    if matches > 0 do
      # Replace unqualified property with ExUnitProperties.property
      new_content = Regex.replace(pattern1, content, fn _, indent, rest ->
        "#{indent}ExUnitProperties.#{rest}"
      end)

      # Only write if content changed
      if new_content != content do
        File.write!(file, new_content)
        {:fixed, matches}
      else
        :no_changes
      end
    else
      :no_changes
    end
  end
end

PropertyAmbiguityFixer.run()
