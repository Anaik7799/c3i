#!/usr/bin/env elixir

defmodule RemoveDuplicateRequireAtomic do
  @moduledoc """
  Remove duplicate __require_atomic? false lines
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🧹 REMOVING DUPLICATE __require_atomic? false
    ==========================================
    """

    files = Path.wildcard("lib/**/*.ex")

    results = files
    |> Enum.map(&process_file/1)
    |> Enum.filter(& &1.changed)

    IO.puts "\n📊 RESULTS:"
    IO.puts "- Files processed: #{length(files)}"
    IO.puts "- Files fixed: #{length(results)}"
    IO.puts "- Total duplicates removed: #{Enum.sum(Enum.map(results, & &1.duplic
  end

  @spec process_file(term()) :: term()
  defp process_file(file_path) do
    content = File.read!(file_path)

    # Remove consecutive duplicate __require_atomic? false lines
    fixed_content = Regex.replace(
      ~r/(__require_atomic\? false\s*\n)(\s*__require_atomic\? false\s*\n)+/,
      content,
      "\\1"
    )

    duplicates_removed = count_duplicates_removed(content, fixed_content)
    changed = content != fixed_content

    if changed do
      File.write!(file_path, fixed_content)
      IO.puts "✅ Fixed #{file_path} (#{duplicates_removed} duplicates removed)"
    end

    %{
      file: file_path,
      changed: changed,
      duplicates_removed: duplicates_removed
    }
  end

  @spec count_duplicates_removed(term(), term()) :: term()
  defp count_duplicates_removed(original, fixed) do
    original_count = Regex.scan(~r/__require_atomic\? false/, original) |> length()
    fixed_count = Regex.scan(~r/__require_atomic\? false/, fixed) |> length()
    original_count - fixed_count
  end
end

RemoveDuplicateRequireAtomic.execute()
