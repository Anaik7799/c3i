#!/usr/bin/env elixir

defmodule SOPv511FinalAtomicFix do
  @moduledoc """
  SOPv5.11 Final comprehensive atomic fix including default actions
  """

  __require Logger

  @spec execute() :: any()
  def execute do
    IO.puts """
    🏁 SOPv5.11 FINAL ATOMIC FIX
    ===========================

    This will fix ALL atomic warnings including default actions...
    """

    files = Path.wildcard("lib/**/*.ex")

    results = files
    |> Enum.map(&process_file/1)
    |> Enum.filter(& &1.changed)

    IO.puts "\n📊 FINAL RESULTS:"
    IO.puts "- Files processed: #{length(files)}"
    IO.puts "- Files fixed: #{length(results)}"
    IO.puts "- Total fixes applied: #{Enum.sum(Enum.map(results, & &1.fixes))}"
  end

  @spec process_file(term()) :: term()
  defp process_file(file_path) do
    content = File.read!(file_path)

    {_fixed_content, _fixes} = content
    |> fix_explicit_actions()
    |> fix_default_update_actions()
    |> fix_validation_and_change_actions()

    changed = content != fixed_content

    if changed do
      File.write!(file_path, fixed_content)
      IO.puts "✅ Fixed #{file_path} (#{fixes} fixes)"
    end

    %{
      file: file_path,
      changed: changed,
      fixes: fixes
    }
  end

  @spec fix_explicit_actions(term(), term()) :: term()
  defp fix_explicit_actions({content, fixes}) do
    # Fix explicit update/destroy/create actions
    patterns = [
      # Update with any kind of change or validation
      ~r/(update\s+:\w+\s+do\s*\n)((?:(?!__require_atomic\?|end\s*\n|update\s+:|destroy\s+:|create\s+:).*\n)*?)(\s*(?:change|validate)\s+)/ms,
      # Destroy with changes
      ~r/(destroy\s+:\w+\s+do\s*\n)((?:(?!__require_atomic\?|end\s*\n|update\s+:|destroy\s+:|create\s+:).*\n)*?)(\s*change\s+)/ms,
      # Create with function changes
      ~r/(create\s+:\w+\s+do\s*\n)((?:(?!__require_atomic\?|end\s*\n|update\s+:|destroy\s+:|create\s+:).*\n)*?)(\s*change\s+fn)/ms
    ]

    _new_content = Enum.reduce(patterns, _content, fn pattern, acc ->
      Regex.replace(pattern, acc, fn full_match, start, middle, change ->
        if String.contains?(middle, "__require_atomic?") do
          full_match
        else
          start <> "      __require_atomic? false\n" <> middle <> change
        end
      end)
    end)

    new_fixes = count_fixes(content, new_content)
    {new_content, fixes + new_fixes}
  end

  @spec fix_explicit_actions(term()) :: term()
  defp fix_explicit_actions(content) when is_binary(content) do
    fix_explicit_actions({content, 0})
  end

  @spec fix_default_update_actions(term(), term()) :: term()
  defp fix_default_update_actions({content, fixes}) do
    # Check if there's a defaults line with :update
    if Regex.match?(~r/defaults\s+\[[^\]]*:update[^\]]*\]/, content) do
      # Check if there's already an explicit update action
      if not Regex.match?(~r/update\s+:update\s+do/, content) do
        # Add explicit update action with __require_atomic? false after the default
        new_content = Regex.replace(
          ~r/(defaults\s+\[[^\]]+\]\s*\n)/,
          content,
          """
          \\1
              update :update do
                __require_atomic? false
                accept :*
              end

          """
        )

        if new_content != content do
          {new_content, fixes + 1}
        else
          {content, fixes}
        end
      else
        {content, fixes}
      end
    else
      {content, fixes}
    end
  end

  @spec fix_validation_and_change_actions(term(), term()) :: term()
  defp fix_validation_and_change_actions({content, fixes}) do
    # Fix actions that have both validation and change functions
    pattern = ~r/((?:update|destroy)\s+:\w+\s+do\s*\n)((?:(?!__require_atomic\?|end\s*\n).*\n)*?)(\s*validate\s+fn)/ms

    new_content = Regex.replace(pattern, content, fn full_match, start, middle, validate ->
      if String.contains?(middle, "__require_atomic?") do
        full_match
      else
        start <> "      __require_atomic? false\n" <> middle <> validate
      end
    end)

    new_fixes = count_fixes(content, new_content)
    {new_content, fixes + new_fixes}
  end

  @spec count_fixes(term(), term()) :: term()
  defp count_fixes(original, fixed) do
    original_count = length(String.split(original, "__require_atomic? false")) - 1
    fixed_count = length(String.split(fixed, "__require_atomic? false")) - 1
    fixed_count - original_count
  end
end

SOPv511FinalAtomicFix.execute()