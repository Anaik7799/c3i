#!/usr/bin/env elixir

defmodule ContextSafetyConstraintsFixer do
  @moduledoc """
  Fix _context parameter pattern in STAMP safety constraints file
  """

  def fix_file do
    file_path = "/home/an/dev/indrajaal-demo/lib/mix/tasks/stamp/safety_constraints.ex"
    IO.puts("🔧 Fixing __context parameter pattern in: #{file_path}")

    content = File.read!(file_path)

    # Fix function parameter from _context to __context for functions that use __context
    updated_content =
      content
      |> String.replace(~r/(defp\s+validate_execution_safety\()_context(\)\s+do)/m, "\\1__context\\2")
      |> String.replace(~r/(defp\s+validate_testing_safety\()_context(\)\s+do)/m, "\\1__context\\2")
      |> String.replace(~r/(defp\s+validate_data_safety\()_context(\)\s+do)/m, "\\1__context\\2")

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
    IO.puts("🎯 Systematic Context Parameter Pattern Fixer for STAMP Safety Constraints")
    IO.puts("=" |> String.duplicate(70))

    if fix_file() do
      IO.puts("\n✅ Successfully fixed all __context parameter patterns")
    else
      IO.puts("\n❌ No fixes applied")
    end
  end
end

ContextSafetyConstraintsFixer.run()