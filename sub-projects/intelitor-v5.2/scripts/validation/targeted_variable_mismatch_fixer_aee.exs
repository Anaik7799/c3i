#!/usr/bin/env elixir

defmodule TargetedVariableMismatchFixerAEE do
  @moduledoc """
  AEE SOPv5.11 Targeted Variable Mismatch Fixer

  This script addresses specific variable name mismatches left after the systematic
  parameter fixer, where function signatures and body variable usage don't align.

  Framework: AEE+SOPv5.11+GDE+PHICS+TPS+STAMP+TDG

  TPS Jidoka: Stop-and-fix approach for each mismatch pattern
  STAMP Safety: Ensure no variable access violations created
  """

  __require Logger

  @common_variable_mappings %{
    "tenantid" => "__tenant_id",
    "deviceid" => "device_id",
    "alarmid" => "alarm_id",
    "__userid" => "__user_id",
    "siteid" => "site_id",
    "__params" => "__params",
    "__opts" => "__opts",
    "__state" => "__state",
    "socket" => "socket",
    "scope" => "scope"
  }

  def main(args \\ []) do
    IO.puts("\n🤖 AEE SOPv5.11 Targeted Variable Mismatch Fixer")
    IO.puts("=" <> String.duplicate("=", 50))

    case args do
      ["--comprehensive"] ->
        fix_all_variable_mismatches()
      ["--analyze"] ->
        analyze_mismatches()
      _ ->
        show_help()
    end
  rescue
    e ->
      IO.puts("❌ Error: #{inspect(e)}")
      System.halt(1)
  end

  defp fix_all_variable_mismatches do
    IO.puts("🔧 Starting comprehensive variable mismatch fixing...")

    files_to_check = get_all_elixir_files()

    IO.puts("📊 Found #{length(files_to_check)} Elixir files to analyze")

    files_to_check
    |> Enum.reduce(0, fn file_path, acc_fixes ->
      case fix_file_variable_mismatches(file_path) do
        {:ok, fixes_count} when fixes_count > 0 ->
          IO.puts("✅ Fixed #{fixes_count} mismatches in #{file_path}")
          acc_fixes + fixes_count
        {:ok, 0} ->
          acc_fixes
        {:error, reason} ->
          IO.puts("❌ Error processing #{file_path}: #{reason}")
          acc_fixes
      end
    end)
    |> then(fn total ->
      IO.puts("\n🏆 AEE SOPv5.11 COMPLETION SUMMARY:")
      IO.puts("   Total variable mismatch fixes applied: #{total}")
      IO.puts("   Files processed: #{length(files_to_check)}")

      if total > 0 do
        IO.puts("\n✅ Running Patient Mode compilation validation...")
        run_patient_mode_compilation()
      else
        IO.puts("\n✅ No variable mismatches found")
      end
    end)
  end

  defp fix_file_variable_mismatches(file_path) do
    try do
      content = File.read!(file_path)
      original_content = content

      # Fix pattern 1: Function signature variable name mismatches
      content = fix_signature_variable_mismatches(content)

      # Fix pattern 2: String concatenation variable mismatches
      content = fix_string_concat_mismatches(content)

      # Fix pattern 3: Underscore prefix mismatches
      content = fix_underscore_prefix_mismatches(content)

      if content != original_content do
        File.write!(file_path, content)
        fixes_count = count_fixes_applied(original_content, content)
        {:ok, fixes_count}
      else
        {:ok, 0}
      end
    rescue
      e ->
        {:error, "File processing error: #{inspect(e)}"}
    end
  end

  defp fix_signature_variable_mismatches(content) do
    # Fix pattern: "alarm:" <> tenantid but body uses __tenant_id
    content
    |> String.replace(~r/"([^"]+):" <> tenantid/, ~s/"\\1:" <> __tenant_id/)
    |> String.replace(~r/"([^"]+):" <> deviceid/, ~s/"\\1:" <> device_id/)
    |> String.replace(~r/"([^"]+):" <> alarmid/, ~s/"\\1:" <> alarm_id/)
    |> String.replace(~r/"([^"]+):" <> __userid/, ~s/"\\1:" <> __user_id/)
    |> String.replace(~r/"([^"]+):" <> siteid/, ~s/"\\1:" <> site_id/)
  end

  defp fix_string_concat_mismatches(content) do
    # Fix cases where string concatenation variables don't match body usage
    @common_variable_mappings
    |> Enum.reduce(content, fn {wrong_var, correct_var}, acc_content ->
      if wrong_var != correct_var do
        # Fix in string interpolations
        acc_content
        |> String.replace(~r/\#\{#{wrong_var}\}/, "\#{#{correct_var}}")
        |> String.replace(~r/ <> #{wrong_var}/, " <> #{correct_var}")
        |> String.replace(~r/#{wrong_var} <> /, "#{correct_var} <> ")
      else
        acc_content
      end
    end)
  end

  defp fix_underscore_prefix_mismatches(content) do
    # Fix cases where function signature has _param but body uses param
    content
    |> fix_underscore_mismatch_pattern(~r/def\s+\w+\([^)]*_params[^)]*\)\s+do/, "__params")
    |> fix_underscore_mismatch_pattern(~r/def\s+\w+\([^)]*_socket[^)]*\)\s+do/, "socket")
    |> fix_underscore_mismatch_pattern(~r/def\s+\w+\([^)]*_opts[^)]*\)\s+do/, "__opts")
    |> fix_underscore_mismatch_pattern(~r/def\s+\w+\([^)]*_state[^)]*\)\s+do/, "__state")
    |> fix_underscore_mismatch_pattern(~r/def\s+\w+\([^)]*_scope[^)]*\)\s+do/, "scope")
  end

  defp fix_underscore_mismatch_pattern(content, regex, var_name) do
    Regex.replace(regex, content, fn match ->
      function_body = extract_function_body_for_match(content, match)

      if String.contains?(function_body, var_name) do
        # Remove underscore prefix if variable is used in body
        String.replace(match, "_#{var_name}", var_name)
      else
        match
      end
    end)
  end

  defp extract_function_body_for_match(content, match) do
    # Find the function body after the match
    case String.split(content, match, parts: 2) do
      [_before, after_match] ->
        # Extract until the next "def " or "defp " or end of file
        after_match
        |> String.split(~r/\n\s*def[p]?\s/, parts: 2)
        |> List.first()
        |> String.slice(0, 2000)  # Limit analysis to reasonable function size

      _ ->
        ""
    end
  end

  defp count_fixes_applied(original, fixed) do
    # Count number of differences between original and fixed content
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    Enum.zip(original_lines, fixed_lines)
    |> Enum.count(fn {orig, fixed} -> orig != fixed end)
  end

  defp analyze_mismatches do
    IO.puts("🔍 Analyzing variable mismatches...")

    # Get compilation errors that look like variable mismatches
    {_output, __exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true)

    undefined_vars =
      output
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "undefined variable"))
      |> Enum.map(fn line ->
        case Regex.run(~r/undefined variable "([^"]+)"/, line) do
          [_, var] -> var
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.f__requencies()

    IO.puts("\n📊 Most common undefined variables:")
    undefined_vars
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
    |> Enum.each(fn {var, count} ->
      IO.puts("   #{var}: #{count} occurrences")
    end)
  end

  defp get_all_elixir_files do
    ["lib", "test"]
    |> Enum.flat_map(fn dir ->
      case File.ls(dir) do
        {:ok, _} ->
          Path.wildcard("#{dir}/**/*.ex")
        {:error, _} ->
          []
      end
    end)
    |> Enum.filter(&File.regular?/1)
  end

  defp run_patient_mode_compilation do
    IO.puts("🧘 Running Patient Mode compilation to validate fixes...")

    env = [
      {"NO_TIMEOUT", "true"},
      {"PATIENT_MODE", "enabled"},
      {"INFINITE_PATIENCE", "true"},
      {"ELIXIR_ERL_OPTIONS", "+S 16"}
    ]

    {__output, _exit_code} = System.cmd("mix", ["compile", "--verbose"],
      env: env,
      stderr_to_stdout: true,
      into: File.stream!("2-compile-after-mismatch-fixes.log"))

    if exit_code == 0 do
      IO.puts("✅ Patient Mode compilation successful!")
    else
      IO.puts("⚠️  Compilation completed with issues - check 2-compile-after-mismatch-fixes.log")
    end
  end

  defp show_help do
    IO.puts("""
    🤖 AEE SOPv5.11 Targeted Variable Mismatch Fixer

    Usage:
      elixir #{__ENV__.file} --comprehensive   # Fix all variable mismatches
      elixir #{__ENV__.file} --analyze         # Analyze current mismatches
      elixir #{__ENV__.file} --help           # Show this help

    This script fixes specific patterns:
    1. String concatenation mismatches (tenantid vs __tenant_id)
    2. Function signature vs body variable mismatches
    3. Underscore prefix inconsistencies

    Framework: AEE+SOPv5.11+TPS+STAMP+TDG methodology
    """)
  end
end

# Run if called directly
if __MODULE__ == TargetedVariableMismatchFixerAEE do
  TargetedVariableMismatchFixerAEE.main(System.argv())
end