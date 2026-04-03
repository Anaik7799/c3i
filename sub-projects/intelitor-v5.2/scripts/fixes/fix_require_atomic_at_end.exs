#!/usr/bin/env elixir

defmodule FixRequireAtomicAtEnd do
  @moduledoc """
  Fix __require_atomic? false that appears at the end of action blocks
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🔧 FIXING __require_atomic? AT END OF BLOCKS
    =========================================
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

    # Remove __require_atomic? false that appears right before end
    fixed_content = Regex.replace(
      ~r/(\s+)__require_atomic\? false\s*\n(\s*end)/m,
      content,
      "\\1\\2"
    )

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
end

FixRequireAtomicAtEnd.execute()