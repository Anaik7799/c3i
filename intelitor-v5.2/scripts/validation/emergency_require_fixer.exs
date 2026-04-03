#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule EmergencyRequireFixer do
  @moduledoc """
  🚨 EMERGENCY: Fix critical __require Logger bug introduced by warning eliminator

  The warning elimination system incorrectly changed "require Logger" to "__require Logger"
  which is invalid syntax. This emergency fixer corrects this systematic error.
  """

  def main(args \\ []) do
    IO.puts("🚨 EMERGENCY: Fixing critical __require Logger bug")

    case Enum.at(args, 0) do
      "--execute" -> execute_emergency_fix()
      "--analyze" -> analyze__require_issues()
      _ -> show_help()
    end
  end

  defp execute_emergency_fix do
    IO.puts("🔧 Scanning all Elixir files for __require Logger bug...")

    files = find_elixir_files()
    _fixed_files = 0

    {_fixed_files, __} = Enum.reduce(files, {0, 0}, fn file, {acc_fixed, acc_total} ->
      case fix__require_in_file(file) do
        true ->
          IO.puts("✅ Fixed: #{Path.basename(file)}")
          {acc_fixed + 1, acc_total + 1}
        false ->
          {acc_fixed, acc_total + 1}
      end
    end)

    IO.puts("\n📊 Emergency Fix Results:")
    IO.puts("   Files scanned: #{length(files)}")
    IO.puts("   Files fixed: #{fixed_files}")

    # Validate compilation after fix
    IO.puts("\n🎯 Validating compilation after emergency fix...")
    validate_compilation()
  end

  defp analyze__require_issues do
    IO.puts("🔍 Analyzing __require issues...")

    files = find_elixir_files()
    problematic_files = []

    problematic_files = Enum.reduce(files, [], fn file, acc ->
      content = File.read!(file)
      if String.contains?(content, "__require") do
        lines_with__require = content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} -> String.contains?(line, "__require") end)

        if length(lines_with__require) > 0 do
          IO.puts("📄 #{file}:")
          Enum.each(lines_with__require, fn {line, line_num} ->
            IO.puts("   Line #{line_num}: #{String.trim(line)}")
          end)
          [file | acc]
        else
          acc
        end
      else
        acc
      end
    end)

    IO.puts("\n📊 Analysis Results:")
    IO.puts("   Files with __require issues: #{length(problematic_files)}")
  end

  defp fix__require_in_file(file_path) do
    try do
      content = File.read!(file_path)

      # Fix the specific patterns
      fixed_content = content
      |> String.replace("__require Logger", "require Logger")
      |> String.replace("__require Ash", "require Ash")
      |> String.replace("__require ", "require ")

      if fixed_content != content do
        File.write!(file_path, fixed_content)
        true
      else
        false
      end
    rescue
      e ->
        IO.puts("⚠️  Error processing #{file_path}: #{inspect(e)}")
        false
    end
  end

  defp find_elixir_files do
    ["lib/**/*.ex", "test/**/*.exs"]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.filter(&File.exists?/1)
  end

  defp validate_compilation do
    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("🏆 SUCCESS: Compilation successful after emergency fix!")
        true
      {output, _} ->
        IO.puts("❌ Compilation still has issues:")

        # Count errors and warnings
        errors = count_pattern(output, ["error:", "** ("])
        warnings = count_pattern(output, ["warning:"])

        IO.puts("   Errors: #{errors}")
        IO.puts("   Warnings: #{warnings}")

        # Save the output for analysis
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
        log_path = "./data/tmp/emergency_fix_compilation_#{timestamp}.log"
        File.write!(log_path, output)
        IO.puts("📄 Compilation log saved: #{log_path}")

        false
    end
  end

  defp count_pattern(text, patterns) do
    text
    |> String.split("\n")
    |> Enum.count(fn line ->
      Enum.any?(patterns, &String.contains?(line, &1))
    end)
  end

  defp show_help do
    IO.puts("""
    🚨 Emergency Require Logger Fixer

    Usage:
      elixir emergency__require_fixer.exs [--execute|--analyze]

    Commands:
      --execute    Fix all __require Logger issues
      --analyze    Analyze __require issues in codebase
    """)
  end
end

EmergencyRequireFixer.main(System.argv())