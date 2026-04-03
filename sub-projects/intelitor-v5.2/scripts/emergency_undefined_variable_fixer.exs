#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule EmergencyUndefinedVariableFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Emergency Undefined Variable Fixer

  This script systematically fixes undefined variable errors in Elixir files
  by analyzing the compilation log and applying targeted fixes.
  """

  def main(args \\ []) do
    IO.puts("🚨 SOPv5.11 Emergency Undefined Variable Fixer")
    IO.puts("=" |> String.duplicate(50))

    case args do
      ["--analyze"] -> analyze_log()
      ["--fix", batch_size] -> fix_variables(String.to_integer(batch_size))
      ["--fix"] -> fix_variables(200)
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts("""
    Usage:
      elixir scripts/emergency_undefined_variable_fixer.exs --analyze
      elixir scripts/emergency_undefined_variable_fixer.exs --fix [batch_size]

    Options:
      --analyze     Analyze 1-compile.log for undefined variable patterns
      --fix         Fix undefined variables in batches (default: 200)
    """)
  end

  defp analyze_log do
    IO.puts("📊 Analyzing compilation log for undefined variable patterns...")

    if File.exists?("1-compile.log") do
      content = File.read!("1-compile.log")

      # Extract undefined variable errors
      errors = extract_undefined_variable_errors(content)

      IO.puts("🔍 Found #{length(errors)} undefined variable errors")

      # Group by file
      grouped = Enum.group_by(errors, & &1.file)

      IO.puts("📁 Files with errors:")
      grouped
      |> Enum.sort_by(fn {_file, errors} -> -length(errors) end)
      |> Enum.take(20)
      |> Enum.each(fn {file, file_errors} ->
        IO.puts("  #{file}: #{length(file_errors)} errors")

        # Show most common variables
        file_errors
        |> Enum.map(& &1.variable)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_var, count} -> -count end)
        |> Enum.take(5)
        |> Enum.each(fn {var, count} ->
          IO.puts("    - #{var}: #{count} times")
        end)
      end)
    else
      IO.puts("❌ 1-compile.log not found")
    end
  end

  defp extract_undefined_variable_errors(content) do
    # Split into lines and process
    lines = String.split(content, "\n")

    extract_errors_from_lines(lines, [])
  end

  defp extract_errors_from_lines([], acc), do: Enum.reverse(acc)

  defp extract_errors_from_lines([line | rest], acc) do
    if String.contains?(line, "error: undefined variable") do
      # Extract variable name
      case Regex.run(~r/error: undefined variable "([^"]+)"/, line) do
        [_, variable] ->
          # Find the corresponding file and line info
          file_info = find_file_info(rest)
          error = %{
            variable: variable,
            file: file_info.file,
            line_number: file_info.line_number
          }
          extract_errors_from_lines(rest, [error | acc])

        _ ->
          extract_errors_from_lines(rest, acc)
      end
    else
      extract_errors_from_lines(rest, acc)
    end
  end

  defp find_file_info(lines) do
    # Look for the line with └─ that contains file info
    file_line = Enum.find(lines, &String.contains?(&1, "└─"))

    if file_line do
      case Regex.run(~r/└─\s+([^:]+):(\d+)/, file_line) do
        [_, file, line_number] ->
          %{file: file, line_number: String.to_integer(line_number)}

        _ ->
          %{file: "unknown", line_number: 0}
      end
    else
      %{file: "unknown", line_number: 0}
    end
  end

  defp fix_variables(batch_size) do
    IO.puts("🔧 Starting systematic variable fixes (batch size: #{batch_size})")

    if File.exists?("1-compile.log") do
      content = File.read!("1-compile.log")
      errors = extract_undefined_variable_errors(content)

      IO.puts("📊 Total errors to fix: #{length(errors)}")

      # Group by file and fix in batches
      errors
      |> Enum.group_by(& &1.file)
      |> Enum.take(5)  # Start with top 5 files
      |> Enum.each(fn {file, file_errors} ->
        IO.puts("🎯 Fixing #{file} (#{length(file_errors)} errors)")
        fix_file_variables(file, file_errors)
      end)
    else
      IO.puts("❌ 1-compile.log not found")
    end
  end

  defp fix_file_variables(file_path, errors) do
    if File.exists?(file_path) do
      content = File.read!(file_path)

      # Analyze the most common patterns
      variable_patterns = analyze_variable_patterns(errors)

      # Apply fixes based on patterns
      fixed_content = apply_variable_fixes(content, variable_patterns, errors)

      if fixed_content != content do
        File.write!(file_path, fixed_content)
        IO.puts("  ✅ Applied fixes to #{file_path}")
      else
        IO.puts("  ℹ️  No changes needed for #{file_path}")
      end
    else
      IO.puts("  ❌ File not found: #{file_path}")
    end
  end

  defp analyze_variable_patterns(errors) do
    # Common patterns:
    # 1. _context vs context
    # 2. _opts vs opts
    # 3. accessrule vs access_rule
    # 4. monitoring_results vs _monitoring_results

    patterns = %{
      "_context" => "context",
      "_opts" => "opts",
      "__opts" => "opts",
      "_tenant_id" => "tenant_id",
      "__tenant_id" => "tenant_id",
      "_tenant_id" => "tenant_id",
      "_state" => "state",
      "__state" => "state",
      "accessrule" => "access_rule",
      "_user" => "user"
    }

    # Find which patterns apply to these errors
    applicable_patterns =
      errors
      |> Enum.map(& &1.variable)
      |> Enum.uniq()
      |> Enum.filter(fn var -> Map.has_key?(patterns, var) end)
      |> Enum.into(%{}, fn var -> {var, patterns[var]} end)

    applicable_patterns
  end

  defp apply_variable_fixes(content, patterns, errors) do
    # Apply each pattern fix
    Enum.reduce(patterns, content, fn {wrong_var, correct_var}, acc_content ->
      # Fix function parameter names
      acc_content
      |> String.replace(
        ~r/defp?\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*#{Regex.escape(wrong_var)}([^)]*)\)/,
        fn match ->
          String.replace(match, wrong_var, correct_var)
        end
      )
      |> String.replace(
        ~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*#{Regex.escape(wrong_var)}([^)]*)\)/,
        fn match ->
          String.replace(match, wrong_var, correct_var)
        end
      )
    end)
  end
end

# Handle command line arguments
System.argv() |> EmergencyUndefinedVariableFixer.main()