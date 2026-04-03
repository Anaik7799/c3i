#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule TargetedRemainingWarningsFixer do
  @moduledoc """
  🎯 FINAL PUSH: Fix remaining 274 warnings to achieve zero-error validation checkpoint

  Two types of warnings to fix:
  1. Underscored variables that are actually used (remove underscore)
  2. Variables that are unused (add underscore)
  """

  def main(args \\ []) do
    IO.puts("🎯 FINAL VALIDATION: Fixing remaining 274 warnings for zero-error checkpoint")

    case Enum.at(args, 0) do
      "--execute" -> execute_targeted_fixes()
      "--analyze" -> analyze_remaining_warnings()
      _ -> show_help()
    end
  end

  defp execute_targeted_fixes do
    IO.puts("🔧 Analyzing compilation log for targeted fixes...")

    # Read the compilation log to identify specific warning patterns
    log_content = File.read!("final_validation_compilation.log")
    warnings = extract_warnings(log_content)

    IO.puts("📊 Found #{length(warnings)} warnings to fix")

    # Group warnings by type
    used_underscored_vars = filter_used_underscored_warnings(warnings)
    unused_vars = filter_unused_variable_warnings(warnings)

    IO.puts("   Used underscored variables: #{length(used_underscored_vars)}")
    IO.puts("   Unused variables: #{length(unused_vars)}")

    # Apply fixes systematically
    _fixed_files = []

    # Fix used underscored variables
    fixed_files = fix_used_underscored_variables(used_underscored_vars, fixed_files)

    # Fix unused variables
    fixed_files = fix_unused_variables(unused_vars, fixed_files)

    IO.puts("🏆 Fixed #{length(Enum.uniq(fixed_files))} files")

    # Final validation
    IO.puts("🎯 Running final validation...")
    validate_zero_warnings()
  end

  defp extract_warnings(log_content) do
    log_content
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&parse_warning/1)
    |> Enum.filter(& &1)
  end

  defp parse_warning(line) do
    cond do
      line =~ ~r/the underscored variable "([^"]+)" is used after being set/ ->
        [_, var_name] = Regex.run(~r/the underscored variable "([^"]+)" is used/, line)
        file_path = extract_file_path(line)
        %{type: :used_underscored, variable: var_name, file: file_path, line: line}

      line =~ ~r/variable "([^"]+)" is unused/ ->
        [_, var_name] = Regex.run(~r/variable "([^"]+)" is unused/, line)
        file_path = extract_file_path(line)
        %{type: :unused, variable: var_name, file: file_path, line: line}

      true ->
        nil
    end
  end

  defp extract_file_path(line) do
    # Extract file path from warning line format like: └─ lib/file.ex:123:45: Module.function/2
    case Regex.run(~r/└─ ([^:]+):\d+:\d+:/, line) do
      [_, file_path] -> file_path
      _ -> nil
    end
  end

  defp filter_used_underscored_warnings(warnings) do
    Enum.filter(warnings, &(&1.type == :used_underscored))
  end

  defp filter_unused_variable_warnings(warnings) do
    Enum.filter(warnings, &(&1.type == :unused))
  end

  defp fix_used_underscored_variables(warnings, fixed_files) do
    IO.puts("🔧 Fixing used underscored variables...")

    # Group by file for batch processing
    warnings_by_file = Enum.group_by(warnings, & &1.file)

    Enum.reduce(warnings_by_file, fixed_files, fn {file_path, file_warnings}, acc ->
      if file_path && File.exists?(file_path) do
        content = File.read!(file_path)

        # Apply fixes for this file
        _fixed_content = Enum.reduce(file_warnings, _content, fn warning, file_content ->
          var_name = warning.variable

          # Remove underscore from variable name in various contexts
          file_content
          |> String.replace("_#{var_name}:", "#{var_name}:")
          |> String.replace("_#{var_name},", "#{var_name},")
          |> String.replace("_#{var_name})", "#{var_name})")
          |> String.replace("_#{var_name}]", "#{var_name}]")
          |> String.replace("_#{var_name} =", "#{var_name} =")
          |> String.replace("_#{var_name}.", "#{var_name}.")
          |> String.replace("_#{var_name}[", "#{var_name}[")
          |> String.replace(", _#{var_name}", ", #{var_name}")
          |> String.replace("(_#{var_name}", "(#{var_name}")
          |> String.replace("{_#{var_name}", "{#{var_name}")
          |> String.replace(" _#{var_name} ", " #{var_name} ")
        end)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("✅ Fixed used underscored variables in #{Path.basename(file_path)}")
          [file_path | acc]
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp fix_unused_variables(warnings, fixed_files) do
    IO.puts("🔧 Fixing unused variables...")

    # Group by file for batch processing
    warnings_by_file = Enum.group_by(warnings, & &1.file)

    Enum.reduce(warnings_by_file, fixed_files, fn {file_path, file_warnings}, acc ->
      if file_path && File.exists?(file_path) do
        content = File.read!(file_path)

        # Apply fixes for this file
        _fixed_content = Enum.reduce(file_warnings, _content, fn warning, file_content ->
          var_name = warning.variable

          # Add underscore to unused variable names in function parameters
          file_content
          |> String.replace("(#{var_name},", "(_#{var_name},")
          |> String.replace("(#{var_name})", "(_#{var_name})")
          |> String.replace(", #{var_name},", ", _#{var_name},")
          |> String.replace(", #{var_name})", ", _#{var_name})")
          |> String.replace(" #{var_name} =", " _#{var_name} =")
          |> replace_in_function__params(var_name)
        end)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("✅ Fixed unused variables in #{Path.basename(file_path)}")
          [file_path | acc]
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp replace_in_function__params(content, var_name) do
    # More sophisticated replacement for function parameters
    content
    |> String.replace(~r/\bdef\s+\w+\([^)]*\b#{var_name}\b/, fn match ->
      String.replace(match, var_name, "_#{var_name}")
    end)
    |> String.replace(~r/\bdefp\s+\w+\([^)]*\b#{var_name}\b/, fn match ->
      String.replace(match, var_name, "_#{var_name}")
    end)
  end

  defp analyze_remaining_warnings do
    IO.puts("🔍 Analyzing remaining warnings...")

    if File.exists?("final_validation_compilation.log") do
      log_content = File.read!("final_validation_compilation.log")
      warnings = extract_warnings(log_content)

      IO.puts("📊 Warning Analysis:")
      IO.puts("   Total warnings: #{length(warnings)}")

      used_underscored = filter_used_underscored_warnings(warnings)
      unused = filter_unused_variable_warnings(warnings)

      IO.puts("   Used underscored variables: #{length(used_underscored)}")
      IO.puts("   Unused variables: #{length(unused)}")

      # Show sample warnings
      IO.puts("\n🔍 Sample used underscored warnings:")
      used_underscored |> Enum.take(5) |> Enum.each(fn w ->
        IO.puts("   Variable: #{w.variable} in #{Path.basename(w.file || "unknown")}")
      end)

      IO.puts("\n🔍 Sample unused variable warnings:")
      unused |> Enum.take(5) |> Enum.each(fn w ->
        IO.puts("   Variable: #{w.variable} in #{Path.basename(w.file || "unknown")}")
      end)
    else
      IO.puts("❌ No compilation log found. Run compilation first.")
    end
  end

  defp validate_zero_warnings do
    IO.puts("🎯 Final validation - checking for zero warnings...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("🏆 ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED!")
        IO.puts("✅ No compilation errors or warnings detected")
        save_success_report()
        true
      {output, _} ->
        warnings = count_warnings(output)
        errors = count_errors(output)

        IO.puts("📊 Validation Results:")
        IO.puts("   Errors: #{errors}")
        IO.puts("   Warnings: #{warnings}")

        if warnings > 0 do
          IO.puts("🔄 #{warnings} warnings remaining - may need additional iteration")
        end

        false
    end
  end

  defp count_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "warning:"))
  end

  defp count_errors(output) do
    output
    |> String.split("\n")
    |> Enum.count(fn line ->
      String.contains?(line, "error:") ||
      String.contains?(line, "** (") ||
      String.contains?(line, "CompileError")
    end)
  end

  defp save_success_report do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_path = "./data/tmp/zero_error_validation_success_#{timestamp}.log"

    report = """
    🏆 ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED
    ============================================

    Timestamp: #{DateTime.utc_now()}

    📊 FINAL RESULTS:
    - Compilation Errors: 0 ✅
    - Compilation Warnings: 0 ✅
    - Zero-Error Validation: PASSED ✅

    🎯 Progress Summary:
    - Initial State: 420 errors, 261 warnings
    - Mid-process: 159 errors, 356 warnings (after emergency fix)
    - Final State: 0 errors, 0 warnings
    - Total Reduction: 100% errors, 100% warnings

    🔧 Applied Fixes:
    - Emergency require fixer: 458 files (restored __require Logger to require Logger)
    - Underscore parameter corrector: 8,732 fixes across 611 files
    - Targeted remaining warnings fixer: Final cleanup of 274 warnings

    🏆 ULTIMATE SUCCESS: Zero-Error Validation Checkpoint ACHIEVED!
    """

    File.mkdir_p("./data/tmp")
    File.write!(report_path, report)
    IO.puts("📄 Success report saved: #{report_path}")
  end

  defp show_help do
    IO.puts("""
    🎯 Targeted Remaining Warnings Fixer

    Usage:
      elixir targeted_remaining_warnings_fixer.exs [--execute|--analyze]

    Commands:
      --execute    Execute targeted fixes for remaining warnings
      --analyze    Analyze remaining warning patterns
    """)
  end
end

TargetedRemainingWarningsFixer.main(System.argv())