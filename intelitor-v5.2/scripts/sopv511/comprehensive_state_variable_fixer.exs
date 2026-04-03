#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveStateVariableFixer do
  @moduledoc """
  Comprehensive fix for incorrectly modified state variables across all files
  Fixes _state and __state issues caused by overly aggressive pattern replacement
  """

  def main(args \\ []) do
    IO.puts("🚀 Comprehensive State Variable Fixer")
    IO.puts("📊 Fixing incorrectly modified state variables across all files")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--fix-all"] -> fix_all_state_issues()
      ["--scan"] -> scan_state_issues()
      ["--test"] -> test_compilation()
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --fix-all  # Fix all state variable issues
      elixir #{__ENV__.file} --scan     # Scan for state variable issues
      elixir #{__ENV__.file} --test     # Test compilation
    """)
  end

  def fix_all_state_issues do
    IO.puts("🔧 Scanning for files with state variable issues...")

    # Find all Elixir files with __state or _state issues
    problematic_files = find_problematic_files()

    IO.puts("📋 Found #{length(problematic_files)} files with state variable issues:")
    Enum.each(problematic_files, fn file ->
      IO.puts("  ├── #{file}")
    end)

    # Fix each file
    fixed_count = Enum.reduce(problematic_files, 0, fn file, acc ->
      if fix_file_state_issues(file) do
        acc + 1
      else
        acc
      end
    end)

    IO.puts("\n✅ Fixed state variable issues in #{fixed_count}/#{length(problematic_files)} files")

    # Log the operation
    log_file = "./data/tmp/#{current_timestamp()}-comprehensive-state-fix.log"
    log_entry = """
    Comprehensive State Variable Fix

    Files processed: #{length(problematic_files)}
    Files fixed: #{fixed_count}
    Timestamp: #{current_timestamp()}

    Fixed files:
    #{Enum.join(problematic_files, "\n")}
    """
    File.write!(log_file, log_entry)

    # Test compilation
    test_compilation()
  end

  defp find_problematic_files do
    Path.wildcard("lib/**/*.ex")
    |> Enum.filter(&file_has_state_issues?/1)
  end

  defp file_has_state_issues?(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        String.contains?(content, "_state") or
        has_incorrect_state_usage?(content)
      {:error, _} ->
        false
    end
  end

  defp has_incorrect_state_usage?(content) do
    # Check for __state in function parameters where it should be state
    Regex.match?(~r/def handle_[a-z_]+\([^,)]*__, _state\)/, content) or
    Regex.match?(~r/defp [a-zA-Z_][a-zA-Z0-9_]*\([^,)]*__, _state\)/, content)
  end

  def fix_file_state_issues(file_path) do
    IO.puts("🔧 Fixing: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = apply_comprehensive_state_fixes(content)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Fixed state issues in #{file_path}")
          true
        else
          IO.puts("  ℹ️ No state fixes needed in #{file_path}")
          false
        end

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
        false
    end
  end

  defp apply_comprehensive_state_fixes(content) do
    content
    # Fix triple underscore state variables (_state -> state)
    |> String.replace(~r/\b_state\b/, "state")
    # Fix function signatures with __state parameters
    |> fix_function_signatures_with_state()
    # Fix state references in function bodies
    |> fix_state_references_in_bodies()
    # Fix other common misnamed variables
    |> fix_other_common_issues()
  end

  defp fix_function_signatures_with_state(content) do
    content
    # Fix handle_cast with __state
    |> String.replace(
      ~r/def handle_cast\(([^,]+), _state\) do/,
      "def handle_cast(\\1, state) do"
    )
    # Fix handle_call with __state
    |> String.replace(
      ~r/def handle_call\(([^,]+), ([^,]+), _state\) do/,
      "def handle_call(\\1, \\2, state) do"
    )
    # Fix handle_info with __state
    |> String.replace(
      ~r/def handle_info\(([^,]+), _state\) do/,
      "def handle_info(\\1, state) do"
    )
    # Fix private functions with __state
    |> String.replace(
      ~r/defp ([a-zA-Z_][a-zA-Z0-9_]*)\(([^,)]*), _state\)/,
      "defp \\1(\\2, state)"
    )
  end

  defp fix_state_references_in_bodies(content) do
    content
    # Fix standalone __state references in function bodies
    |> String.replace(~r/(?<![a-zA-Z0-9_])__state(?![a-zA-Z0-9_])/, "state")
    # Fix map update syntax with __state
    |> String.replace(~r/%\{__state \|/, "%{state |")
    # Fix Map.get, Map.put calls with __state
    |> String.replace(~r/Map\.get\(__state\./, "Map.get(state.")
    |> String.replace(~r/Map\.put\(__state\./, "Map.put(state.")
  end

  defp fix_other_common_issues(content) do
    content
    # Fix any remaining double underscore variables that should be single
    |> String.replace(~r/__user_experience_rating:/, "user_experience_rating:")
    # Fix result parameters that might have been incorrectly modified
    |> String.replace(~r/defp update_strategic_state\(state, _result\)/, "defp update_strategic_state(state, _result)")
  end

  def scan_state_issues do
    IO.puts("🔍 Scanning for state variable issues...")

    problematic_files = find_problematic_files()

    IO.puts("📋 Found #{length(problematic_files)} files with issues:")

    Enum.each(problematic_files, fn file ->
      IO.puts("\n📄 #{file}:")
      case File.read(file) do
        {:ok, content} ->
          lines = String.split(content, "\n")
          problem_lines = lines
          |> Enum.with_index(1)
          |> Enum.filter(fn {line, _} ->
            String.contains?(line, "_state") or String.contains?(line, "__state")
          end)
          |> Enum.take(5) # Show first 5 problems per file

          Enum.each(problem_lines, fn {line, line_num} ->
            IO.puts("    Line #{line_num}: #{String.trim(line)}")
          end)

        {:error, _} ->
          IO.puts("    Error reading file")
      end
    end)
  end

  def test_compilation do
    IO.puts("\n🧪 Testing compilation after state fixes...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful - all state issues fixed!")
        true
      {output, _} ->
        IO.puts("❌ Compilation still has issues:")

        # Show key errors
        errors = output
        |> String.split("\n")
        |> Enum.filter(&(String.contains?(&1, "error:") or String.contains?(&1, "** (")))
        |> Enum.take(10)

        if length(errors) > 0 do
          IO.puts("Key errors:")
          Enum.each(errors, fn error ->
            IO.puts("  #{error}")
          end)
        else
          # Show warnings if no errors
          warnings = output
          |> String.split("\n")
          |> Enum.filter(&String.contains?(&1, "warning:"))
          |> Enum.take(5)

          if length(warnings) > 0 do
            IO.puts("Warnings found:")
            Enum.each(warnings, fn warning ->
              IO.puts("  #{warning}")
            end)
          end
        end

        false
    end
  end

  defp current_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Execute
ComprehensiveStateVariableFixer.main(System.argv())