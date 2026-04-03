#!/usr/bin/env elixir

defmodule AEE.Cycle68SystematicErrorFixer do
  @moduledoc """
  AEE SOPv5.11 Cycle 6.8 Systematic Error Elimination Engine

  Fixes the highest frequency undefined variable errors identified in 1-compile.log:
  - _context (142 errors) → context
  - opts (98 errors) → __opts
  - __opts (87 errors) → opts (when actually used)
  - __tenant_id (75 errors) → tenant_id
  - data (67 errors) → appropriate context-based replacement

  Date: 2025-09-18 19:26:00 CEST
  Status: Emergency systematic fixing for compilation restoration
  """

  def main(args \\ []) do
    IO.puts("🎯 AEE SOPv5.11 Cycle 6.8: Systematic Error Elimination")
    IO.puts("📊 Target: Fix highest frequency undefined variable errors")

    case args do
      ["--analyze"] -> analyze_patterns()
      ["--fix-context"] -> fix_context_errors()
      ["--fix-opts"] -> fix_opts_errors()
      ["--fix-tenant"] -> fix_tenant_errors()
      ["--fix-data"] -> fix_data_errors()
      ["--comprehensive"] -> comprehensive_fix()
      _ -> show_help()
    end
  end

  defp analyze_patterns do
    IO.puts("\n🔍 Analyzing Error Patterns:")
    IO.puts("1. _context (142 errors) - underscored context variable being used")
    IO.puts("2. opts (98 errors) - missing underscore prefix")
    IO.puts("3. __opts (87 errors) - double underscore when used")
    IO.puts("4. __tenant_id (75 errors) - tenant parameter issues")
    IO.puts("5. data (67 errors) - generic data parameter issues")

    IO.puts("\n📋 Recommended Fix Order:")
    IO.puts("1. Fix _context errors (highest impact)")
    IO.puts("2. Fix opts/__opts confusion")
    IO.puts("3. Fix tenant_id parameter issues")
    IO.puts("4. Fix data parameter issues")
  end

  defp fix_context_errors do
    IO.puts("\n🔧 Fixing _context errors (142 instances)...")

    elixir_files = get_elixir_files()

    Enum.each(elixir_files, fn file ->
      content = File.read!(file)

      # Fix _context being used (should be context)
      new_content = String.replace(content, ~r/\b_context\b/, "context")

      if content != new_content do
        File.write!(file, new_content)
        IO.puts("✅ Fixed _context → context in #{file}")
      end
    end)

    IO.puts("✅ _context pattern fixes completed")
  end

  defp fix_opts_errors do
    IO.puts("\n🔧 Fixing opts/__opts confusion...")

    elixir_files = get_elixir_files()

    Enum.each(elixir_files, fn file ->
      content = File.read!(file)
      original_content = content

      # Pattern 1: opts used but not defined (add underscore to parameter)
      # Pattern 2: __opts defined but opts is used (remove underscore when used)

      # Fix undefined opts by checking if function has _opts or __opts parameter
      lines = String.split(content, "\n")

      new_lines = Enum.map_with_index(lines, fn {line, idx} ->
        cond do
          # If line uses opts but function has __opts parameter
          String.contains?(line, "opts") and !String.contains?(line, "__opts") ->
            check_function_parameter(lines, idx, line)

          true -> line
        end
      end)

      new_content = Enum.join(new_lines, "\n")

      if content != new_content do
        File.write!(file, new_content)
        IO.puts("✅ Fixed opts patterns in #{file}")
      end
    end)

    IO.puts("✅ opts pattern fixes completed")
  end

  defp fix_tenant_errors do
    IO.puts("\n🔧 Fixing __tenant_id errors...")

    elixir_files = get_elixir_files()

    Enum.each(elixir_files, fn file ->
      content = File.read!(file)

      # Fix __tenant_id being used (should be tenant_id)
      new_content = String.replace(content, ~r/\b__tenant_id\b/, "tenant_id")

      if content != new_content do
        File.write!(file, new_content)
        IO.puts("✅ Fixed __tenant_id → tenant_id in #{file}")
      end
    end)

    IO.puts("✅ __tenant_id pattern fixes completed")
  end

  defp fix_data_errors do
    IO.puts("\n🔧 Fixing data variable errors...")

    elixir_files = get_elixir_files()

    Enum.each(elixir_files, fn file ->
      content = File.read!(file)

      # This is more complex - need to analyze context
      # For now, look for common patterns where data is undefined

      # Pattern: data used in function but parameter is _data
      new_content = content
      |> String.replace(~r/(\bdata\b)(?=\s*\.)/, "_data")  # Replace data. with _data.
      |> String.replace(~r/\b_data\b(?=\s*[^.])/, "data")   # But keep data for other uses

      if content != new_content do
        File.write!(file, new_content)
        IO.puts("✅ Fixed data patterns in #{file}")
      end
    end)

    IO.puts("✅ data pattern fixes completed")
  end

  defp comprehensive_fix do
    IO.puts("\n🚀 AEE SOPv5.11 Comprehensive Error Elimination")

    fix_context_errors()
    fix_opts_errors()
    fix_tenant_errors()
    fix_data_errors()

    IO.puts("\n✅ Comprehensive systematic fixes completed")
    IO.puts("📋 Next step: Run compilation to validate fixes")
  end

  defp check_function_parameter(lines, current_idx, line) do
    # Look backwards to find function definition
    function_lines = Enum.take(lines, current_idx + 1) |> Enum.reverse()

    function_def = Enum.find(function_lines, fn l ->
      String.contains?(l, "def ") or String.contains?(l, "defp ")
    end)

    cond do
      function_def && String.contains?(function_def, "__opts") ->
        String.replace(line, ~r/\bopts\b/, "__opts")
      function_def && String.contains?(function_def, "_opts") ->
        String.replace(line, ~r/\bopts\b/, "_opts")
      true ->
        line
    end
  end

  defp get_elixir_files do
    Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")
  end

  defp show_help do
    IO.puts("""
    AEE SOPv5.11 Cycle 6.8 Systematic Error Elimination

    Usage:
      elixir cycle68_systematic_error_fixer.exs [option]

    Options:
      --analyze       Analyze error patterns and show fix strategy
      --fix-context   Fix _context errors (142 instances)
      --fix-opts      Fix opts/__opts confusion (185 instances)
      --fix-tenant    Fix __tenant_id errors (75 instances)
      --fix-data      Fix data variable errors (67 instances)
      --comprehensive Apply all fixes systematically

    Error Frequency Analysis:
      1. _context: 142 errors (highest priority)
      2. opts: 98 errors
      3. __opts: 87 errors
      4. __tenant_id: 75 errors
      5. data: 67 errors
    """)
  end
end

AEE.Cycle68SystematicErrorFixer.main(System.argv())