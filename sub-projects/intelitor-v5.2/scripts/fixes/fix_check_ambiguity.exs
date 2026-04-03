#!/usr/bin/env elixir

# SOPv5.11 Check Ambiguity Fix Script
# Fixes ambiguous check/2 calls in test files that use both PropCheck and ExUnitProperties
# This script adds explicit ExUnitProperties. prefix to check calls in ExUnitProperties sections

defmodule CheckAmbiguityFixer do
  @moduledoc """
  Fixes the ambiguous check/2 import error that occurs when both PropCheck
  and ExUnitProperties are used in the same test file.

  The fix adds explicit `ExUnitProperties.check` qualification to check
  calls that are inside ExUnitProperties.property blocks.
  """

  def run do
    IO.puts("SOPv5.11 Check Ambiguity Fix Script")
    IO.puts("=" |> String.duplicate(50))

    # Find all test files that use both PropCheck and ExUnitProperties
    files = find_dual_property_files()
    IO.puts("Found #{length(files)} files using both PropCheck and ExUnitProperties")

    fixed_count = Enum.reduce(files, 0, fn file, acc ->
      case fix_file(file) do
        {:fixed, count} ->
          IO.puts("✅ Fixed #{count} check calls in #{Path.basename(file)}")
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
    IO.puts("Total check calls fixed: #{fixed_count}")
    IO.puts("✅ Check ambiguity fix complete")
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

    # Pattern to find unqualified check all( that is inside ExUnitProperties.property blocks
    # We need to be more careful here - we only want to fix `check all(` that is part of ExUnitProperties
    # (i.e., inside an ExUnitProperties.property block, not inside PropCheck.property blocks)

    # Strategy: Look for `check all(` that appears AFTER `ExUnitProperties.property` and BEFORE the closing `end`
    # This is complex because we need context, so let's use a simpler approach:
    # Replace `check all(` with `ExUnitProperties.check all(` globally EXCEPT when it's already qualified

    # Pattern 1: Unqualified check all( - replace with ExUnitProperties.check all(
    # But we need to be careful not to replace PropCheck's check/2
    # PropCheck uses `forall ... do` pattern, ExUnitProperties uses `check all(...) do`

    # Find unqualified `check all(` (not preceded by ExUnitProperties.)
    pattern = ~r/(?<!ExUnitProperties\.)(\s+)(check all\()/

    # Count matches before fixing
    matches = Regex.scan(pattern, content) |> length()

    if matches > 0 do
      # Replace unqualified check all with ExUnitProperties.check all
      new_content = Regex.replace(pattern, content, fn _, indent, _check_call ->
        "#{indent}ExUnitProperties.check all("
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

CheckAmbiguityFixer.run()
