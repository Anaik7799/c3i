#!/usr/bin/env elixir

defmodule FinalUpdateCleanup do
  @moduledoc """
  Final cleanup of all duplicate update :update actions
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🏁 FINAL UPDATE ACTION CLEANUP
    ==============================
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

    # Only remove update :update if there are other update actions
    if has_multiple_update_actions?(content) do
      fixed_content = remove_update_update(content)

      if fixed_content != content do
        File.write!(file_path, fixed_content)
        IO.puts "✅ Fixed #{file_path}"
        %{file: file_path, changed: true}
      else
        %{file: file_path, changed: false}
      end
    else
      %{file: file_path, changed: false}
    end
  end

  @spec has_multiple_update_actions?(term()) :: term()
  defp has_multiple_update_actions?(content) do
    # Count update actions
    update_matches = Regex.scan(~r/update\s+:\w+\s+do/, content)
    length(update_matches) > 1
  end

  @spec remove_update_update(term()) :: term()
  defp remove_update_update(content) do
    # Remove update :update blocks including any surrounding blank lines
    Regex.replace(
      ~r/\n*\s*update\s+:update\s+do\s*\n\s*__require_atomic\?\s+false\s*\n\s*accept\s+:\*\s*\n\s*end\s*\n*/,
      content,
      "\n"
    )
  end
end

FinalUpdateCleanup.execute()