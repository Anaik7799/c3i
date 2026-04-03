#!/usr/bin/env elixir

defmodule RemoveAllUpdateUpdate do
  @moduledoc """
  Remove ALL update :update blocks from files
  """

  @spec execute() :: any()
  def execute do
    IO.puts("""
    🏁 REMOVING ALL update :update BLOCKS
    ====================================
    """)

    # Get all files that have update :update
    files =
      Path.wildcard(
        "lib/**/*.ex"
        |> Enum.filter(fn file ->
          content = File.read!(file)
          String.contains?(content, "update :update do")
        end)
      )

    IO.puts("Found #{length(files)} files with 'update :update' blocks")

    fixed_count =
      files
      |> Enum.map(&((remove_update_update / 1) |> Enum.count(& &1)))

    IO.puts("\n✅ Fixed #{fixed_count} files")
  end

  @spec remove_update_update(term()) :: term()
  defp remove_update_update(file_path) do
    content = File.read!(file_path)

    # Remove the update :update block
    fixed_content =
      Regex.replace(
        ~r/\n*\s*update\s+:update\s+do\s*\n\s*__require_atomic\?\s+false\s*\n\s*accept\s+:\*\s*\n\s*end\s*/,
        content,
        ""
      )

    if fixed_content != content do
      File.write!(file_path, fixed_content)
      IO.puts("✅ Fixed #{file_path}")
      true
    else
      false
    end
  end
end

RemoveAllUpdateUpdate.execute()
