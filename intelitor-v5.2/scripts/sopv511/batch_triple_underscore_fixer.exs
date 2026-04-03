#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule BatchTripleUnderscoreFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Batch Fixer for Triple Underscore MODULE Errors

  Phase 2.2.1: Systematic fix for all __MODULE__ compilation errors blocking analytics tests
  """

  require Logger

  def main(args \\ []) do
    Logger.info("🚀 SOPv5.11 Batch Triple Underscore Fixer - Starting")

    case args do
      ["--scan"] -> scan_all_files()
      ["--fix"] -> fix_all_files()
      ["--validate"] -> validate_fixes()
      ["--comprehensive"] -> run_comprehensive_fix()
      _ -> run_comprehensive_fix()
    end
  end

  def run_comprehensive_fix do
    Logger.info("🎯 Phase 2.2.1: Comprehensive __MODULE__ Error Fix")

    # Step 1: Scan all affected files
    affected_files = scan_all_files()

    # Step 2: Fix files in batches
    fix_results = fix_all_files()

    # Step 3: Validate compilation
    validate_fixes()

    Logger.info("✅ Comprehensive fix completed")

    %{
      files_scanned: length(affected_files),
      files_fixed: length(fix_results),
      status: :completed
    }
  end

  def scan_all_files do
    Logger.info("📊 Scanning for __MODULE__ errors across entire codebase")

    # Use grep to find all files with __MODULE__
    {output, _} = System.cmd("grep", ["-r", "-l", "__MODULE__", "lib/", "test/"], stderr_to_stdout: true)

    files = output
    |> String.split("\n")
    |> Enum.filter(&(&1 != ""))
    |> Enum.filter(&String.ends_with?(&1, ".ex"))

    Logger.info("📋 Found #{length(files)} files with __MODULE__ errors")

    # Log first 10 files for verification
    files
    |> Enum.take(10)
    |> Enum.with_index(1)
    |> Enum.each(fn {file, index} ->
      Logger.info("   #{index}. #{file}")
    end)

    if length(files) > 10 do
      Logger.info("   ... and #{length(files) - 10} more files")
    end

    files
  end

  def fix_all_files do
    Logger.info("🔧 Fixing all __MODULE__ errors systematically")

    affected_files = scan_all_files()

    results = affected_files
    |> Enum.with_index(1)
    |> Enum.map(fn {file_path, index} ->
      fix_file(file_path, index, length(affected_files))
    end)
    |> Enum.filter(&(&1 != nil))

    Logger.info("✅ Fixed #{length(results)} files successfully")
    results
  end

  def fix_file(file_path, index, total) do
    Logger.info("🔧 [#{index}/#{total}] Fixing: #{file_path}")

    try do
      # Read file content
      content = File.read!(file_path)

      # Count occurrences before fix
      before_count = count_triple_underscore_occurrences(content)

      if before_count > 0 do
        # Replace all __MODULE__ with __MODULE__
        fixed_content = String.replace(content, "__MODULE__", "__MODULE__")

        # Count after fix
        after_count = count_triple_underscore_occurrences(fixed_content)

        # Write fixed content
        File.write!(file_path, fixed_content)

        Logger.info("   ✅ Fixed #{before_count} occurrences in #{Path.basename(file_path)}")

        %{
          file: file_path,
          fixes_applied: before_count,
          status: :success
        }
      else
        Logger.info("   ℹ️ No __MODULE__ found in #{Path.basename(file_path)}")
        nil
      end
    rescue
      error ->
        Logger.error("   ❌ Error fixing #{file_path}: #{inspect(error)}")
        %{
          file: file_path,
          status: :error,
          error: inspect(error)
        }
    end
  end

  def count_triple_underscore_occurrences(content) do
    content
    |> String.split("__MODULE__")
    |> length()
    |> Kernel.-(1)
    |> max(0)
  end

  def validate_fixes do
    Logger.info("🔍 Validating compilation after fixes")

    # Check if any __MODULE__ errors remain
    remaining_files = scan_all_files()

    if length(remaining_files) == 0 do
      Logger.info("✅ All __MODULE__ errors fixed successfully")

      # Attempt compilation test
      Logger.info("🧪 Testing compilation...")

      compile_result = System.cmd("mix", ["compile", "--warnings-as-errors"],
        stderr_to_stdout: true,
        env: [
          {"NO_TIMEOUT", "true"},
          {"PATIENT_MODE", "enabled"},
          {"INFINITE_PATIENCE", "true"},
          {"ELIXIR_ERL_OPTIONS", "+S 16"}
        ]
      )

      case compile_result do
        {_output, 0} ->
          Logger.info("✅ Compilation successful after fixes")
          :compilation_success
        {output, _} ->
          Logger.warn("⚠️ Compilation still has issues:")
          Logger.warn(String.slice(output, 0, 1000) <> "...")
          :compilation_issues
      end
    else
      Logger.warn("⚠️ #{length(remaining_files)} files still have __MODULE__ errors")
      :incomplete_fixes
    end
  end

  def save_fix_report(results) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./data/tmp/#{timestamp}-triple-underscore-fix-report.json"

    report = %{
      timestamp: timestamp,
      total_files_processed: length(results),
      successful_fixes: Enum.count(results, &(&1.status == :success)),
      errors: Enum.filter(results, &(&1.status == :error)),
      total_fixes_applied: Enum.sum(Enum.map(results, &(&1[:fixes_applied] || 0)))
    }

    File.write!(report_file, Jason.encode!(report, pretty: true))
    Logger.info("📋 Fix report saved to: #{report_file}")

    report
  end
end

# Execute if run directly
if System.argv() != [] or __ENV__.file == Path.absname(System.argv() |> hd || __ENV__.file) do
  BatchTripleUnderscoreFixer.main(System.argv())
end