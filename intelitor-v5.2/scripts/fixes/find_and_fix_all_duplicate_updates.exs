#!/usr/bin/env elixir

defmodule FindAndFixAllDuplicateUpdates do
  @moduledoc """
  Find and fix ALL files with duplicate update :update actions
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🔍 FINDING AND FIXING ALL DUPLICATE update :update ACTIONS
    =========================================================
    """

    files = Path.wildcard("lib/**/*.ex")

    # First, identify all files with the generic update :update
    files_with_update_update = files
    |> Enum.filter(fn file ->
      content = File.read!(file)
      String.contains?(content, "update :update do")
    end)

    IO.puts "Found #{length(files_with_update_update)} files with 'update :update

    # Now check which ones also have other update actions
    results = files_with_update_update
    |> Enum.map(&check_and_fix_file/1)
    |> Enum.filter(& &1.should_fix)

    IO.puts "\n📊 RESULTS:"
    IO.puts "- Files with update :update: #{length(files_with_update_update)}"
    IO.puts "- Files that need fixing: #{length(results)}"

    # Fix the files
    fixed = Enum.map(results, &fix_file/1)

    IO.puts "- Files fixed: #{length(fixed)}"
  end

  @spec check_and_fix_file(term()) :: term()
  defp check_and_fix_file(file_path) do
    content = File.read!(file_path)

    # Count all update actions
    update_matches = Regex.scan(~r/update\s+:(\w+)\s+do/, content)
    _update_names = Enum.map(update_matches, fn [_, name] -> name end)

    has_update_update = "update" in update_names
    has_other_updates = length(update_names) > 1 and Enum.any?(update_names, & &1 != "update")

    %{
      file: file_path,
      update_count: length(update_names),
      has_update_update: has_update_update,
      has_other_updates: has_other_updates,
      should_fix: has_update_update and has_other_updates
    }
  end

  @spec fix_file(map()) :: term()
  defp fix_file(%{file: file_path}) do
    content = File.read!(file_path)

    # Remove the update :update block
    fixed_content = Regex.replace(
      ~r/\n*\s*update\s+:update\s+do\s*\n\s*__require_atomic\?\s+false\s*\n\s*accept\s+:\*\s*\n\s*end\s*\n*/,
      content,
      "\n"
    )

    if fixed_content != content do
      File.write!(file_path, fixed_content)
      IO.puts "✅ Fixed #{file_path}"
    end

    file_path
  end
end

FindAndFixAllDuplicateUpdates.execute()
end
