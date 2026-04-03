#!/usr/bin/env elixir

# Fix double-underscore variables that are actually used
# Pattern: __variable_name is used but marked with double underscore

defmodule DoubleUnderscoreFixer do
  def run do
    IO.puts("\n🔧 Fixing Double-Underscore Variable Usage Issues...")
    IO.puts("=" |> String.duplicate(80))

    # Common double-underscore variables that are used
    variables = [
      "__user_id",
      "__tenant_id",
      "__params_hash",
      "__user_role",
      "__required_role",
      "__requested_tenant",
      "__user_score",
      "__user_responsiveness",
      "__event_score",
      "__user_preferred_hours",
      "__user_hours_set"
    ]

    # Get all Elixir files
    files = Path.wildcard("lib/**/*.ex")

    Enum.each(variables, fn var ->
      IO.puts("\n📋 Processing: #{var}")
      count = fix_variable(files, var)
      IO.puts("  ✅ Fixed #{count} occurrences")
    end)

    IO.puts("\n✨ Complete!")
  end

  defp fix_variable(files, var) do
    # Remove leading underscores to get clean variable name
    clean_var = String.replace_prefix(var, "__", "")

    Enum.reduce(files, 0, fn file, count ->
      content = File.read!(file)

      # Replace double-underscore variable with single clean name
      new_content = String.replace(content, var, clean_var)

      if new_content != content do
        File.write!(file, new_content)
        occurrences = length(String.split(content, var)) - 1
        count + occurrences
      else
        count
      end
    end)
  end
end

DoubleUnderscoreFixer.run()