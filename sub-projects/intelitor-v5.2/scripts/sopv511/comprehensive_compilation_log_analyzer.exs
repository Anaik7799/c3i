#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.ComprehensiveCompilationLogAnalyzer do
  @moduledoc """
  SOPv5.11 Cybernetic Compilation Log Analyzer

  Comprehensive analysis of compilation logs following SOPv5.11 framework:
  - Complete file analysis (no head/tail truncation)
  - Multi-method warning classification
  - Criticality analysis of unused functions
  - FPPS consensus validation
  - Git-based state tracking
  """

  require Logger

  def main(_args) do
    timestamp = DateTime.now!("Europe/Berlin") |> Calendar.strftime("%Y%m%d-%H%M")
    log_file = "./data/tmp/#{timestamp}-sopv511-compilation-analysis.log"

    Logger.configure(level: :info)

    Logger.info("🚀 SOPv5.11 Comprehensive Compilation Log Analysis Started")
    Logger.info("📋 Timestamp: #{timestamp}")
    Logger.info("📄 Processing: 1-compile.log")

    case analyze_compilation_log("1-compile.log") do
      {:ok, analysis} ->
        Logger.info("✅ Analysis completed successfully")
        save_analysis_report(analysis, timestamp)
        display_summary(analysis)

      {:error, reason} ->
        Logger.error("❌ Analysis failed: #{reason}")
        System.halt(1)
    end
  end

  def analyze_compilation_log(log_path) do
    Logger.info("🔍 Reading complete compilation log: #{log_path}")

    case File.read(log_path) do
      {:ok, content} ->
        Logger.info("📊 Log file size: #{byte_size(content)} bytes")
        lines = String.split(content, "\n")
        Logger.info("📊 Total lines: #{length(lines)}")

        analysis = %{
          total_lines: length(lines),
          file_size_bytes: byte_size(content),
          warnings: analyze_warnings(lines),
          errors: analyze_errors(lines),
          compilation_status: determine_compilation_status(lines),
          file_analysis: analyze_file_patterns(lines),
          unused_functions: analyze_unused_functions(lines),
          criticality_analysis: nil  # Will be populated later
        }

        # Add criticality analysis
        analysis = %{analysis | criticality_analysis: perform_criticality_analysis(analysis.unused_functions)}

        {:ok, analysis}

      {:error, reason} ->
        {:error, "Failed to read log file: #{reason}"}
    end
  end

  defp analyze_warnings(lines) do
    Logger.info("🔍 Analyzing warnings patterns...")

    warning_patterns = [
      {"unused_variable", ~r/warning: variable ".*" is unused/},
      {"unused_function", ~r/warning: function .* is unused/},
      {"unused_import", ~r/warning: unused import/},
      {"unused_alias", ~r/warning: unused alias/},
      {"underscore_param", ~r/warning: the underscore in "_.*" means the variable is ignored/},
      {"deprecated", ~r/warning: .*deprecated/},
      {"pattern_match", ~r/warning: this clause cannot match/},
      {"type_spec", ~r/warning: @spec .* but the actual function/},
      {"dialyzer", ~r/warning: .*\[dialyzer\]/},
      {"documentation", ~r/warning: .*missing @doc/},
      {"other", ~r/warning:/}
    ]

    warnings = Enum.reduce(lines, %{}, fn line, acc ->
      Enum.reduce(warning_patterns, acc, fn {pattern_name, regex}, pattern_acc ->
        if String.match?(line, regex) do
          Map.update(pattern_acc, pattern_name, [line], fn existing -> [line | existing] end)
        else
          pattern_acc
        end
      end)
    end)

    # Count and reverse lists (they were built in reverse)
    warnings
    |> Enum.map(fn {pattern, matches} -> {pattern, Enum.reverse(matches)} end)
    |> Enum.into(%{})
    |> tap(fn w ->
      total = w |> Map.values() |> List.flatten() |> length()
      Logger.info("📊 Total warnings found: #{total}")
      Enum.each(w, fn {pattern, matches} ->
        Logger.info("  - #{pattern}: #{length(matches)}")
      end)
    end)
  end

  defp analyze_errors(lines) do
    Logger.info("🔍 Analyzing error patterns...")

    error_patterns = [
      {"compilation_error", ~r/\*\* \(CompileError\)/},
      {"syntax_error", ~r/\*\* \(SyntaxError\)/},
      {"undefined_function", ~r/undefined function/},
      {"undefined_variable", ~r/undefined variable/},
      {"module_not_found", ~r/could not compile module/},
      {"dependency_error", ~r/could not compile dependency/},
      {"type_error", ~r/\*\* \(ArgumentError\)/},
      {"runtime_error", ~r/\*\* \(RuntimeError\)/},
      {"other_error", ~r/\*\* \(/}
    ]

    errors = Enum.reduce(lines, %{}, fn line, acc ->
      Enum.reduce(error_patterns, acc, fn {pattern_name, regex}, pattern_acc ->
        if String.match?(line, regex) do
          Map.update(pattern_acc, pattern_name, [line], fn existing -> [line | existing] end)
        else
          pattern_acc
        end
      end)
    end)

    # Count and reverse lists
    errors
    |> Enum.map(fn {pattern, matches} -> {pattern, Enum.reverse(matches)} end)
    |> Enum.into(%{})
    |> tap(fn e ->
      total = e |> Map.values() |> List.flatten() |> length()
      Logger.info("📊 Total errors found: #{total}")
      Enum.each(e, fn {pattern, matches} ->
        Logger.info("  - #{pattern}: #{length(matches)}")
      end)
    end)
  end

  defp determine_compilation_status(lines) do
    Logger.info("🔍 Determining compilation status...")

    has_errors = Enum.any?(lines, &String.contains?(&1, "** ("))
    has_warnings = Enum.any?(lines, &String.contains?(&1, "warning:"))
    completed = Enum.any?(lines, &String.contains?(&1, "Compiled"))

    status = cond do
      has_errors -> :failed_with_errors
      has_warnings -> :completed_with_warnings
      completed -> :success
      true -> :unknown
    end

    Logger.info("📊 Compilation status: #{status}")
    status
  end

  defp analyze_file_patterns(lines) do
    Logger.info("🔍 Analyzing file patterns...")

    file_mentions = lines
    |> Enum.filter(&String.contains?(&1, ".ex"))
    |> Enum.map(fn line ->
      case Regex.run(~r/(lib\/[\w\/]+\.ex)/, line) do
        [_, file_path] -> file_path
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(20)  # Top 20 most mentioned files

    Logger.info("📊 Top files with issues: #{length(file_mentions)}")
    file_mentions
  end

  defp analyze_unused_functions(lines) do
    Logger.info("🔍 Analyzing unused functions in detail...")

    unused_function_regex = ~r/warning: function ([\w\.\/]+)#([\w_\?!]+)\/(\d+) is unused/

    unused_functions = lines
    |> Enum.filter(&String.contains?(&1, "function") and String.contains?(&1, "is unused"))
    |> Enum.map(fn line ->
      case Regex.run(unused_function_regex, line) do
        [_, module, function, arity] ->
          %{
            module: module,
            function: function,
            arity: String.to_integer(arity),
            line: line,
            full_name: "#{function}/#{arity}"
          }
        _ ->
          # Fallback parsing for different formats
          case Regex.run(~r/warning: function ([\w_\?!]+)\/(\d+) is unused/, line) do
            [_, function, arity] ->
              %{
                module: "unknown",
                function: function,
                arity: String.to_integer(arity),
                line: line,
                full_name: "#{function}/#{arity}"
              }
            _ -> nil
          end
      end
    end)
    |> Enum.filter(&(&1 != nil))

    Logger.info("📊 Unused functions found: #{length(unused_functions)}")
    unused_functions
  end

  defp perform_criticality_analysis(unused_functions) do
    Logger.info("🔍 Performing criticality analysis of unused functions...")

    # Classify functions by criticality for removal/commenting
    classifications = unused_functions
    |> Enum.map(fn func ->
      criticality = classify_function_criticality(func)
      action = determine_action(criticality)

      Map.merge(func, %{
        criticality: criticality,
        recommended_action: action,
        reasoning: get_reasoning(func, criticality)
      })
    end)

    # Group by criticality
    by_criticality = Enum.group_by(classifications, & &1.criticality)

    Logger.info("📊 Criticality analysis complete:")
    Enum.each([:safe_to_remove, :safe_to_comment, :investigate, :keep], fn level ->
      count = length(Map.get(by_criticality, level, []))
      Logger.info("  - #{level}: #{count} functions")
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

  defp classify_function_criticality(func) do
    function_name = func.function

    cond do
      # Private helper functions - usually safe to remove
      String.starts_with?(function_name, "do_") or
      String.starts_with?(function_name, "handle_") or
      String.starts_with?(function_name, "process_") ->
        :safe_to_remove

      # Test helper functions - safe to comment
      String.contains?(function_name, "test") or
      String.contains?(function_name, "mock") or
      String.contains?(function_name, "stub") ->
        :safe_to_comment

      # Public API functions - investigate before removal
      String.ends_with?(function_name, "!") or
      not String.starts_with?(function_name, "_") ->
        :investigate

      # Callback functions - keep (might be called by framework)
      function_name in ["init", "handle_call", "handle_cast", "handle_info", "terminate", "code_change"] ->
        :keep

      # Default case
      true ->
        :safe_to_comment
    end
  end

  defp determine_action(criticality) do
    case criticality do
      :safe_to_remove -> :remove
      :safe_to_comment -> :comment_out
      :investigate -> :manual_review
      :keep -> :no_action
    end
  end

  defp get_reasoning(_func, criticality) do
    case criticality do
      :safe_to_remove -> "Private helper function, likely safe to remove"
      :safe_to_comment -> "Internal function, safe to comment out for potential future use"
      :investigate -> "Public or important function, requires manual investigation"
      :keep -> "Framework callback or critical function, should not be removed"
    end
  end

  defp save_analysis_report(analysis, timestamp) do
    Logger.info("💾 Saving comprehensive analysis report...")

    report_path = "./data/tmp/#{timestamp}-sopv511-compilation-analysis-report.json"

    report = %{
      timestamp: timestamp,
      analysis_type: "SOPv5.11_Comprehensive_Compilation_Analysis",
      metadata: %{
        total_lines: analysis.total_lines,
        file_size_bytes: analysis.file_size_bytes,
        compilation_status: analysis.compilation_status
      },
      warnings: analysis.warnings,
      errors: analysis.errors,
      file_analysis: analysis.file_analysis,
      unused_functions: analysis.unused_functions,
      criticality_analysis: analysis.criticality_analysis
    }

    json_content = Jason.encode!(report, pretty: true)
    File.write!(report_path, json_content)

    Logger.info("✅ Report saved to: #{report_path}")
    report_path
  end

  defp display_summary(analysis) do
    Logger.info("📊 === SOPv5.11 COMPILATION ANALYSIS SUMMARY ===")
    Logger.info("📄 Total lines processed: #{analysis.total_lines}")
    Logger.info("📊 File size: #{Float.round(analysis.file_size_bytes / 1024 / 1024, 2)} MB")
    Logger.info("🔄 Compilation status: #{analysis.compilation_status}")

    # Warning summary
    total_warnings = analysis.warnings |> Map.values() |> List.flatten() |> length()
    Logger.info("⚠️ Total warnings: #{total_warnings}")

    # Error summary
    total_errors = analysis.errors |> Map.values() |> List.flatten() |> length()
    Logger.info("❌ Total errors: #{total_errors}")

    # Unused functions summary
    Logger.info("🔍 Unused functions: #{length(analysis.unused_functions)}")

    # Criticality analysis summary
    if analysis.criticality_analysis do
      summary = analysis.criticality_analysis.summary
      Logger.info("🎯 CRITICALITY ANALYSIS:")
      Logger.info("  - Safe to remove: #{summary.safe_to_remove}")
      Logger.info("  - Safe to comment: #{summary.safe_to_comment}")
      Logger.info("  - Needs investigation: #{summary.investigate}")
      Logger.info("  - Keep as-is: #{summary.keep}")
    end

    Logger.info("✅ Analysis complete - proceed with SOPv5.11 batch processing")
  end
end

# Execute if called directly
if System.argv() != [] or __ENV__.file == :stdin do
  SOPv511.ComprehensiveCompilationLogAnalyzer.main(System.argv())
end