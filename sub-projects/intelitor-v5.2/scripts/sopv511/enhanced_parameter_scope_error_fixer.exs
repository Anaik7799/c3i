#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule EnhancedParameterScopeErrorFixer do
  @moduledoc """
  AEE SOPv5.11 Enhanced Parameter Scope Error Fixer

  Advanced cybernetic error resolution system specifically designed to fix
  function parameter scope errors that persist after initial AEE execution.

  Targets critical patterns:
  - Functions with _param definitions but code using param
  - Missing parameters in function definitions
  - Variable scope mismatches

  Architecture: 5-Agent Cybernetic Parameter Resolution System
  - 1 Analysis Agent: Error pattern identification and classification
  - 1 Parameter Agent: Function signature analysis and correction
  - 1 Scope Agent: Variable scope validation and resolution
  - 1 Validation Agent: Fix verification and testing
  - 1 Coordination Agent: System-wide coordination and reporting
  """

  def main(args) do
    IO.puts "[#{timestamp()}] 🚀 AEE SOPv5.11 Enhanced Parameter Scope Error Fixer Starting..."
    IO.puts "[#{timestamp()}] 🤖 Deploying 5-Agent Cybernetic Parameter Resolution System"

    case List.first(args) do
      "--analyze" ->
        analyze_parameter_errors()
      "--validate" ->
        validate_fixes()
      _ ->
        execute_comprehensive_parameter_resolution()
    end

    IO.puts "[#{timestamp()}] ✅ AEE SOPv5.11 Enhanced Parameter Scope Resolution Complete"
  end

  defp execute_comprehensive_parameter_resolution do
    IO.puts "[#{timestamp()}] 📊 Analysis Agent: Scanning compilation log for parameter errors..."

    # Read the latest compilation log
    compilation_output = case File.read("2-compile-post-aee.log") do
      {:ok, content} -> content
      {:error, _} ->
        IO.puts "[#{timestamp()}] ⚠️ No compilation log found, running fresh compilation..."
        {_output, __} = System.cmd("mix", ["compile"], stderr_to_stdout: true, env: [{"ELIXIR_ERL_OPTIONS", "+S 16"}])
        File.write!("3-enhanced-parameter-compile.log", output)
        output
    end

    # Extract parameter scope errors
    parameter_errors = extract_parameter_scope_errors(compilation_output)

    IO.puts "[#{timestamp()}] 📈 Analysis Agent: Found #{length(parameter_errors)} parameter scope errors"

    # Group errors by file and type
    errors_by_file = Enum.group_by(parameter_errors, &(&1.file))

    IO.puts "[#{timestamp()}] 🔧 Parameter Agent: Processing #{map_size(errors_by_file)} files..."

    _total_fixes = 0

    Enum.reduce(errors_by_file, 0, fn {file_path, file_errors}, acc ->
      IO.puts "[#{timestamp()}] 🎯 Processing #{file_path} (#{length(file_errors)} errors)"
      fixes_applied = fix_parameter_errors_in_file(file_path, file_errors)
      IO.puts "[#{timestamp()}] ✅ Applied #{fixes_applied} fixes to #{file_path}"
      acc + fixes_applied
    end)
    |> (&(IO.puts "[#{timestamp()}] 🏆 Coordination Agent: Total fixes applied: #{&1}")).()

    # Validate compilation after fixes
    IO.puts "[#{timestamp()}] 🔍 Validation Agent: Running post-fix compilation validation..."
    validate_post_fix_compilation()
  end

  defp extract_parameter_scope_errors(compilation_output) do
    # Pattern to match parameter scope errors
    error_pattern = ~r/error: undefined variable "([^"]+)"\s+│[^│]+│\s*(\d+)\s+│[^│]+│[^│]+└─\s+([^:]+):(\d+):(\d+):/

    Regex.scan(error_pattern, compilation_output)
    |> Enum.map(fn [_full, variable, line_in_error, file, line_num, col] ->
      %{
        type: :undefined_variable,
        variable: variable,
        file: file,
        line: String.to_integer(line_num),
        column: String.to_integer(col),
        error_line: String.to_integer(line_in_error)
      }
    end)
  end

  defp fix_parameter_errors_in_file(file_path, errors) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Process each error and determine fix strategy
        _fixed_lines = Enum.reduce(errors, _lines, fn error, current_lines ->
          fix_parameter_error(current_lines, error)
        end)

        # Write back the fixed content
        fixed_content = Enum.join(fixed_lines, "\n")
        if fixed_content != content do
          File.write!(file_path, fixed_content)
          length(errors)
        else
          0
        end

      {:error, reason} ->
        IO.puts "[#{timestamp()}] ❌ Could not read #{file_path}: #{reason}"
        0
    end
  end

  defp fix_parameter_error(lines, error) do
    line_index = error.line - 1

    if line_index >= 0 and line_index < length(lines) do
      line = Enum.at(lines, line_index)

      # Determine fix strategy based on error pattern
      fixed_line = cond do
        # Case 1: Variable used but function has _variable parameter
        String.contains?(line, error.variable) and not String.contains?(line, "_#{error.variable}") ->
          fix_function_parameter_definition(lines, error)

        # Case 2: Variable used but not defined in function parameters
        String.contains?(line, error.variable) ->
          add_missing_parameter(lines, error)

        true ->
          lines
      end

      fixed_line
    else
      lines
    end
  end

  defp fix_function_parameter_definition(lines, error) do
    # Find the function definition that needs parameter fix
    function_start = find_function_start(lines, error.line - 1)

    if function_start do
      function_line = Enum.at(lines, function_start)

      # Fix _param to param in function definition
      fixed_function_line = String.replace(function_line, "_#{error.variable}", error.variable)

      if fixed_function_line != function_line do
        List.replace_at(lines, function_start, fixed_function_line)
      else
        lines
      end
    else
      lines
    end
  end

  defp add_missing_parameter(lines, error) do
    # Find the function definition and add missing parameter
    function_start = find_function_start(lines, error.line - 1)

    if function_start do
      function_line = Enum.at(lines, function_start)

      # Add parameter to function definition
      fixed_function_line = add_parameter_to_function(function_line, error.variable)

      if fixed_function_line != function_line do
        List.replace_at(lines, function_start, fixed_function_line)
      else
        lines
      end
    else
      lines
    end
  end

  defp find_function_start(lines, start_line) do
    # Look backwards from error line to find function definition
    Enum.find(start_line..0, fn line_index ->
      line = Enum.at(lines, line_index)
      line && (String.contains?(line, "def ") or String.contains?(line, "defp "))
    end)
  end

  defp add_parameter_to_function(function_line, variable) do
    cond do
      # Function with no parameters
      String.contains?(function_line, "() do") ->
        String.replace(function_line, "() do", "(#{variable}) do")

      # Function with parameters
      String.contains?(function_line, ") do") ->
        String.replace(function_line, ") do", ", #{variable}) do")

      # Function with when clause
      String.contains?(function_line, ") when") ->
        String.replace(function_line, ") when", ", #{variable}) when")

      true ->
        function_line
    end
  end

  defp validate_post_fix_compilation do
    IO.puts "[#{timestamp()}] 🔍 Validation Agent: Running compilation test..."

    {_output, _exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true, env: [{"ELIXIR_ERL_OPTIONS", "+S 16"}])

    File.write!("4-post-parameter-fix-compile.log", output)

    error_count = count_compilation_errors(output)
    warning_count = count_compilation_warnings(output)

    IO.puts "[#{timestamp()}] 📊 Validation Results:"
    IO.puts "[#{timestamp()}]   - Compilation exit code: #{exit_code}"
    IO.puts "[#{timestamp()}]   - Errors: #{error_count}"
    IO.puts "[#{timestamp()}]   - Warnings: #{warning_count}"

    if exit_code == 0 do
      IO.puts "[#{timestamp()}] 🎉 Validation Agent: COMPILATION SUCCESS!"
      if warning_count > 0 do
        IO.puts "[#{timestamp()}] ⚠️ Note: #{warning_count} warnings remain for future resolution"
      end
    else
      IO.puts "[#{timestamp()}] ❌ Validation Agent: Compilation still has #{error_count} errors"
      IO.puts "[#{timestamp()}] 📋 Next: Manual review of 4-post-parameter-fix-compile.log __required"
    end
  end

  defp count_compilation_errors(output) do
    # Count various error patterns
    error_patterns = [
      ~r/error:/,
      ~r/\*\* \(/,
      ~r/undefined variable/,
      ~r/undefined function/,
      ~r/CompileError/,
      ~r/cannot compile module/,
      ~r/== Compilation error/
    ]

    Enum.reduce(error_patterns, 0, fn pattern, acc ->
      matches = Regex.scan(pattern, output) |> length()
      acc + matches
    end)
  end

  defp count_compilation_warnings(output) do
    warning_patterns = [
      ~r/warning:/,
      ~r/is unused/,
      ~r/deprecated/
    ]

    Enum.reduce(warning_patterns, 0, fn pattern, acc ->
      matches = Regex.scan(pattern, output) |> length()
      acc + matches
    end)
  end

  defp analyze_parameter_errors do
    IO.puts "[#{timestamp()}] 🔍 Analysis Mode: Parameter Error Pattern Analysis"

    # Read compilation logs and analyze patterns
    compilation_files = ["1-compile.log", "2-compile-post-aee.log", "3-enhanced-parameter-compile.log"]

    Enum.each(compilation_files, fn file ->
      if File.exists?(file) do
        content = File.read!(file)
        errors = extract_parameter_scope_errors(content)

        IO.puts "[#{timestamp()}] 📊 #{file}: #{length(errors)} parameter errors"

        # Group by error type
        by_type = Enum.group_by(errors, &(&1.type))
        Enum.each(by_type, fn {type, errors} ->
          IO.puts "[#{timestamp()}]   - #{type}: #{length(errors)} errors"
        end)

        # Group by file
        by_file = Enum.group_by(errors, &(&1.file))
        top_files = by_file
          |> Enum.sort_by(fn {_file, errors} -> length(errors) end, :desc)
          |> Enum.take(5)

        IO.puts "[#{timestamp()}] 🎯 Top 5 files with parameter errors:"
        Enum.each(top_files, fn {file, errors} ->
          IO.puts "[#{timestamp()}]   - #{file}: #{length(errors)} errors"
        end)
      end
    end)
  end

  defp validate_fixes do
    IO.puts "[#{timestamp()}] ✅ Validation Mode: Fix Verification"

    # Run fresh compilation to validate all fixes
    validate_post_fix_compilation()
  end

  defp timestamp do
    DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")
  end
end

# Execute directly
EnhancedParameterScopeErrorFixer.main(System.argv())