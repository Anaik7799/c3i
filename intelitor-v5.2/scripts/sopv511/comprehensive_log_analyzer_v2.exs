#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.ComprehensiveLogAnalyzer do
  @moduledoc """
  SOPv5.11 Cybernetic Compilation Log Analyzer v2
  Complete analysis of 1-compile.log without head/tail truncation
  """

  def main do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")

    IO.puts("🚀 SOPv5.11 Comprehensive Compilation Log Analysis Started")
    IO.puts("📋 Timestamp: #{timestamp}")
    IO.puts("📄 Processing: 1-compile.log")

    case analyze_compilation_log("1-compile.log") do
      {:ok, analysis} ->
        IO.puts("✅ Analysis completed successfully")
        save_and_display_analysis(analysis, timestamp)

      {:error, reason} ->
        IO.puts("❌ Analysis failed: #{reason}")
        System.halt(1)
    end
  end

  def analyze_compilation_log(log_path) do
    IO.puts("🔍 Reading complete compilation log: #{log_path}")

    case File.read(log_path) do
      {:ok, content} ->
        IO.puts("📊 Log file size: #{Float.round(byte_size(content) / 1024 / 1024, 2)} MB")
        lines = String.split(content, "\n")
        IO.puts("📊 Total lines: #{length(lines)}")

        analysis = %{
          total_lines: length(lines),
          file_size_bytes: byte_size(content),
          warnings: analyze_warnings(lines),
          errors: analyze_errors(lines),
          unused_functions: analyze_unused_functions(lines),
          critical_files: analyze_critical_files(lines)
        }

        # Add criticality analysis
        analysis = Map.put(analysis, :criticality_analysis, perform_criticality_analysis(analysis.unused_functions))

        {:ok, analysis}

      {:error, reason} ->
        {:error, "Failed to read log file: #{reason}"}
    end
  end

  defp analyze_warnings(lines) do
    IO.puts("🔍 Analyzing warning patterns...")

    patterns = %{
      "unused_variable" => ~r/warning: variable ".*" is unused/,
      "unused_function" => ~r/warning: function .* is unused/,
      "unused_import" => ~r/warning: unused import/,
      "unused_alias" => ~r/warning: unused alias/,
      "underscore_param" => ~r/warning: the underscore in "_.*" means the variable is ignored/,
      "deprecated" => ~r/warning: .*deprecated/,
      "pattern_match" => ~r/warning: this clause cannot match/,
      "type_spec" => ~r/warning: @spec .* but the actual function/,
      "dialyzer" => ~r/warning: .*\[dialyzer\]/,
      "other" => ~r/warning:/
    }

    results = Enum.reduce(patterns, %{}, fn {name, regex}, acc ->
      matches = Enum.filter(lines, &String.match?(&1, regex))
      Map.put(acc, name, matches)
    end)

    total = results |> Map.values() |> List.flatten() |> length()
    IO.puts("📊 Total warnings found: #{total}")

    Enum.each(results, fn {pattern, matches} ->
      IO.puts("  - #{pattern}: #{length(matches)}")
    end)

    results
  end

  defp analyze_errors(lines) do
    IO.puts("🔍 Analyzing error patterns...")

    patterns = %{
      "compilation_error" => ~r/\*\* \(CompileError\)/,
      "syntax_error" => ~r/\*\* \(SyntaxError\)/,
      "undefined_function" => ~r/undefined function/,
      "undefined_variable" => ~r/undefined variable/,
      "module_not_found" => ~r/could not compile module/,
      "other_error" => ~r/\*\* \(/
    }

    results = Enum.reduce(patterns, %{}, fn {name, regex}, acc ->
      matches = Enum.filter(lines, &String.match?(&1, regex))
      Map.put(acc, name, matches)
    end)

    total = results |> Map.values() |> List.flatten() |> length()
    IO.puts("📊 Total errors found: #{total}")

    Enum.each(results, fn {pattern, matches} ->
      IO.puts("  - #{pattern}: #{length(matches)}")
    end)

    results
  end

  defp analyze_unused_functions(lines) do
    IO.puts("🔍 Analyzing unused functions in detail...")

    unused_functions = lines
    |> Enum.filter(&(String.contains?(&1, "function") and String.contains?(&1, "is unused")))
    |> Enum.map(&parse_unused_function/1)
    |> Enum.filter(&(&1 != nil))

    IO.puts("📊 Unused functions found: #{length(unused_functions)}")
    unused_functions
  end

  defp parse_unused_function(line) do
    # Try different patterns for unused function warnings
    patterns = [
      ~r/warning: function ([\w\.]+)#([\w_\?!]+)\/(\d+) is unused/,
      ~r/warning: function ([\w_\?!]+)\/(\d+) is unused/
    ]

    case parse_with_patterns(line, patterns) do
      {module, function, arity} ->
        %{
          module: module,
          function: function,
          arity: arity,
          line: line,
          full_name: "#{function}/#{arity}"
        }
      nil -> nil
    end
  end

  defp parse_with_patterns(line, [pattern | rest]) do
    case Regex.run(pattern, line) do
      [_, module, function, arity] ->
        {module, function, String.to_integer(arity)}
      [_, function, arity] ->
        {"unknown", function, String.to_integer(arity)}
      nil ->
        parse_with_patterns(line, rest)
    end
  end

  defp parse_with_patterns(_line, []), do: nil

  defp analyze_critical_files(lines) do
    IO.puts("🔍 Analyzing critical files with most issues...")

    file_issues = lines
    |> Enum.filter(&(String.contains?(&1, "warning:") or String.contains?(&1, "** (")))
    |> Enum.map(&extract_file_path/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(20)

    IO.puts("📊 Top files with issues: #{length(file_issues)}")
    file_issues
  end

  defp extract_file_path(line) do
    case Regex.run(~r/(lib\/[\w\/\._]+\.ex)/, line) do
      [_, file_path] -> file_path
      _ -> nil
    end
  end

  defp perform_criticality_analysis(unused_functions) do
    IO.puts("🔍 Performing criticality analysis of unused functions...")

    classifications = unused_functions
    |> Enum.map(&classify_function/1)

    by_criticality = Enum.group_by(classifications, & &1.criticality)

    IO.puts("📊 Criticality analysis complete:")
    Enum.each([:safe_to_remove, :safe_to_comment, :investigate, :keep], fn level ->
      count = length(Map.get(by_criticality, level, []))
      IO.puts("  - #{level}: #{count} functions")
    end)

    %{
      classifications: classifications,
      by_criticality: by_criticality,
      summary: %{
        total: length(unused_functions),
        safe_to_remove: length(Map.get(by_criticality, :safe_to_remove, [])),
        safe_to_comment: length(Map.get(by_criticality, :safe_to_comment, [])),
        investigate: length(Map.get(by_criticality, :investigate, [])),
        keep: length(Map.get(by_criticality, :keep, []))
      }
    }
  end

  defp classify_function(func) do
    function_name = func.function

    {criticality, reasoning} = cond do
      # Private helper functions - usually safe to remove
      String.starts_with?(function_name, "do_") ->
        {:safe_to_remove, "Private helper function, safe to remove"}

      # Test helpers - safe to comment
      String.contains?(function_name, "test") or String.contains?(function_name, "mock") ->
        {:safe_to_comment, "Test helper function, safe to comment out"}

      # Public API functions - investigate first
      not String.starts_with?(function_name, "_") and func.arity > 0 ->
        {:investigate, "Public function, needs investigation before removal"}

      # Callback functions - keep
      function_name in ["init", "handle_call", "handle_cast", "handle_info", "terminate"] ->
        {:keep, "Framework callback, should not be removed"}

      # Default case
      true ->
        {:safe_to_comment, "Internal function, safe to comment out"}
    end

    action = case criticality do
      :safe_to_remove -> :remove
      :safe_to_comment -> :comment_out
      :investigate -> :manual_review
      :keep -> :no_action
    end

    Map.merge(func, %{
      criticality: criticality,
      recommended_action: action,
      reasoning: reasoning
    })
  end

  defp serialize_for_json(data) when is_map(data) do
    Enum.into(data, %{}, fn {k, v} -> {k, v} end)
  end

  defp save_and_display_analysis(analysis, timestamp) do
    IO.puts("💾 Saving analysis report...")

    report_path = "./data/tmp/#{timestamp}-sopv511-compilation-analysis-report.json"

    # Convert tuples to maps for JSON serialization
    serializable_analysis = %{
      timestamp: timestamp,
      total_lines: analysis.total_lines,
      file_size_bytes: analysis.file_size_bytes,
      warnings: serialize_for_json(analysis.warnings),
      errors: serialize_for_json(analysis.errors),
      unused_functions: analysis.unused_functions,
      critical_files: Enum.map(analysis.critical_files, fn {file, count} -> %{file: file, count: count} end),
      criticality_analysis: analysis.criticality_analysis
    }

    json_content = Jason.encode!(serializable_analysis, pretty: true)
    File.write!(report_path, json_content)

    IO.puts("✅ Report saved to: #{report_path}")

    display_summary(analysis)
    display_criticality_details(analysis.criticality_analysis)
  end

  defp display_summary(analysis) do
    IO.puts("\n📊 === SOPv5.11 COMPILATION ANALYSIS SUMMARY ===")
    IO.puts("📄 Total lines processed: #{analysis.total_lines}")
    IO.puts("📊 File size: #{Float.round(analysis.file_size_bytes / 1024 / 1024, 2)} MB")

    # Warning summary
    total_warnings = analysis.warnings |> Map.values() |> List.flatten() |> length()
    IO.puts("⚠️ Total warnings: #{total_warnings}")

    # Error summary
    total_errors = analysis.errors |> Map.values() |> List.flatten() |> length()
    IO.puts("❌ Total errors: #{total_errors}")

    # Top warning categories
    IO.puts("\n🔝 Top warning categories:")
    analysis.warnings
    |> Enum.sort_by(fn {_, warnings} -> length(warnings) end, :desc)
    |> Enum.take(5)
    |> Enum.each(fn {category, warnings} ->
      IO.puts("  #{category}: #{length(warnings)} warnings")
    end)

    # Critical files
    IO.puts("\n📁 Top 10 files with most issues:")
    analysis.critical_files
    |> Enum.take(10)
    |> Enum.each(fn {file, count} ->
      IO.puts("  #{file}: #{count} issues")
    end)
  end

  defp display_criticality_details(criticality_analysis) do
    IO.puts("\n🎯 === CRITICALITY ANALYSIS DETAILS ===")
    summary = criticality_analysis.summary

    IO.puts("📊 Summary:")
    IO.puts("  - Total unused functions: #{summary.total}")
    IO.puts("  - Safe to remove: #{summary.safe_to_remove}")
    IO.puts("  - Safe to comment: #{summary.safe_to_comment}")
    IO.puts("  - Needs investigation: #{summary.investigate}")
    IO.puts("  - Keep as-is: #{summary.keep}")

    # Show examples from each category
    Enum.each([:safe_to_remove, :safe_to_comment, :investigate], fn category ->
      functions = Map.get(criticality_analysis.by_criticality, category, [])
      if length(functions) > 0 do
        IO.puts("\n#{String.upcase(to_string(category))} (#{length(functions)} functions):")
        functions
        |> Enum.take(5)
        |> Enum.each(fn func ->
          IO.puts("  - #{func.module}.#{func.full_name}: #{func.reasoning}")
        end)

        if length(functions) > 5 do
          IO.puts("  ... and #{length(functions) - 5} more")
        end
      end
    end)

    IO.puts("\n✅ Analysis complete - ready for SOPv5.11 batch processing")
  end
end

# Execute
SOPv511.ComprehensiveLogAnalyzer.main()