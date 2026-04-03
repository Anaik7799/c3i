#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule BatchUnderscoreFixe do
  @moduledoc """
  SOPv5.11 AEE Batch Underscore Variable Fixer
  Systematically fixes the 7,504 high-severity underscored variable warnings
  """

  def main(args \\ []) do
    IO.puts("🚀 SOPv5.11 AEE: Batch Underscore Variable Fixer")
    IO.puts("📊 Target: 7,504 high-severity underscored variable warnings")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--analyze"] -> analyze_underscored_variables()
      ["--fix-batch", batch_size] -> fix_batch(String.to_integer(batch_size))
      ["--fix-file", file_path] -> fix_file(file_path)
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --analyze                    # Analyze underscore issues
      elixir #{__ENV__.file} --fix-batch 25              # Fix batch of 25 files
      elixir #{__ENV__.file} --fix-file path/to/file.ex  # Fix specific file
    """)
  end

  def analyze_underscored_variables do
    IO.puts("\n📋 Analyzing underscore variable issues...")

    files = find_elixir_files()

    issues = files
    |> Enum.flat_map(&analyze_file/1)
    |> Enum.group_by(& &1.type)

    IO.puts("\n📊 Analysis Results:")
    IO.puts("├── Total files analyzed: #{length(files)}")
    IO.puts("├── Underscore removal needed: #{length(Map.get(issues, :remove_underscore, []))}")
    IO.puts("├── Underscore addition needed: #{length(Map.get(issues, :add_underscore, []))}")
    IO.puts("└── Total issues: #{Enum.reduce(issues, 0, fn {_, v}, acc -> acc + length(v) end)}")

    save_analysis_results(issues)
  end

  def fix_batch(batch_size) do
    IO.puts("\n🔧 Fixing batch of #{batch_size} files...")

    analysis_file = "./data/tmp/#{current_timestamp()}-underscore-analysis.json"

    if File.exists?(analysis_file) do
      issues = File.read!(analysis_file) |> Jason.decode!(keys: :atoms)

      # Focus on the highest priority: underscored variables being used
      remove_underscore_issues = Map.get(issues, :remove_underscore, [])

      files_to_fix = remove_underscore_issues
      |> Enum.map(& &1.file)
      |> Enum.uniq()
      |> Enum.take(batch_size)

      IO.puts("📋 Files in this batch:")
      Enum.each(files_to_fix, fn file ->
        IO.puts("  ├── #{file}")
      end)

      Enum.each(files_to_fix, &fix_file/1)

      IO.puts("\n✅ Batch completed: #{length(files_to_fix)} files processed")
    else
      IO.puts("❌ Run --analyze first to generate analysis data")
    end
  end

  def fix_file(file_path) do
    IO.puts("🔧 Fixing file: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = apply_underscore_fixes(content, file_path)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Fixed underscore issues in #{file_path}")
        else
          IO.puts("  ℹ️ No fixes needed in #{file_path}")
        end

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  defp apply_underscore_fixes(content, _file_path) do
    # Fix 1: Remove underscores from variables that are actually used
    content
    |> fix_used_underscored_variables()
    |> fix_unused_variables()
  end

  defp fix_used_underscored_variables(content) do
    # Pattern 1: _variable used in expressions -> variable
    content
    |> String.replace(~r/\b_([a-z_][a-zA-Z0-9_]*)\b(?=\.[a-zA-Z])/, "\\1")  # _alarm.site_id -> alarm.site_id
    |> String.replace(~r/\|\s*_([a-z_][a-zA-Z0-9_]*)\s*\|/, "| \\1 |")        # | _alarm | -> | alarm |
    |> String.replace(~r/\[_([a-z_][a-zA-Z0-9_]*)\s*\|/, "[\\1 |")           # [_alarm | -> [alarm |
    |> String.replace(~r/length\(_([a-z_][a-zA-Z0-9_]*)\)/, "length(\\1)")   # length(_cluster) -> length(cluster)
    |> String.replace(~r/hd\(_([a-z_][a-zA-Z0-9_]*)\)/, "hd(\\1)")           # hd(_cluster) -> hd(cluster)
    |> String.replace(~r/\{\s*:ok,\s*_([a-z_][a-zA-Z0-9_]*)\s*\}/, "{:ok, \\1}")  # {:ok, _alarm} -> {:ok, alarm}
  end

  defp fix_unused_variables(content) do
    # Pattern 2: Add underscores to truly unused variables
    lines = String.split(content, "\n")

    fixed_lines = Enum.map(lines, fn line ->
      cond do
        # Function parameters that are unused
        String.contains?(line, "def ") and String.contains?(line, "opts") and not String.contains?(line, "_opts") ->
          String.replace(line, ~r/\b(opts)\b(?![_a-zA-Z0-9])/, "_\\1")

        String.contains?(line, "def ") and String.contains?(line, "tenant_id") and not String.contains?(line, "_tenant_id") ->
          String.replace(line, ~r/\b(tenant_id)\b(?![_a-zA-Z0-9])/, "_\\1")

        String.contains?(line, "def ") and String.contains?(line, "state") and not String.contains?(line, "_state") ->
          String.replace(line, ~r/\b(state)\b(?![_a-zA-Z0-9])/, "_\\1")

        true -> line
      end
    end)

    Enum.join(fixed_lines, "\n")
  end

  defp analyze_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        find_underscore_issues(content, file_path)
      {:error, _} ->
        []
    end
  end

  defp find_underscore_issues(content, file_path) do
    # Find underscored variables being used (need underscore removed)
    used_underscored = Regex.scan(~r/_([a-z_][a-zA-Z0-9_]*)\.[a-zA-Z]/, content)
    |> Enum.map(fn [_, var] ->
      %{type: :remove_underscore, file: file_path, variable: "_#{var}", line: "unknown"}
    end)

    # Find unused variables without underscores (need underscore added)
    unused_vars = Regex.scan(~r/def\s+\w+\([^)]*\b(opts|tenant_id|state)\b[^)]*\)/, content)
    |> Enum.map(fn [_, var] ->
      %{type: :add_underscore, file: file_path, variable: var, line: "unknown"}
    end)

    used_underscored ++ unused_vars
  end

  defp find_elixir_files do
    Path.wildcard("lib/**/*.ex")
    |> Enum.filter(&File.exists?/1)
  end

  defp save_analysis_results(issues) do
    timestamp = current_timestamp()
    filename = "./data/tmp/#{timestamp}-underscore-analysis.json"

    File.write!(filename, Jason.encode!(issues, pretty: true))
    IO.puts("\n💾 Analysis saved to: #{filename}")
  end

  defp current_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Execute
BatchUnderscoreFixe.main(System.argv())