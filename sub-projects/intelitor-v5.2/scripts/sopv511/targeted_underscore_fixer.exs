#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule TargetedUnderscoreFixer do
  @moduledoc """
  SOPv5.11 AEE Targeted Underscore Variable Fixer
  Focuses on the two main patterns from compilation warnings
  """

  def main(args \\ []) do
    IO.puts("🚀 SOPv5.11 AEE: Targeted Underscore Variable Fixer")
    IO.puts("📊 Fixing specific underscore warning patterns")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--fix-file", file_path] -> fix_single_file(file_path)
      ["--fix-batch", count] -> fix_batch_files(String.to_integer(count))
      ["--test"] -> test_compilation()
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --fix-file path/to/file.ex  # Fix specific file
      elixir #{__ENV__.file} --fix-batch 10             # Fix first 10 files with warnings
      elixir #{__ENV__.file} --test                     # Test compilation
    """)
  end

  def fix_single_file(file_path) do
    IO.puts("🔧 Fixing underscore warnings in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = apply_targeted_fixes(content)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Fixed underscore warnings in #{file_path}")

          # Log the changes
          log_file = "./data/tmp/#{current_timestamp()}-underscore-fixes.log"
          log_entry = "Fixed: #{file_path}\n"
          File.write!(log_file, log_entry, [:append])
        else
          IO.puts("  ℹ️ No underscore fixes needed in #{file_path}")
        end

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  def fix_batch_files(count) do
    IO.puts("🔧 Fixing underscore warnings in batch of #{count} files...")

    # Files with underscore warnings from the compilation output
    problem_files = [
      "lib/indrajaal/alarms/correlation_engine.ex",
      "lib/indrajaal/accounts/changes/hash_password.ex",
      "lib/indrajaal/accounts/changes/send_confirmation_email.ex",
      "lib/indrajaal/accounts/changes/generate_username.ex",
      "lib/indrajaal/accounts/authentication.ex",
      "lib/indrajaal/accounts/session_security.ex",
      "lib/indrajaal/ai/security/ml_threat_detection.ex",
      "lib/indrajaal/agent_comments/comprehensive_agent_integrator.ex",
      "lib/indrajaal/alarms/analytics_engine.ex"
    ]

    files_to_fix = Enum.take(problem_files, count)

    IO.puts("📋 Files to fix:")
    Enum.each(files_to_fix, fn file ->
      IO.puts("  ├── #{file}")
    end)

    fixed_count = Enum.reduce(files_to_fix, 0, fn file, acc ->
      fix_single_file(file)
      acc + 1
    end)

    IO.puts("\n✅ Batch completed: #{fixed_count} files processed")
  end

  def test_compilation do
    IO.puts("🧪 Testing compilation after fixes...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful - no warnings!")
        true
      {output, _} ->
        IO.puts("❌ Compilation warnings/errors still present:")

        # Show just the first few warnings
        warnings = output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "warning:"))
        |> Enum.take(10)

        Enum.each(warnings, fn warning ->
          IO.puts("  #{warning}")
        end)

        false
    end
  end

  defp apply_targeted_fixes(content) do
    content
    |> fix_underscored_variable_usage()
    |> fix_unused_variables()
  end

  defp fix_underscored_variable_usage(content) do
    # Pattern: "_alarm" is used after being set -> change to "alarm"
    # These are variables that should NOT have underscore prefix because they're being used

    content
    # Fix _alarm usage in correlation engine
    |> String.replace(~r/\b_alarm\b/, "alarm")
    # Fix other common underscored variables being used
    |> String.replace(~r/\(\s*_(\w+)\s*\)/, "(\\1)")  # function calls like get_all_correlations(_alarm)
    |> String.replace(~r/\[_(\w+)\s*\|/, "[\\1 |")    # list patterns like [_alarm | rest]
    |> String.replace(~r/\{:ok,\s*_(\w+)\}/, "{:ok, \\1}")  # tuples like {:ok, _alarm}
  end

  defp fix_unused_variables(content) do
    # Pattern: variables that are truly unused and need underscore prefix
    lines = String.split(content, "\n")

    fixed_lines = Enum.map(lines, fn line ->
      cond do
        # Function parameters that are unused - add underscore
        String.match?(line, ~r/def\s+.*\(\s*changeset,\s*opts,\s*/) and String.contains?(line, "opts") ->
          String.replace(line, ~r/\bopts\b/, "_opts")

        String.match?(line, ~r/def\s+.*\(\s*opts\s*\)/) and String.contains?(line, "opts") ->
          String.replace(line, ~r/\bopts\b/, "_opts")

        String.match?(line, ~r/def\s+.*\(\s*.*,\s*user\s*\)/) and String.contains?(line, "user") ->
          String.replace(line, ~r/\buser\b/, "_user")

        String.match?(line, ~r/defp\s+.*\(\s*tenant_id.*\)\s*do/) and String.contains?(line, "tenant_id") ->
          String.replace(line, ~r/\btenant_id\b/, "_tenant_id")

        String.match?(line, ~r/defp\s+.*\(\s*user_id.*\)\s*do/) and String.contains?(line, "user_id") ->
          String.replace(line, ~r/\buser_id\b/, "_user_id")

        String.match?(line, ~r/def\s+init\s*\(\s*opts\s*\)/) ->
          String.replace(line, ~r/\bopts\b/, "_opts")

        String.match?(line, ~r/defp\s+.*\(\s*state.*\)\s*do/) and String.contains?(line, "state") ->
          String.replace(line, ~r/\bstate\b/, "_state")

        true -> line
      end
    end)

    Enum.join(fixed_lines, "\n")
  end

  defp current_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Execute
TargetedUnderscoreFixer.main(System.argv())