#!/usr/bin/env elixir

defmodule FixAllDuplicateRequireAtomic do
  @moduledoc """
  Comprehensive fix for all duplicate __require_atomic? false issues
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🛠️ COMPREHENSIVE DUPLICATE __require_atomic? FIX
    ============================================
    """

    files = Path.wildcard("lib/**/*.ex")

    results = files
    |> Enum.map(&process_file/1)
    |> Enum.filter(& &1.changed)

    IO.puts "\n📊 RESULTS:"
    IO.puts "- Files processed: #{length(files)}"
    IO.puts "- Files fixed: #{length(results)}"
    IO.puts "- Total fixes: #{Enum.sum(Enum.map(results, & &1.fixes))}"
  end

  @spec process_file(term()) :: term()
  defp process_file(file_path) do
    content = File.read!(file_path)

    # Fix the content
    {_fixed_content, _fixes} = fix_duplicate_require_atomic(content)

    changed = content != fixed_content

    if changed do
      File.write!(file_path, fixed_content)
      IO.puts "✅ Fixed #{file_path} (#{fixes} fixes)"
    end

    %{
      file: file_path,
      changed: changed,
      fixes: fixes
    }
  end

  @spec fix_duplicate_require_atomic(term()) :: term()
  defp fix_duplicate_require_atomic(content) do
    lines = String.split(content, "\n")

    # Process action blocks
    {_fixed_lines, _fixes} = process_lines(lines, [], 0, false, false)

    {Enum.join(fixed_lines, "\n"), fixes}
  end

  defp process_lines([], acc, fixes, _, _), do: {Enum.reverse(acc), fixes}

  defp process_lines([line | rest], acc, fixes, in_action, seen_require_atomic) do
    cond do
      # Start of action block
      Regex.match?(~r/^\s*(update|destroy|create)\s+:\w+\s+do\s*$/, line) ->
        process_lines(rest, [line | acc], fixes, true, false)

      # End of action block
      in_action and Regex.match?(~r/^\s*end\s*$/, line) ->
        process_lines(rest, [line | acc], fixes, false, false)

      # __require_atomic? line
      in_action and String.trim(line) == "__require_atomic? false" ->
        if seen_require_atomic do
          # Skip duplicate
          process_lines(rest, acc, fixes + 1, in_action, true)
        else
          # Keep first occurrence
          process_lines(rest, [line | acc], fixes, in_action, true)
        end

      # accept [] line resets the seen_require_atomic flag
      in_action and String.trim(line) == "accept []" ->
        process_lines(rest, [line | acc], fixes, in_action, seen_require_atomic)

      # Any other line
      true ->
        process_lines(rest, [line | acc], fixes, in_action, seen_require_atomic)
    end
  end
end

FixAllDuplicateRequireAtomic.execute()