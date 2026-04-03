#!/usr/bin/env elixir

defmodule FinalComprehensiveUpdateFix do
  @moduledoc """
  Final comprehensive fix to remove ALL update :update blocks
  """

  @spec execute() :: any()
  def execute do
    IO.puts """
    🏁 FINAL COMPREHENSIVE UPDATE :UPDATE REMOVAL
    ============================================
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

    # More comprehensive pattern to match update :update with any content
    fixed_content = Regex.replace(
      ~r/\n*\s*update\s+:update\s+do\s*\n(?:(?!\s*end\s*\n).*\n)*?\s*end\s*/m,
      content,
      ""
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

FinalComprehensiveUpdateFix.execute()