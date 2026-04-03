#!/usr/bin/env elixir

# Fix files that use BOTH `use PropCheck` AND `use ExUnitProperties`
# which causes property/2 and check/2 macro conflicts.
#
# Solution:
# 1. Change `use ExUnitProperties` to `import ExUnitProperties, except: [property: 2, check: 2]`
# 2. Change bare `check all` to `ExUnitProperties.check all`

defmodule UseExUnitPropertiesConflictFixer do
  @moduledoc """
  Fixes files that have both `use PropCheck` and `use ExUnitProperties`,
  which causes macro conflicts.
  """

  def run do
    IO.puts("=== Use ExUnitProperties + Use PropCheck Conflict Fixer ===\n")

    # Find files with both patterns
    files = find_conflict_files()
    IO.puts("Found #{length(files)} files with both `use PropCheck` AND `use ExUnitProperties`\n")

    # Fix each file
    results = Enum.map(files, &fix_file/1)

    # Summary
    successful = Enum.count(results, fn {_, status, _} -> status == :fixed end)
    already_ok = Enum.count(results, fn {_, status, _} -> status == :already_ok end)
    errors = Enum.count(results, fn {_, status, _} -> status == :error end)

    IO.puts("\n=== Summary ===")
    IO.puts("Files fixed: #{successful}")
    IO.puts("Already OK: #{already_ok}")
    IO.puts("Errors: #{errors}")

    # List errors if any
    if errors > 0 do
      IO.puts("\nErrors encountered:")
      results
      |> Enum.filter(fn {_, status, _} -> status == :error end)
      |> Enum.each(fn {file, _, msg} -> IO.puts("  #{file}: #{msg}") end)
    end

    IO.puts("\nDone!")
  end

  defp find_conflict_files do
    # Find files with use ExUnitProperties
    {output_eup, 0} = System.cmd("grep", [
      "-rl",
      "use ExUnitProperties",
      "test/"
    ], stderr_to_stdout: true)

    eup_files =
      output_eup
      |> String.trim()
      |> String.split("\n")
      |> Enum.filter(&(String.length(&1) > 0))

    # Filter to those that also have use PropCheck
    Enum.filter(eup_files, fn file ->
      case File.read(file) do
        {:ok, content} -> String.contains?(content, "use PropCheck")
        _ -> false
      end
    end)
  end

  defp fix_file(file) do
    IO.puts("Processing: #{file}")

    case File.read(file) do
      {:ok, content} ->
        # Check if it has `use ExUnitProperties` (not import)
        if Regex.match?(~r/^\s*use ExUnitProperties\s*$/m, content) do
          new_content =
            content
            # Replace `use ExUnitProperties` with import except
            |> String.replace(
              ~r/^\s*use ExUnitProperties\s*$/m,
              "  import ExUnitProperties, except: [property: 2, check: 2]"
            )
            # Replace bare `check all` with qualified version
            |> String.replace(
              ~r/(?<![.\w])check all(?=\s)/,
              "ExUnitProperties.check all"
            )
            # Fix potential double qualification
            |> String.replace(
              "ExUnitProperties.ExUnitProperties.check all",
              "ExUnitProperties.check all"
            )

          if new_content != content do
            case File.write(file, new_content) do
              :ok ->
                IO.puts("  ✓ Fixed")
                {file, :fixed, nil}

              {:error, reason} ->
                IO.puts("  ✗ Error writing: #{inspect(reason)}")
                {file, :error, "Write error: #{inspect(reason)}"}
            end
          else
            IO.puts("  - No changes needed")
            {file, :already_ok, nil}
          end
        else
          IO.puts("  - Already using import pattern")
          {file, :already_ok, nil}
        end

      {:error, reason} ->
        IO.puts("  ✗ Error reading: #{inspect(reason)}")
        {file, :error, "Read error: #{inspect(reason)}"}
    end
  end
end

# Run the fixer
UseExUnitPropertiesConflictFixer.run()
