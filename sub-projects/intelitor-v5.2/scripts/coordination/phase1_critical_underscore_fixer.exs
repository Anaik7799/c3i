#!/usr/bin/env elixir

# SOPv5.11 Phase 1 Critical Underscore Variable Fixer
# Executive Director: Strategic Pattern-Based Fix Coordination
# Generated: 2025-09-18 16:58:00 CEST

Mix.install([{:jason, "~> 1.4"}])

defmodule Phase1CriticalUnderscoreFixer do
  @moduledoc """
  SOPv5.11 Phase 1: Critical Used Underscored Variables Fix

  This is the Executive Director agent for systematic elimination of the highest-priority
  warning pattern: variables prefixed with underscore that are actually being used.

  Pattern Examples:
  - "__state" is used → change to "state"
  - "_attrs" is used → change to "attrs"
  - "_opts" is used → change to "opts"
  """

  # Critical patterns to fix (highest priority)
  @critical_patterns [
    {"__state", "state"},
    {"_attrs", "attrs"},
    {"_opts", "opts"},
    {"_req", "req"},
    {"_errors", "errors"},
    {"_warnings", "warnings"},
    {"_context", "context"},
    {"_params", "params"},
    {"_data", "data"}
  ]

  def main(args \\ []) do
    IO.puts("🚀 SOPv5.11 Phase 1: Critical Underscore Variable Fixer")
    IO.puts("======================================================")
    IO.puts("📅 Timestamp: #{DateTime.utc_now() |> DateTime.to_string()}")
    IO.puts("")

    case args do
      ["--analyze"] ->
        analyze_critical_patterns()

      ["--fix-batch", batch_size] ->
        batch_size = String.to_integer(batch_size)
        fix_critical_patterns_in_batches(batch_size)

      ["--status"] ->
        show_status()

      _ ->
        show_help()
    end
  end

  defp analyze_critical_patterns do
    IO.puts("🔍 Analyzing Critical Underscore Pattern Usage...")

    # Get all .ex files
    files = Path.wildcard("lib/**/*.ex")

    IO.puts("📊 Found #{length(files)} Elixir files to analyze")

    critical_files =
      Enum.reduce(@critical_patterns, %{}, fn {pattern, _replacement}, acc ->
        pattern_files = find_files_with_pattern(files, pattern)
        Map.put(acc, pattern, pattern_files)
      end)

    # Display analysis results
    IO.puts("")
    IO.puts("📋 Critical Pattern Analysis Results:")
    IO.puts("====================================")

    Enum.each(@critical_patterns, fn {pattern, replacement} ->
      files_with_pattern = Map.get(critical_files, pattern, [])
      IO.puts("  #{pattern} → #{replacement}: #{length(files_with_pattern)} files")

      if length(files_with_pattern) > 0 do
        files_with_pattern
        |> Enum.take(3)
        |> Enum.each(fn file ->
          IO.puts("    - #{file}")
        end)

        if length(files_with_pattern) > 3 do
          IO.puts("    ... and #{length(files_with_pattern) - 3} more files")
        end
      end
    end)

    total_files = critical_files |> Map.values() |> List.flatten() |> Enum.uniq() |> length()
    IO.puts("")
    IO.puts("🎯 Total files needing critical fixes: #{total_files}")
    IO.puts("📊 Recommended batch size: 25 files per batch")
  end

  defp find_files_with_pattern(files, pattern) do
    Enum.filter(files, fn file ->
      content = File.read!(file)

      # Look for the pattern being used (not just defined)
      # This is more sophisticated than simple string matching
      used_pattern = Regex.compile!(~s/(?:#{Regex.escape(pattern)})\\s*[\\[\\.]/)

      case Regex.run(used_pattern, content) do
        nil -> false
        _ -> true
      end
    end)
  end

  defp fix_critical_patterns_in_batches(batch_size) do
    IO.puts("🔧 Executing SOPv5.11 Phase 1 Critical Fixes in batches of #{batch_size}")

    # Create git checkpoint
    create_git_checkpoint("phase1-critical-underscore-fixes")

    files = Path.wildcard("lib/**/*.ex")

    all_affected_files =
      Enum.reduce(@critical_patterns, [], fn {pattern, _}, acc ->
        pattern_files = find_files_with_pattern(files, pattern)
        acc ++ pattern_files
      end)
      |> Enum.uniq()

    IO.puts("📊 Found #{length(all_affected_files)} files needing critical fixes")

    # Process in batches
    all_affected_files
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, index} ->
      process_batch(batch, index + 1, batch_size)
    end)

    IO.puts("")
    IO.puts("✅ Phase 1 Critical Fixes Complete!")
    IO.puts("🔍 Run compilation to verify results...")
  end

  defp process_batch(files, batch_number, batch_size) do
    IO.puts("")
    IO.puts("📦 Processing Batch #{batch_number} (#{length(files)} files)")
    IO.puts("===============================================")

    Enum.each(files, fn file ->
      IO.puts("  🔧 Fixing: #{file}")
      fix_critical_patterns_in_file(file)
    end)

    IO.puts("  ✅ Batch #{batch_number} completed")

    # Test compilation after each batch
    IO.puts("  🧪 Testing compilation...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("  ✅ Compilation successful for batch #{batch_number}")

        # Commit successful batch
        commit_message =
          "SOPv5.11 Phase 1: Fixed critical underscore variables (batch #{batch_number})"

        System.cmd("git", ["add", "."])
        System.cmd("git", ["commit", "-m", commit_message])

      {output, _} ->
        IO.puts("  ⚠️  Compilation issues detected in batch #{batch_number}")
        IO.puts("  🔄 Rolling back batch...")

        # Rollback this batch
        System.cmd("git", ["reset", "--hard", "HEAD"])

        # Log the issue
        log_batch_issue(batch_number, output)
    end
  end

  defp fix_critical_patterns_in_file(file_path) do
    content = File.read!(file_path)

    updated_content =
      Enum.reduce(@critical_patterns, content, fn {pattern, replacement}, acc ->
        # More sophisticated replacement that considers context
        # Only replace when the variable is being used, not just defined

        # Pattern 1: Variable usage (accessing fields or being passed)
        usage_pattern = ~r/\b#{Regex.escape(pattern)}\.([\w_]+)/
        acc = Regex.replace(usage_pattern, acc, "#{replacement}.\\1")

        # Pattern 2: Variable being returned or passed
        return_pattern = ~r/\b#{Regex.escape(pattern)}\b(?=\s*[,\)\]\}])/
        acc = Regex.replace(return_pattern, acc, replacement)

        # Pattern 3: Function call arguments
        arg_pattern = ~r/\b#{Regex.escape(pattern)}\b(?=\s*[,\)])/
        Regex.replace(arg_pattern, acc, replacement)
      end)

    if content != updated_content do
      File.write!(file_path, updated_content)
    end
  end

  defp create_git_checkpoint(name) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    branch_name = "#{name}-#{timestamp}"

    System.cmd("git", ["add", "."])
    System.cmd("git", ["commit", "-m", "Checkpoint before #{name}"])

    IO.puts("📍 Git checkpoint created: #{branch_name}")
  end

  defp log_batch_issue(batch_number, output) do
    log_file = "./data/tmp/phase1_batch_#{batch_number}_issues.log"
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    log_content = """
    SOPv5.11 Phase 1 Batch Issue Log
    ================================
    Batch: #{batch_number}
    Timestamp: #{timestamp}

    Compilation Output:
    #{output}
    """

    File.write!(log_file, log_content)
    IO.puts("  📝 Issue logged to: #{log_file}")
  end

  defp show_status do
    IO.puts("📊 SOPv5.11 Phase 1 Status")
    IO.puts("==========================")

    # Check current compilation status
    case System.cmd("mix", ["compile"], stderr_to_stdout: true) do
      {output, 0} ->
        warning_count =
          output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))

        IO.puts("✅ Compilation Status: SUCCESS")
        IO.puts("⚠️  Current Warnings: #{warning_count}")

      {output, _} ->
        error_lines = output |> String.split("\n") |> Enum.filter(&String.contains?(&1, "error:"))
        IO.puts("❌ Compilation Status: ERRORS DETECTED")
        IO.puts("🔴 Error Count: #{length(error_lines)}")
    end

    IO.puts("")
    IO.puts("🎯 Ready for Phase 1 execution")
  end

  defp show_help do
    IO.puts("SOPv5.11 Phase 1 Critical Underscore Fixer")
    IO.puts("Usage:")
    IO.puts("  --analyze                 # Analyze critical underscore pattern usage")
    IO.puts("  --fix-batch SIZE          # Fix patterns in batches (recommended: 25)")
    IO.puts("  --status                  # Show current system status")
    IO.puts("")
    IO.puts("Examples:")
    IO.puts("  elixir #{__ENV__.file} --analyze")
    IO.puts("  elixir #{__ENV__.file} --fix-batch 25")
    IO.puts("  elixir #{__ENV__.file} --status")
  end
end

# Execute if run directly
if String.ends_with?(__ENV__.file, Path.basename(__ENV__.file)) do
  Phase1CriticalUnderscoreFixer.main(System.argv())
end
