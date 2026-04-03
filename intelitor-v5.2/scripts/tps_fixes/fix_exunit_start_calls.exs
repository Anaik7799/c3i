#!/usr/bin/env elixir

# TPS 5-Level RCA Fix: Remove ExUnit.start() calls from test files
# Level 1 Symptom: "cannot add module... after suite starts running" error
# Level 5 Design: Systematic removal of duplicate ExUnit.start() calls

defmodule TPSExUnitStartFixer do
  @moduledoc """
  TPS 5-Level RCA Solution: Fix ExUnit.start() duplicate calls

  Agent: Worker-Systematic Test File Cleaner
  Framework: Patient Mode with TPS methodology
  """

  @spec fix_all_files() :: any()
  def fix_all_files do
    IO.puts "🔧 TPS Fix: Removing duplicate ExUnit.start() calls"
    IO.puts "🤖 Agent: Worker-Systematic Test File Cleaner"
    IO.puts "⏱️ Started: #{DateTime.utc_now()}"

    # Get all test files with ExUnit.start() except test_helper.exs
    test_files = Path.wildcard("test/**/*.exs")
    |> Enum.filter(&(&1 != "test/test_helper.exs"))
    |> Enum.filter(&has_exunit_start?/1)

    IO.puts "📊 Found #{length(test_files)} files with ExUnit.start() calls to fix

    Enum.each(test_files, &fix_file/1)

    IO.puts "✅ TPS Fix Complete: All duplicate ExUnit.start() calls removed"
    IO.puts "📈 Files processed: #{length(test_files)}"
  end

  @spec has_exunit_start?(term()) :: term()
  defp has_exunit_start?(file_path) do
    File.read!(file_path)
    |> String.contains?("ExUnit.start()")
  end

  @spec fix_file(term()) :: term()
  defp fix_file(file_path) do
    IO.puts "  🔧 Fixing: #{file_path}"

    content = File.read!(file_path)

    # Remove ExUnit.start() lines and any preceding comments
    fixed_content = content
    |> String.split("\n")
    |> remove_exunit_start_lines()
    |> Enum.join("\n")

    File.write!(file_path, fixed_content)
    IO.puts "  ✅ Fixed: #{file_path}"
  end

  @spec remove_exunit_start_lines(term()) :: term()
  defp remove_exunit_start_lines(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _idx} ->
      not (String.contains?(line, "ExUnit.start()") or
           String.trim(line) == "# Start ExUnit first" or
           (String.trim(line) == ""
    and String.contains?(Enum.at(lines, _idx + 1) || "", "ExUnit.start()")))
    end)
    |> Enum.map(fn {line, _idx} -> line end)
  end
end

# Execute the fix
TPSExUnitStartFixer.fix_all_files()
