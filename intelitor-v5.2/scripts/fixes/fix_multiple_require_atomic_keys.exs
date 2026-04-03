#!/usr/bin/env elixir

defmodule FixMultipleRequireAtomicKeys do
  @moduledoc """
  Fix multiple __require_atomic? keys in action blocks
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🔧 FIXING MULTIPLE __require_atomic? KEYS
    ======================================
    """

    files = Path.wildcard("lib/**/*.ex")

    results = files
    |> Enum.map(&process_file/1)
    |> Enum.filter(& &1.changed)

    IO.puts "\n📊 RESULTS:"
    IO.puts "- Files processed: #{length(files)}"
    IO.puts "- Files fixed: #{length(results)}"
  end

  @spec process_file(term()) :: term()
  defp process_file(file_path) do
    content = File.read!(file_path)

    # Fix actions that have multiple __require_atomic? in the same block
    fixed_content = fix_multiple_require_atomic_in_actions(content)

    changed = content != fixed_content

    if changed do
      File.write!(file_path, fixed_content)
      IO.puts "✅ Fixed #{file_path}"
    end

    %{
      file: file_path,
      changed: changed
    }
  end

  @spec fix_multiple_require_atomic_in_actions(term()) :: term()
  defp fix_multiple_require_atomic_in_actions(content) do
    # Split into lines for processing
    lines = String.split(content, "\n")

    # Process lines to remove duplicate __require_atomic? within action blocks
    {_fixed_lines, __} = Enum.reduce(lines, {[], nil}, fn line, {acc, last_line} ->
      cond do
        # Skip duplicate __require_atomic? lines
        String.trim(line) == "__require_atomic? false" and
        last_line != nil and String.trim(last_line) == "__require_atomic? false" ->
          {acc, line}

        # Keep the line
        true ->
          {acc ++ [line], line}
      end
    end)

    Enum.join(fixed_lines, "\n")
  end
end

FixMultipleRequireAtomicKeys.execute()