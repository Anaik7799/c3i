#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule IntelligentUnderscoreFixer do
  @moduledoc """
  SOPv5.11 AEE Intelligent Underscore Variable Fixer
  Safely fixes underscore variable warnings by analyzing usage patterns
  """

  def main(args \\ []) do
    IO.puts("🚀 SOPv5.11 AEE: Intelligent Underscore Variable Fixer")
    IO.puts("📊 Target: 7,504 high-severity underscored variable warnings")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--analyze"] -> analyze_files()
      ["--fix-batch", batch_size] -> fix_batch(String.to_integer(batch_size))
      ["--fix-file", file_path] -> fix_single_file(file_path)
      ["--validate"] -> validate_fixes()
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --analyze                    # Analyze underscore issues intelligently
      elixir #{__ENV__.file} --fix-batch 25              # Fix batch of 25 files safely
      elixir #{__ENV__.file} --fix-file path/to/file.ex  # Fix specific file with validation
      elixir #{__ENV__.file} --validate                  # Validate current fixes
    """)
  end

  def analyze_files do
    IO.puts("\n📋 Analyzing underscore variable patterns intelligently...")

    files = find_elixir_files()

    all_issues = files
    |> Enum.flat_map(&analyze_file_intelligently/1)
    |> Enum.group_by(& &1.category)

    IO.puts("\n📊 Intelligent Analysis Results:")
    IO.puts("├── Total files analyzed: #{length(files)}")

    Enum.each(all_issues, fn {category, issues} ->
      IO.puts("├── #{category}: #{length(issues)} issues")
    end)

    IO.puts("└── Total issues: #{Enum.reduce(all_issues, 0, fn {_, v}, acc -> acc + length(v) end)}")

    save_analysis_results(all_issues)
  end

  def fix_batch(batch_size) do
    IO.puts("\n🔧 Fixing batch of #{batch_size} files with intelligence...")

    analysis_file = find_latest_analysis()

    if analysis_file && File.exists?(analysis_file) do
      issues = File.read!(analysis_file) |> Jason.decode!(keys: :atoms)

      # Get safest fixes first - parameter/usage mismatches
      safe_fixes = Map.get(issues, :parameter_usage_mismatch, [])

      files_to_fix = safe_fixes
      |> Enum.map(& &1.file)
      |> Enum.uniq()
      |> Enum.take(batch_size)

      IO.puts("📋 Files in this batch:")
      Enum.each(files_to_fix, fn file ->
        issue_count = Enum.count(safe_fixes, &(&1.file == file))
        IO.puts("  ├── #{file} (#{issue_count} issues)")
      end)

      fixed_count = Enum.reduce(files_to_fix, 0, fn file, acc ->
        if fix_single_file(file), do: acc + 1, else: acc
      end)

      IO.puts("\n✅ Batch completed: #{fixed_count}/#{length(files_to_fix)} files successfully fixed")
    else
      IO.puts("❌ Run --analyze first to generate analysis data")
    end
  end

  def fix_single_file(file_path) do
    IO.puts("🔧 Analyzing and fixing: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        issues = analyze_file_intelligently(file_path)

        if length(issues) > 0 do
          IO.puts("  📋 Found #{length(issues)} potential fixes")

          fixed_content = apply_intelligent_fixes(content, issues)

          if fixed_content != content do
            # Validate the fix doesn't break syntax
            if validate_elixir_syntax(fixed_content) do
              File.write!(file_path, fixed_content)
              IO.puts("  ✅ Successfully fixed #{file_path}")
              true
            else
              IO.puts("  ❌ Fix would break syntax in #{file_path}, skipping")
              false
            end
          else
            IO.puts("  ℹ️ No changes needed in #{file_path}")
            true
          end
        else
          IO.puts("  ℹ️ No underscore issues found in #{file_path}")
          true
        end

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
        false
    end
  end

  defp analyze_file_intelligently(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        find_intelligent_underscore_issues(content, file_path)
      {:error, _} ->
        []
    end
  end

  defp find_intelligent_underscore_issues(content, file_path) do
    lines = String.split(content, "\n")

    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      analyze_line_for_parameter_issues(line, line_num, file_path, content)
    end)
  end

  defp analyze_line_for_parameter_issues(line, line_num, file_path, full_content) do
    cond do
      # Function definition with potential parameter/usage mismatch
      String.match?(line, ~r/def\s+\w+.*\(.*_\w+.*\)/) ->
        analyze_function_parameter_usage(line, line_num, file_path, full_content)

      # Variable usage that might need underscore removed
      String.match?(line, ~r/_\w+\.\w+|_\w+\s*\||_\w+\s*\]/) ->
        [%{
          category: :variable_usage_underscore,
          file: file_path,
          line_num: line_num,
          line: String.trim(line),
          description: "Underscored variable being used"
        }]

      true -> []
    end
  end

  defp analyze_function_parameter_usage(def_line, line_num, file_path, full_content) do
    # Extract actual parameters from function definition
    case Regex.run(~r/def\s+\w+\s*\((.*?)\)/, def_line) do
      [_, params_str] ->
        # Find parameters that start with underscore in the parameter list
        underscored_params = Regex.scan(~r/\b_(\w+)/, params_str)
        |> Enum.map(fn [full_match, param] -> {full_match, param} end)

        # For each underscored parameter, check if it's used without underscore in function body
        underscored_params
        |> Enum.flat_map(fn {full_param, param_name} ->
          # Look for usage of the parameter without underscore in function body
          # We need to find the function body for this specific function
          function_body = extract_function_body(full_content, line_num)
          usage_pattern = ~r/\b#{param_name}\b(?![\w_])/

          if function_body && Regex.match?(usage_pattern, function_body) do
            [%{
              category: :parameter_usage_mismatch,
              file: file_path,
              line_num: line_num,
              line: String.trim(def_line),
              parameter: full_param,
              used_as: param_name,
              description: "Parameter defined as #{full_param} but used as #{param_name}"
            }]
          else
            []
          end
        end)

      _ -> []
    end
  end

  defp extract_function_body(content, def_line_num) do
    lines = String.split(content, "\n")

    # Start from the function definition line
    # Find the matching 'end' for this function
    {_, function_lines} = lines
    |> Enum.with_index(1)
    |> Enum.drop(def_line_num - 1)
    |> Enum.reduce_while({0, []}, fn {line, _line_num}, {depth, acc} ->
      cond do
        String.match?(line, ~r/\b(def|defp|if|case|cond|with|try|receive)\b/) ->
          {:cont, {depth + 1, [line | acc]}}
        String.match?(line, ~r/^\s*end\s*$/) ->
          if depth == 1 do
            {:halt, {depth, [line | acc]}}
          else
            {:cont, {depth - 1, [line | acc]}}
          end
        true ->
          {:cont, {depth, [line | acc]}}
      end
    end)

    function_lines |> Enum.reverse() |> Enum.join("\n")
  end

  defp apply_intelligent_fixes(content, issues) do
    # Group issues by category and apply fixes
    grouped_issues = Enum.group_by(issues, & &1.category)

    content
    |> apply_parameter_mismatch_fixes(Map.get(grouped_issues, :parameter_usage_mismatch, []))
    |> apply_variable_usage_fixes(Map.get(grouped_issues, :variable_usage_underscore, []))
  end

  defp apply_parameter_mismatch_fixes(content, issues) do
    # For parameter/usage mismatches, change the parameter to match usage
    Enum.reduce(issues, content, fn issue, acc ->
      # Replace _param with param in function definition
      old_param = issue.parameter
      new_param = issue.used_as

      # Only replace in the specific function definition line
      lines = String.split(acc, "\n")

      updated_lines = Enum.with_index(lines, 1)
      |> Enum.map(fn {line, line_num} ->
        if line_num == issue.line_num do
          # Replace parameter in function definition
          String.replace(line, ~r/\b#{Regex.escape(old_param)}\b/, new_param)
        else
          line
        end
      end)

      Enum.join(updated_lines, "\n")
    end)
  end

  defp apply_variable_usage_fixes(content, issues) do
    # For variable usage fixes, remove underscores from usage
    Enum.reduce(issues, content, fn issue, acc ->
      line_content = issue.line

      # Find underscored variables being used and remove underscore
      fixed_line = line_content
      |> String.replace(~r/_(\w+)\./, "\\1.")
      |> String.replace(~r/\|\s*_(\w+)\s*\|/, "| \\1 |")
      |> String.replace(~r/\[_(\w+)\s*\|/, "[\\1 |")
      |> String.replace(~r/\{:ok,\s*_(\w+)\}/, "{:ok, \\1}")

      String.replace(acc, line_content, fixed_line)
    end)
  end

  defp validate_elixir_syntax(content) do
    # Write to temporary file and try to compile
    temp_file = "/tmp/validate_syntax_#{:rand.uniform(10000)}.ex"

    try do
      File.write!(temp_file, content)

      case System.cmd("elixir", ["-c", temp_file], stderr_to_stdout: true) do
        {_output, 0} -> true
        {_output, _} -> false
      end
    rescue
      _ -> false
    after
      File.rm(temp_file)
    end
  end

  def validate_fixes do
    IO.puts("\n🔍 Validating current fixes...")

    # Try to compile the project
    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ All fixes validated successfully - no compilation errors")
        true
      {output, _} ->
        IO.puts("❌ Compilation errors found:")
        IO.puts(output)
        false
    end
  end

  defp find_elixir_files do
    Path.wildcard("lib/**/*.ex")
    |> Enum.filter(&File.exists?/1)
  end

  defp find_latest_analysis do
    case File.ls("./data/tmp") do
      {:ok, files} ->
        files
        |> Enum.filter(&String.contains?(&1, "underscore-analysis"))
        |> Enum.sort(:desc)
        |> List.first()
        |> case do
          nil -> nil
          filename -> "./data/tmp/#{filename}"
        end
      _ -> nil
    end
  end

  defp save_analysis_results(issues) do
    timestamp = current_timestamp()
    filename = "./data/tmp/#{timestamp}-intelligent-underscore-analysis.json"

    File.write!(filename, Jason.encode!(issues, pretty: true))
    IO.puts("\n💾 Intelligent analysis saved to: #{filename}")
  end

  defp current_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Execute
IntelligentUnderscoreFixer.main(System.argv())