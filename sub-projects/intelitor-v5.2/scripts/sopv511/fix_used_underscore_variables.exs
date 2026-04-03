#!/usr/bin/env elixir

defmodule UsedUnderscoreVariableFixer do
  @moduledoc """
  Fixes variables that have underscore prefix but are actually used.
  These generate warnings like "the underscored variable '_cluster' is used after being set"
  """

  def run do
    IO.puts("\n🔧 Fixing Used Underscore Variables")
    IO.puts("=" |> String.duplicate(50))

    # Find all Elixir files
    files = Path.wildcard("lib/**/*.ex")

    # Variables that are commonly used with underscore but shouldn't be
    problematic_vars = [
      "_cluster",
      "_alarm_id",
      "_user_id",
      "_tenant_id",
      "_params",
      "_opts",
      "_state",
      "_config",
      "_metadata"
    ]

    total_fixes = Enum.reduce(problematic_vars, 0, fn var, acc ->
      count = fix_variable_in_files(files, var)
      if count > 0 do
        IO.puts("✅ Fixed #{count} occurrences of #{var}")
      end
      acc + count
    end)

    IO.puts("\n📊 Total fixes applied: #{total_fixes}")
    IO.puts("=" |> String.duplicate(50))
  end

  defp fix_variable_in_files(files, var) do
    clean_var = String.replace_prefix(var, "_", "")

    Enum.reduce(files, 0, fn file, count ->
      content = File.read!(file)
      lines = String.split(content, "\n")

      {new_lines, file_fixes} = process_lines(lines, var, clean_var)

      if file_fixes > 0 do
        new_content = Enum.join(new_lines, "\n")
        File.write!(file, new_content)
        count + file_fixes
      else
        count
      end
    end)
  end

  defp process_lines(lines, var, clean_var) do
    Enum.map_reduce(lines, 0, fn line, acc ->
      # Check if this line uses the underscore variable (but not in a definition)
      if String.contains?(line, var) and is_usage_line?(line, var) do
        # Replace underscore variable with clean variable
        new_line = String.replace(line, var, clean_var)
        {new_line, acc + 1}
      else
        {line, acc}
      end
    end)
  end

  defp is_usage_line?(line, var) do
    # It's a usage line if:
    # 1. Variable appears in the line
    # 2. It's not a function parameter definition (defp func(_var))
    # 3. It's not a pattern match definition ({_var, data} = ...)
    # 4. It IS being used (in a function call, map access, etc.)

    cond do
      # Skip if it's a function definition with unused parameter
      String.match?(line, ~r/(defp?|def)\s+\w+\([^)]*#{Regex.escape(var)}[,)]/) ->
        false

      # Skip if it's a pattern match definition at start of line
      String.match?(line, ~r/^\s*[{(].*#{Regex.escape(var)}.*[})]?\s*=/) ->
        false

      # It's a usage if variable appears in:
      # - Function calls: func(var)
      # - Map/list operations: [var], %{key: var}
      # - String interpolation: "#{var}"
      # - Pipe operations: var |> func()
      String.match?(line, ~r/[(\[{,:=]\s*#{Regex.escape(var)}/) or
      String.match?(line, ~r/#\{#{Regex.escape(var)}\}/) or
      String.match?(line, ~r/#{Regex.escape(var)}\s*\|>/) or
      String.match?(line, ~r/#{Regex.escape(var)}\s*\./) ->
        true

      true ->
        false
    end
  end
end

UsedUnderscoreVariableFixer.run()