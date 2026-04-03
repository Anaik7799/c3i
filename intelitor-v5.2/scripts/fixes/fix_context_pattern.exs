#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ContextPatternFixer do
  @moduledoc """
  Systematic fixer for _context parameter pattern issues
  """

  def fix_file(file_path) do
    IO.puts("🔧 Fixing __context parameter pattern in: #{file_path}")

    content = File.read!(file_path)

    # Fix function parameter from _context to __context
    updated_content = String.replace(content, ~r/(\s+defp\s+\w+\([^)]*?)_context(\)\s+do)/m, "\\1__context\\2")

    if content != updated_content do
      File.write!(file_path, updated_content)
      IO.puts("✅ Fixed __context parameter pattern in #{file_path}")
      true
    else
      IO.puts("ℹ️  No __context parameter patterns found in #{file_path}")
      false
    end
  end

  def run do
    file_path = "/home/an/dev/indrajaal-demo/lib/mix/tasks/demo/alarm_processing.ex"

    IO.puts("🎯 Systematic Context Parameter Pattern Fixer")
    IO.puts("=" |> String.duplicate(50))

    if fix_file(file_path) do
      IO.puts("\n✅ Successfully fixed all __context parameter patterns")
    else
      IO.puts("\n❌ No fixes applied")
    end
  end
end

ContextPatternFixer.run()