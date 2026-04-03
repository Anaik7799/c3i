#!/usr/bin/env elixir

defmodule DirectStateErrorFixer do
  @moduledoc """
  Direct State Error Fixer

  Fixes the specific pattern causing "undefined variable 'state'" errors:
  - Functions that have parameters like `_state` but the body tries to use `state`
  - Stub functions with all parameters underscored that are called by other functions
  """

  def run do
    IO.puts("🔧 Direct State Error Fixer")
    IO.puts("=" |> String.duplicate(60))

    # Fix the specific file with most errors
    fix_file("lib/indrajaal/alarms/security_intelligence_engine.ex")

    IO.puts("\n✅ Complete! Run compilation to verify fixes.")
  end

  defp fix_file(file_path) do
    IO.puts("\n📝 Processing: #{file_path}")

    content = File.read!(file_path)

    # Fix pattern 1: Stub functions with all underscored parameters
    # These are functions that don't use their parameters but other functions expect to call them
    fixed = content
    |> fix_stub_functions()

    if content != fixed do
      File.write!(file_path, fixed)
      IO.puts("     ✅ Fixed underscore parameters")
    else
      IO.puts("     ℹ️  No changes needed")
    end
  end

  defp fix_stub_functions(content) do
    # Pattern: defp function_name(_param1, _param2, _param3) do
    # These are stub functions that should have normal parameters
    # since they're called by other functions that pass actual values

    lines = String.split(content, "\n")

    lines
    |> Enum.map(fn line ->
      # Check if this is a stub function definition with all underscored params
      if Regex.match?(~r/^\s*defp\s+\w+\([^)]*_\w+[^)]*\)\s+do\s*$/, line) do
        # Check if it's followed by an empty implementation or return value
        # If so, remove underscores from parameters
        Regex.replace(
          ~r/\b_(\w+)/,
          line,
          fn _, param_name ->
            # Remove underscore from parameter names
            param_name
          end
        )
      else
        line
      end
    end)
    |> Enum.join("\n")
  end
end

DirectStateErrorFixer.run()