#!/usr/bin/env elixir

defmodule RemoveDuplicateUpdateActions do
  @moduledoc """
  Remove duplicate update :update actions that were added by mistake
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🧹 REMOVING DUPLICATE update :update ACTIONS
    ===========================================
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

    # Check if file has both "update :update" and other named update actions
    has_update_update = Regex.match?(~r/update\s+:update\s+do/, content)
    has_other_updates = Regex.match?(~r/update\s+:(?!update)\w+\s+do/, content)

    if has_update_update and has_other_updates do
      # Remove the generic update :update action
      fixed_content = Regex.replace(
        ~r/\n\s*update\s+:update\s+do\s*\n\s*__require_atomic\?\s+false\s*\n\s*accept\s+:\*\s*\n\s*end\s*\n/,
        content,
        "\n"
      )

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
end

RemoveDuplicateUpdateActions.execute()