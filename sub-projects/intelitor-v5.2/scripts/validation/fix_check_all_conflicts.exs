#!/usr/bin/env elixir

# Fix PropCheck/ExUnitProperties `check all` conflicts
#
# Problem: Files that use both PropCheck and ExUnitProperties exclude `check: 2`
#          from the ExUnitProperties import to avoid conflict with PropCheck.
#          However, this breaks `check all` syntax which needs ExUnitProperties.check
#
# Solution: Replace unqualified `check all` with `ExUnitProperties.check all`
#           in files that have the `except: [property: 2, check: 2]` pattern.

defmodule CheckAllConflictFixer do
  @moduledoc """
  Fixes check all conflicts by replacing unqualified `check all` with
  `ExUnitProperties.check all` in files that exclude check: 2 from import.
  """

  def run do
    IO.puts("=== PropCheck/ExUnitProperties Check All Conflict Fixer ===\n")

    # Find files with the problematic pattern
    files_with_except = find_files_with_except_pattern()
    IO.puts("Found #{length(files_with_except)} files with `except: [property: 2, check: 2]` pattern")

    # Filter to only files that also have unqualified check all
    files_needing_fix =
      files_with_except
      |> Enum.filter(&has_unqualified_check_all?/1)

    IO.puts("Found #{length(files_needing_fix)} files needing fix (have unqualified `check all`)\n")

    # Fix each file
    results = Enum.map(files_needing_fix, &fix_file/1)

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

  defp find_files_with_except_pattern do
    {output, 0} = System.cmd("grep", [
      "-rl",
      "except:.*check: 2",
      "test/"
    ], stderr_to_stdout: true)

    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.filter(&(String.length(&1) > 0))
  end

  defp has_unqualified_check_all?(file) do
    case File.read(file) do
      {:ok, content} ->
        # Match `check all` that is NOT preceded by `ExUnitProperties.`
        # We use negative lookbehind in regex
        Regex.match?(~r/(?<!ExUnitProperties\.)check all/, content)

      {:error, _} ->
        false
    end
  end

  defp fix_file(file) do
    IO.puts("Processing: #{file}")

    case File.read(file) do
      {:ok, content} ->
        # Check if there are unqualified check all patterns
        if Regex.match?(~r/(?<!ExUnitProperties\.)check all/, content) do
          # Replace unqualified `check all` with `ExUnitProperties.check all`
          # We need to be careful not to double-qualify already qualified ones

          # Pattern: Match `check all` that is NOT immediately after a dot
          # This handles cases like:
          #   - `check all` at start of line (with optional whitespace)
          #   - `check all` after parenthesis or other non-dot characters

          new_content =
            content
            # Replace `check all` that's not after a dot or after ExUnitProperties
            |> String.replace(
              ~r/(?<![.\w])check all(?=\s)/,
              "ExUnitProperties.check all"
            )

          # Double check we didn't create double qualification
          new_content = String.replace(
            new_content,
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
          IO.puts("  - Already OK")
          {file, :already_ok, nil}
        end

      {:error, reason} ->
        IO.puts("  ✗ Error reading: #{inspect(reason)}")
        {file, :error, "Read error: #{inspect(reason)}"}
    end
  end
end

# Run the fixer
CheckAllConflictFixer.run()
