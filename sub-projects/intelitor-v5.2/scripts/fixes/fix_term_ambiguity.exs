#!/usr/bin/env elixir

# Fix script for ambiguous term/0 import between PropCheck.BasicTypes and StreamData
# This script adds StreamData. prefix to term() calls in ExUnitProperties contexts
# to resolve the ambiguity error.

defmodule TermAmbiguityFixer do
  @moduledoc """
  Fixes ambiguous term/0 import errors in test files.

  The issue: Both PropCheck.BasicTypes and StreamData export term/0
  When both `use PropCheck` and `use ExUnitProperties` are used,
  the term/0 call becomes ambiguous.

  Solution: In ExUnitProperties contexts (check all, gen), use StreamData.term()
  """

  def run do
    IO.puts("🔧 Fixing ambiguous term/0 imports...")
    IO.puts("=" |> String.duplicate(60))

    # Find all test files that might have this issue
    test_files = Path.wildcard("test/**/*.exs")

    total_fixes =
      test_files
      |> Enum.map(&fix_file/1)
      |> Enum.filter(&(&1 != nil))
      |> Enum.reduce(0, fn {:fixed, count}, acc -> acc + count end)

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("✅ Total term() calls fixed: #{total_fixes}")
    IO.puts("✅ Fix completed!")
  end

  defp fix_file(file) do
    content = File.read!(file)

    # Check if this file uses both PropCheck and ExUnitProperties
    uses_both = String.contains?(content, "use PropCheck") and
                String.contains?(content, "use ExUnitProperties")

    if uses_both do
      # Fix term() calls in ExUnitProperties contexts
      # Pattern: term() that's NOT already prefixed with StreamData. or PropCheck.
      # We need to be careful to only fix term() used as a generator, not type specs

      # Fix pattern 1: term() in ExUnitProperties.check all context (inside <- generator assignments)
      # Pattern matches: `variable <- something(term())` or `map_of(atom(), term())`
      pattern1 = ~r/(<-\s*[^,\n]*?)(?<!StreamData\.)(?<!PropCheck\.BasicTypes\.)\bterm\(\)/

      # Fix pattern 2: term() in map_of, list_of, etc. generator functions
      pattern2 = ~r/(map_of\([^)]*?)(?<!StreamData\.)(?<!PropCheck\.BasicTypes\.)\bterm\(\)/
      pattern3 = ~r/(list_of\([^)]*?)(?<!StreamData\.)(?<!PropCheck\.BasicTypes\.)\bterm\(\)/

      new_content = content

      # Count matches before fixing
      matches1 = Regex.scan(pattern1, content) |> length()
      matches2 = Regex.scan(pattern2, content) |> length()
      matches3 = Regex.scan(pattern3, content) |> length()

      # Apply fixes
      new_content = Regex.replace(pattern1, new_content, fn _, prefix ->
        "#{prefix}StreamData.term()"
      end)

      new_content = Regex.replace(pattern2, new_content, fn _, prefix ->
        "#{prefix}StreamData.term()"
      end)

      new_content = Regex.replace(pattern3, new_content, fn _, prefix ->
        "#{prefix}StreamData.term()"
      end)

      # Also fix standalone term() used as generators (not in type specs)
      # This is tricky - we need to avoid @spec lines
      # Match term() that follows a <- or is inside generator function calls
      pattern4 = ~r/(\w+\s*<-\s*[^<\n]*?)(?<!StreamData\.)(?<!PropCheck\.BasicTypes\.)(?<!\.\s)\bterm\(\)(?![^\n]*::)/

      new_matches = Regex.scan(pattern4, new_content) |> length()
      new_content = Regex.replace(pattern4, new_content, fn _, prefix ->
        "#{prefix}StreamData.term()"
      end)

      total_matches = matches1 + matches2 + matches3 + new_matches

      if new_content != content do
        File.write!(file, new_content)
        IO.puts("✅ Fixed #{total_matches} term() calls in: #{file}")
        {:fixed, total_matches}
      else
        nil
      end
    else
      nil
    end
  end
end

TermAmbiguityFixer.run()
