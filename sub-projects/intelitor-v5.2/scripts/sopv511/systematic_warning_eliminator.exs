#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SystematicWarningEliminator do
  @moduledoc """
  SOPv5.11 Systematic Warning Elimination using 50-Agent Architecture

  This script implements a systematic approach to eliminate all 233 compilation warnings
  using the SOPv5.11 cybernetic framework with agent coordination.

  Patterns identified:
  1. Unused variables needing underscore prefix
  2. Underscored variables being used (remove underscore)
  3. Unused functions needing removal or @doc false
  """

  def main(args) do
    case args do
      ["--analyze"] -> analyze_warnings()
      ["--fix-batch", batch_num] -> fix_warning_batch(String.to_integer(batch_num))
      ["--fix-all"] -> fix_all_warnings()
      ["--status"] -> show_status()
      _ -> show_help()
    end
  end

  def analyze_warnings do
    IO.puts("🔍 Analyzing 233 compilation warnings...")

    # Read compilation log
    log_content = File.read!("compilation-status-check.log")
    warnings = extract_warnings(log_content)

    # Categorize warnings by pattern
    patterns = categorize_warnings(warnings)

    IO.puts("\n📊 Warning Pattern Analysis:")
    Enum.each(patterns, fn {pattern, count} ->
      IO.puts("  #{pattern}: #{count} warnings")
    end)

    # Generate fix strategy
    generate_fix_strategy(patterns)
  end

  def fix_warning_batch(batch_num) do
    IO.puts("🔧 Fixing warning batch #{batch_num}...")

    log_content = File.read!("compilation-status-check.log")
    warnings = extract_warnings(log_content)

    # Process in batches of 25 (as per CLAUDE.md requirements)
    batch_size = 25
    batch_warnings = warnings
    |> Enum.with_index()
    |> Enum.filter(fn {_warning, index} ->
      index >= (batch_num - 1) * batch_size and index < batch_num * batch_size
    end)
    |> Enum.map(fn {warning, _index} -> warning end)

    IO.puts("Processing #{length(batch_warnings)} warnings in batch #{batch_num}")

    # Apply systematic fixes
    Enum.each(batch_warnings, fn warning ->
      apply_systematic_fix(warning)
    end)

    IO.puts("✅ Batch #{batch_num} complete. Run compilation to verify fixes.")
  end

  def fix_all_warnings do
    IO.puts("🚀 Starting systematic warning elimination using SOPv5.11 methodology...")

    log_content = File.read!("compilation-status-check.log")
    warnings = extract_warnings(log_content)

    # Calculate number of batches needed
    batch_size = 25
    total_batches = ceil(length(warnings) / batch_size)

    IO.puts("📋 Processing #{length(warnings)} warnings in #{total_batches} batches")

    # Process each batch systematically
    1..total_batches
    |> Enum.each(fn batch_num ->
      IO.puts("\n🔄 Processing batch #{batch_num}/#{total_batches}")
      fix_warning_batch(batch_num)

      # Test compilation after each batch (as per CLAUDE.md requirements)
      IO.puts("⚡ Testing compilation after batch #{batch_num}...")
      {result, _} = System.cmd("mix", ["compile"], stderr_to_stdout: true)

      if String.contains?(result, "error:") do
        IO.puts("❌ Compilation failed after batch #{batch_num}")
        IO.puts("🔍 Analyzing errors...")
        IO.puts(result)
        System.halt(1)
      else
        IO.puts("✅ Batch #{batch_num} compilation successful")
      end
    end)

    IO.puts("\n🎯 All batches processed. Running final compilation check...")
    final_compilation_check()
  end

  def show_status do
    if File.exists?("compilation-status-check.log") do
      {output, _} = System.cmd("grep", ["-c", "warning:", "compilation-status-check.log"])
      warning_count = String.trim(output) |> String.to_integer()

      IO.puts("📊 Current Status:")
      IO.puts("  Warnings remaining: #{warning_count}")
      IO.puts("  Target: 0 warnings (ZERO TOLERANCE POLICY)")

      if warning_count == 0 do
        IO.puts("✅ ZERO WARNINGS ACHIEVED!")
      else
        IO.puts("⚠️ #{warning_count} warnings need elimination")
      end
    else
      IO.puts("❌ No compilation log found. Run compilation first.")
    end
  end

  defp extract_warnings(log_content) do
    log_content
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&String.trim/1)
  end

  defp categorize_warnings(warnings) do
    categorized = warnings
    |> Enum.reduce(%{"unused_variable" => 0, "underscored_variable_used" => 0, "unused_function" => 0, "other" => 0}, fn warning, acc ->
      cond do
        String.contains?(warning, "variable") and String.contains?(warning, "is unused") ->
          Map.update!(acc, "unused_variable", &(&1 + 1))

        String.contains?(warning, "underscored variable") and String.contains?(warning, "is used after being set") ->
          Map.update!(acc, "underscored_variable_used", &(&1 + 1))

        String.contains?(warning, "function") and String.contains?(warning, "is unused") ->
          Map.update!(acc, "unused_function", &(&1 + 1))

        true ->
          Map.update!(acc, "other", &(&1 + 1))
      end
    end)

    categorized
  end

  defp generate_fix_strategy(patterns) do
    IO.puts("\n🎯 SOPv5.11 Fix Strategy:")
    IO.puts("  1. Fix unused variables (add underscore prefix)")
    IO.puts("  2. Fix underscored variables being used (remove underscore)")
    IO.puts("  3. Remove or annotate unused functions")
    IO.puts("  4. Validate each batch with compilation")

    total_warnings = Map.values(patterns) |> Enum.sum()
    batches_needed = ceil(total_warnings / 25)

    IO.puts("\n📋 Execution Plan:")
    IO.puts("  Total warnings: #{total_warnings}")
    IO.puts("  Batches needed: #{batches_needed}")
    IO.puts("  Batch size: 25 warnings max")
    IO.puts("  Estimated time: #{batches_needed * 2} minutes")
  end

  defp apply_systematic_fix(warning) do
    cond do
      String.contains?(warning, "variable") and String.contains?(warning, "is unused") ->
        fix_unused_variable(warning)

      String.contains?(warning, "underscored variable") and String.contains?(warning, "is used after being set") ->
        fix_underscored_variable(warning)

      String.contains?(warning, "function") and String.contains?(warning, "is unused") ->
        fix_unused_function(warning)

      true ->
        IO.puts("⚠️ Unknown pattern: #{warning}")
    end
  end

  defp fix_unused_variable(warning) do
    # Extract file path and variable name from warning
    case extract_file_and_variable(warning) do
      {file_path, variable_name, line_num} ->
        IO.puts("🔧 Fixing unused variable #{variable_name} in #{file_path}:#{line_num}")

        # Read file content
        content = File.read!(file_path)

        # Apply fix: add underscore prefix
        fixed_content = content
        |> String.replace(~r/\b#{Regex.escape(variable_name)}\b/, "_#{variable_name}")

        # Write back
        File.write!(file_path, fixed_content)
        IO.puts("✅ Fixed unused variable #{variable_name}")

      nil ->
        IO.puts("⚠️ Could not extract file info from: #{warning}")
    end
  end

  defp fix_underscored_variable(warning) do
    case extract_file_and_variable(warning) do
      {file_path, variable_name, line_num} ->
        IO.puts("🔧 Removing underscore from #{variable_name} in #{file_path}:#{line_num}")

        content = File.read!(file_path)

        # Remove underscore prefix
        new_name = String.replace_prefix(variable_name, "_", "")
        fixed_content = content
        |> String.replace(variable_name, new_name)

        File.write!(file_path, fixed_content)
        IO.puts("✅ Fixed underscored variable #{variable_name} -> #{new_name}")

      nil ->
        IO.puts("⚠️ Could not extract file info from: #{warning}")
    end
  end

  defp fix_unused_function(warning) do
    case extract_file_and_function(warning) do
      {file_path, function_name, line_num} ->
        IO.puts("🔧 Fixing unused function #{function_name} in #{file_path}:#{line_num}")

        content = File.read!(file_path)

        # Add @doc false annotation before function
        lines = String.split(content, "\n")

        fixed_lines = lines
        |> Enum.with_index()
        |> Enum.map(fn {line, index} ->
          if String.contains?(line, "def #{function_name}") or String.contains?(line, "defp #{function_name}") do
            if index > 0 and not String.contains?(Enum.at(lines, index - 1), "@doc") do
              "  @doc false\n#{line}"
            else
              line
            end
          else
            line
          end
        end)
        |> Enum.join("\n")

        File.write!(file_path, fixed_lines)
        IO.puts("✅ Added @doc false to unused function #{function_name}")

      nil ->
        IO.puts("⚠️ Could not extract function info from: #{warning}")
    end
  end

  defp extract_file_and_variable(warning) do
    # Read the compilation log to get the full warning context
    log_content = File.read!("compilation-status-check.log")

    # Find this warning and its following lines to get file path
    lines = String.split(log_content, "\n")
    warning_index = Enum.find_index(lines, &(&1 == "    #{warning}"))

    if warning_index do
      # Look for the file path in the next few lines (usually 4-6 lines after)
      file_line = lines
      |> Enum.slice((warning_index + 1)..(warning_index + 10))
      |> Enum.find(&String.contains?(&1, "└─"))

      if file_line do
        # Extract variable name from warning
        variable_match = Regex.run(~r/variable "([^"]+)"/, warning)
        # Extract file path and line from the └─ line
        file_match = Regex.run(~r/└─ ([^:]+):(\d+)/, file_line)

        if variable_match && file_match do
          [_, variable] = variable_match
          [_, file, line] = file_match
          {file, variable, line}
        else
          nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  defp extract_file_and_function(warning) do
    # Similar approach for functions
    log_content = File.read!("compilation-status-check.log")
    lines = String.split(log_content, "\n")
    warning_index = Enum.find_index(lines, &(&1 == "     #{warning}"))

    if warning_index do
      file_line = lines
      |> Enum.slice((warning_index + 1)..(warning_index + 10))
      |> Enum.find(&String.contains?(&1, "└─"))

      if file_line do
        function_match = Regex.run(~r/function ([^\/]+)\/\d+/, warning)
        file_match = Regex.run(~r/└─ ([^:]+):(\d+)/, file_line)

        if function_match && file_match do
          [_, function] = function_match
          [_, file, line] = file_match
          {file, function, line}
        else
          nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  defp final_compilation_check do
    IO.puts("🎯 Running final compilation check...")

    {result, exit_code} = System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true)

    if exit_code == 0 do
      IO.puts("🎉 SUCCESS: Zero warnings achieved!")
      IO.puts("✅ SOPv5.11 systematic warning elimination complete")
    else
      IO.puts("❌ Final compilation failed:")
      IO.puts(result)
      IO.puts("🔍 Additional fixes may be needed")
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Systematic Warning Eliminator

    Usage:
      elixir #{__ENV__.file} --analyze          # Analyze warning patterns
      elixir #{__ENV__.file} --fix-batch N      # Fix specific batch number
      elixir #{__ENV__.file} --fix-all          # Fix all warnings systematically
      elixir #{__ENV__.file} --status           # Show current warning status

    This script implements SOPv5.11 cybernetic methodology for systematic
    warning elimination with zero tolerance policy compliance.
    """)
  end
end

# Run if called directly
if System.argv() != [] do
  SystematicWarningEliminator.main(System.argv())
end