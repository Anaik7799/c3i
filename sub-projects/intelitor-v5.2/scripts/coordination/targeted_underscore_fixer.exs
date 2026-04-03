#!/usr/bin/env elixir

defmodule TargetedUnderscoreFixer do
  @moduledoc """
  Targeted Underscore Parameter Fixer

  Fixes the specific pattern causing "undefined variable" errors:
  - Function parameters with underscore (_state, _alarm_event, etc.)
  - That are used in the function body without underscore

  Strategy:
  1. Find functions with underscored parameters
  2. Read function body
  3. Check if parameter used without underscore
  4. Remove underscore from parameter if used
  """

  def run do
    IO.puts("🔧 Targeted Underscore Parameter Fixer")
    IO.puts("=" |> String.duplicate(60))

    # Start with the file we know has issues
    files = [
      "lib/indrajaal/alarms/security_intelligence_engine.ex"
      # Add more files as needed
    ]

    files
    |> Enum.each(&fix_file/1)

    IO.puts("\n✅ Complete! Verify with compilation.")
  end

  defp fix_file(file_path) do
    IO.puts("\n📝 Processing: #{file_path}")

    content = File.read!(file_path)

    # Fix common underscore parameter patterns
    fixed = content
    |> fix_pattern(~r/defp (\w+)\(([^)]*?)_state([^)]*?)\) do/, "state")
    |> fix_pattern(~r/defp (\w+)\(([^)]*?)_alarm_event([^)]*?)\) do/, "alarm_event")
    |> fix_pattern(~r/defp (\w+)\(([^)]*?)_window([^)]*?)\) do/, "window")
    |> fix_pattern(~r/defp (\w+)\(([^)]*?)_alarm([^)]*?)\) do/, "alarm")
    |> fix_pattern(~r/defp (\w+)\(([^)]*?)_related_alarms([^)]*?)\) do/, "related_alarms")

    if content != fixed do
      File.write!(file_path, fixed)
      IO.puts("     ✅ Fixed underscore parameters")

      # Show what changed
      count_changes(content, fixed)
    else
      IO.puts("     ℹ️  No changes needed")
    end
  end

  defp fix_pattern(content, regex, param_name) do
    Regex.replace(regex, content, fn full_match, func_name, before_param, after_param ->
      # Extract function body to check if parameter is used
      case extract_function_body(content, func_name) do
        nil ->
          full_match

        body ->
          # Check if param_name (without underscore) is used in body
          param_patterns = [
            "#{param_name}.",
            "#{param_name}[",
            "#{param_name} ",
            "#{param_name})",
            "#{param_name},",
            "#{param_name}\n",
            " #{param_name}="
          ]

          is_used = Enum.any?(param_patterns, &String.contains?(body, &1))

          if is_used do
            # Remove underscore from parameter
            "defp #{func_name}(#{before_param}#{param_name}#{after_param}) do"
          else
            full_match
          end
      end
    end)
  end

  defp extract_function_body(content, func_name) do
    # Find the function definition and extract its body
    case Regex.run(~r/defp #{func_name}\([^)]*\) do(.*?)(?=\n  def|\n  defp|\nend\n|\z)/s, content) do
      [_full, body] -> body
      nil -> nil
    end
  end

  defp count_changes(old_content, new_content) do
    old_lines = String.split(old_content, "\n")
    new_lines = String.split(new_content, "\n")

    changes =
      Enum.zip(old_lines, new_lines)
      |> Enum.filter(fn {old, new} -> old != new end)
      |> length()

    if changes > 0 do
      IO.puts("     📊 Changed #{changes} lines")
    end
  end
end

TargetedUnderscoreFixer.run()