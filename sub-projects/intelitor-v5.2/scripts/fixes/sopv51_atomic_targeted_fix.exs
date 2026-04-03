#!/usr/bin/env elixir

defmodule SOPv51AtomicTargetedFix do
  @moduledoc """
  SOPv5.1 Targeted Atomic Fix for actions with change set_attribute
  """

  @spec execute() :: any()
  def execute do
    IO.puts("""
    🎯 SOPv5.1 TARGETED ATOMIC FIX
    =============================

    Fixing atomic warnings for actions with change functions...
    """)

    # Process all files in lib/
    files = Path.wildcard("lib/**/*.ex")

    results =
      files
      |> Enum.map(&((process_file / 1) |> Enum.filter(& &1.changed)))

    IO.puts("\n📊 RESULTS:")
    IO.puts("- Files processed: #{length(files)}")
    IO.puts("- Files fixed: #{length(results)}")
    IO.puts("- Total fixes applied: #{Enum.sum(Enum.map(results, & &1.fixes))}")

    results
  end

  @spec process_file(term()) :: term()
  defp process_file(file_path) do
    content = File.read!(file_path)
    original_content = content

    # Fix update actions that use change set_attribute
    content = fix_update_with_set_attribute(content)

    # Fix update actions with function changes
    content = fix_update_with_function_change(content)

    # Fix destroy actions with changes
    content = fix_destroy_with_change(content)

    # Count fixes
    fixes = count_fixes(original_content, content)
    changed = content != original_content

    if changed do
      File.write!(file_path, content)
      IO.puts("✅ Fixed #{file_path} (#{fixes} fixes)")
    end

    %{
      file: file_path,
      changed: changed,
      fixes: fixes
    }
  end

  @spec fix_update_with_set_attribute(term()) :: term()
  defp fix_update_with_set_attribute(content) do
    # Pattern: update action with change set_attribute but no __require_atomic?
    pattern = ~r/
      (update\s+:\w+\s+do\s*\n)          # update :action_name do
      ((?:(?!__require_atomic\?)           # not containing __require_atomic?
        (?:(?!update\s+:|destroy\s+:|create\s+:)  # not another action
          .*\n                           # any line
        )*?                              # minimal match
      ))
      (\s*change\s+set_attribute)        # change set_attribute
    /mx

    Regex.replace(pattern, content, fn _, start, middle, change ->
      start <> "      __require_atomic? false\n" <> middle <> change
    end)
  end

  @spec fix_update_with_function_change(term()) :: term()
  defp fix_update_with_function_change(content) do
    # Pattern: update action with change fn but no __require_atomic?
    pattern = ~r/
      (update\s+:\w+\s+do\s*\n)          # update :action_name do
      ((?:(?!__require_atomic\?)           # not containing __require_atomic?
        (?:(?!update\s+:|destroy\s+:|create\s+:)  # not another action
          .*\n                           # any line
        )*?                              # minimal match
      ))
      (\s*change\s+fn)                   # change fn
    /mx

    Regex.replace(pattern, content, fn _, start, middle, change ->
      start <> "      __require_atomic? false\n" <> middle <> change
    end)
  end

  @spec fix_destroy_with_change(term()) :: term()
  defp fix_destroy_with_change(content) do
    # Pattern: destroy action with change but no __require_atomic?
    pattern = ~r/
      (destroy\s+:\w+\s+do\s*\n)         # destroy :action_name do
      ((?:(?!__require_atomic\?)           # not containing __require_atomic?
        (?:(?!update\s+:|destroy\s+:|create\s+:)  # not another action
          .*\n                           # any line
        )*?                              # minimal match
      ))
      (\s*change\s+)                     # change
    /mx

    Regex.replace(pattern, content, fn _, start, middle, change ->
      start <> "      __require_atomic? false\n" <> middle <> change
    end)
  end

  @spec count_fixes(term(), term()) :: term()
  defp count_fixes(original, fixed) do
    original_count = Regex.scan(~r/__require_atomic\? false/, original |> length())
    fixed_count = Regex.scan(~r/__require_atomic\? false/, fixed |> length())
    fixed_count - original_count
  end
end

# Execute
SOPv51AtomicTargetedFix.execute()
