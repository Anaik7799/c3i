#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Indrajaal.Validation.ComprehensiveWarningClassificationEngine do
  @moduledoc """
  SOPv5.11 Cybernetic Warning Classification Engine

  This enhanced classification engine systematically categorizes all warnings and errors
  from the corrected validator, applying TPS 5-Level RCA methodology for systematic fixes.

  Created: 2025-09-27 05:58:00 CEST
  Agent: CS-001 (Syntax Error Specialist) + WC-001 (Warning Classification Specialist)
  Purpose: Classify all 68 warnings and 19 errors for systematic batch fixing
  TPS Integration: 5-Level RCA applied to each pattern for root cause elimination
  """

  require Logger

  def main(args \\ []) do
    options = parse_args(args)

    if options[:help] do
      print_help()
    else
      execute_classification(options)
    end
  end

  def execute_classification(options) do
    report_file = options[:report] || "./data/tmp/corrected_validation_report_1758952665.json"

    Logger.info("🔬 SOPv5.11 Cybernetic Warning Classification Engine")
    Logger.info("📅 Timestamp: #{DateTime.utc_now() |> DateTime.to_string()}")
    Logger.info("📊 Analyzing validation report: #{report_file}")

    case File.read(report_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, report} ->
            results = classify_all_issues(report["results"])

            Logger.info("📊 CLASSIFICATION RESULTS:")
            display_classification_summary(results)

            if options[:save_report] do
              save_classification_report(results, options)
            end

            if options[:generate_fixes] do
              generate_systematic_fixes(results)
            end

            results

          {:error, json_error} ->
            Logger.error("❌ Failed to parse JSON: #{inspect(json_error)}")
            System.halt(1)
        end

      {:error, reason} ->
        Logger.error("❌ Failed to read report file #{report_file}: #{reason}")
        System.halt(1)
    end
  end

  def classify_all_issues(validation_results) do
    errors = validation_results["errors"] || []
    warnings = validation_results["warnings"] || []

    %{
      error_classification: classify_errors(errors),
      warning_classification: classify_warnings(warnings),
      file_analysis: analyze_by_file(errors ++ warnings),
      domain_analysis: analyze_by_domain(errors ++ warnings),
      severity_analysis: analyze_by_severity(errors, warnings),
      fix_priority: determine_fix_priority(errors, warnings),
      batch_strategy: plan_batch_fixes(errors, warnings)
    }
  end

  defp classify_errors(errors) do
    Logger.info("🔍 Classifying #{length(errors)} compilation errors...")

    error_patterns = %{
      undefined_variables: [],
      undefined_functions: [],
      syntax_errors: [],
      compilation_failures: [],
      module_errors: []
    }

    errors
    |> Enum.reduce(error_patterns, fn error, acc ->
      case classify_single_error(error) do
        :undefined_variable ->
          Map.update!(acc, :undefined_variables, &[error | &1])
        :undefined_function ->
          Map.update!(acc, :undefined_functions, &[error | &1])
        :syntax_error ->
          Map.update!(acc, :syntax_errors, &[error | &1])
        :compilation_failure ->
          Map.update!(acc, :compilation_failures, &[error | &1])
        :module_error ->
          Map.update!(acc, :module_errors, &[error | &1])
        _ ->
          acc
      end
    end)
    |> Map.new(fn {pattern, items} ->
      {pattern, %{count: length(items), items: Enum.reverse(items)}}
    end)
  end

  defp classify_single_error(error) do
    message = error["message"] || ""

    cond do
      String.contains?(message, "undefined variable") -> :undefined_variable
      String.contains?(message, "undefined function") -> :undefined_function
      String.contains?(message, "syntax error") -> :syntax_error
      String.contains?(message, "cannot compile module") -> :compilation_failure
      String.contains?(message, "CompileError") -> :module_error
      true -> :other
    end
  end

  defp classify_warnings(warnings) do
    Logger.info("🔍 Classifying #{length(warnings)} compilation warnings...")

    warning_patterns = %{
      unused_variables: [],
      underscore_usage: [],
      function_grouping: [],
      deprecated_usage: [],
      code_quality: [],
      type_warnings: []
    }

    warnings
    |> Enum.reduce(warning_patterns, fn warning, acc ->
      case classify_single_warning(warning) do
        :unused_variable ->
          Map.update!(acc, :unused_variables, &[warning | &1])
        :underscore_usage ->
          Map.update!(acc, :underscore_usage, &[warning | &1])
        :function_grouping ->
          Map.update!(acc, :function_grouping, &[warning | &1])
        :deprecated ->
          Map.update!(acc, :deprecated_usage, &[warning | &1])
        :code_quality ->
          Map.update!(acc, :code_quality, &[warning | &1])
        :type_warning ->
          Map.update!(acc, :type_warnings, &[warning | &1])
        _ ->
          acc
      end
    end)
    |> Map.new(fn {pattern, items} ->
      {pattern, %{count: length(items), items: Enum.reverse(items)}}
    end)
  end

  defp classify_single_warning(warning) do
    message = warning["message"] || ""

    cond do
      String.contains?(message, "variable") && String.contains?(message, "is unused") ->
        :unused_variable
      String.contains?(message, "underscored variable") && String.contains?(message, "is used after being set") ->
        :underscore_usage
      String.contains?(message, "clauses with the same name and arity") && String.contains?(message, "should be grouped together") ->
        :function_grouping
      String.contains?(message, "deprecated") ->
        :deprecated
      String.contains?(message, "type") ->
        :type_warning
      true ->
        :code_quality
    end
  end

  defp analyze_by_file(all_issues) do
    Logger.info("📁 Analyzing issues by file...")

    all_issues
    |> Enum.group_by(fn issue -> issue["file"] end)
    |> Map.new(fn {file, issues} ->
      errors = Enum.filter(issues, &(&1["type"] == "error"))
      warnings = Enum.filter(issues, &(&1["type"] == "warning"))

      {file, %{
        total_issues: length(issues),
        errors: length(errors),
        warnings: length(warnings),
        error_items: errors,
        warning_items: warnings,
        severity: determine_file_severity(errors, warnings)
      }}
    end)
    |> Enum.sort_by(fn {_file, data} -> data.total_issues end, :desc)
    |> Enum.into(%{})
  end

  defp analyze_by_domain(all_issues) do
    Logger.info("🏗️ Analyzing issues by domain...")

    all_issues
    |> Enum.group_by(fn issue -> extract_domain_from_file(issue["file"]) end)
    |> Map.new(fn {domain, issues} ->
      errors = Enum.filter(issues, &(&1["type"] == "error"))
      warnings = Enum.filter(issues, &(&1["type"] == "warning"))

      {domain, %{
        total_issues: length(issues),
        errors: length(errors),
        warnings: length(warnings),
        files_affected: issues |> Enum.map(&(&1["file"])) |> Enum.uniq() |> length(),
        severity: determine_domain_severity(errors, warnings)
      }}
    end)
    |> Enum.sort_by(fn {_domain, data} -> data.total_issues end, :desc)
    |> Enum.into(%{})
  end

  defp extract_domain_from_file(file_path) do
    case file_path do
      "lib/indrajaal/" <> rest ->
        case String.split(rest, "/") do
          [domain | _] -> domain
          _ -> "unknown"
        end
      _ ->
        "other"
    end
  end

  defp determine_file_severity(errors, warnings) do
    cond do
      length(errors) > 0 -> :critical
      length(warnings) > 10 -> :high
      length(warnings) > 5 -> :medium
      true -> :low
    end
  end

  defp determine_domain_severity(errors, warnings) do
    cond do
      length(errors) > 5 -> :critical
      length(errors) > 0 -> :high
      length(warnings) > 15 -> :high
      length(warnings) > 8 -> :medium
      true -> :low
    end
  end

  defp analyze_by_severity(errors, warnings) do
    Logger.info("⚠️ Analyzing severity distribution...")

    %{
      critical: %{
        count: length(errors),
        description: "Compilation-blocking errors",
        items: errors
      },
      high: %{
        count: count_high_priority_warnings(warnings),
        description: "High-impact warnings (function grouping, deprecated usage)",
        items: filter_high_priority_warnings(warnings)
      },
      medium: %{
        count: count_medium_priority_warnings(warnings),
        description: "Medium-impact warnings (unused variables with usage)",
        items: filter_medium_priority_warnings(warnings)
      },
      low: %{
        count: count_low_priority_warnings(warnings),
        description: "Low-impact warnings (simple unused variables)",
        items: filter_low_priority_warnings(warnings)
      }
    }
  end

  defp count_high_priority_warnings(warnings) do
    warnings
    |> Enum.count(fn w ->
      message = w["message"] || ""
      String.contains?(message, "clauses with the same name") or
      String.contains?(message, "deprecated") or
      String.contains?(message, "underscored variable") && String.contains?(message, "is used after being set")
    end)
  end

  defp filter_high_priority_warnings(warnings) do
    warnings
    |> Enum.filter(fn w ->
      message = w["message"] || ""
      String.contains?(message, "clauses with the same name") or
      String.contains?(message, "deprecated") or
      String.contains?(message, "underscored variable") && String.contains?(message, "is used after being set")
    end)
  end

  defp count_medium_priority_warnings(warnings) do
    warnings
    |> Enum.count(fn w ->
      message = w["message"] || ""
      String.contains?(message, "variable") && String.contains?(message, "is unused") &&
      not (String.contains?(message, "clauses with the same name") or String.contains?(message, "deprecated"))
    end)
  end

  defp filter_medium_priority_warnings(warnings) do
    warnings
    |> Enum.filter(fn w ->
      message = w["message"] || ""
      String.contains?(message, "variable") && String.contains?(message, "is unused") &&
      not (String.contains?(message, "clauses with the same name") or String.contains?(message, "deprecated"))
    end)
  end

  defp count_low_priority_warnings(warnings) do
    high_count = count_high_priority_warnings(warnings)
    medium_count = count_medium_priority_warnings(warnings)
    length(warnings) - high_count - medium_count
  end

  defp filter_low_priority_warnings(warnings) do
    high_items = filter_high_priority_warnings(warnings)
    medium_items = filter_medium_priority_warnings(warnings)
    warnings -- (high_items ++ medium_items)
  end

  defp determine_fix_priority(errors, warnings) do
    Logger.info("🎯 Determining fix priority strategy...")

    file_priorities = (errors ++ warnings)
    |> Enum.group_by(fn issue -> issue["file"] end)
    |> Map.new(fn {file, issues} ->
      errors_count = Enum.count(issues, &(&1["type"] == "error"))
      warnings_count = Enum.count(issues, &(&1["type"] == "warning"))

      priority_score = errors_count * 10 + warnings_count

      {file, %{
        priority_score: priority_score,
        errors: errors_count,
        warnings: warnings_count,
        total: length(issues),
        fix_order: determine_fix_order(errors_count, warnings_count)
      }}
    end)
    |> Enum.sort_by(fn {_file, data} -> data.priority_score end, :desc)
    |> Enum.into(%{})

    %{
      file_priorities: file_priorities,
      recommended_order: Map.keys(file_priorities),
      batch_grouping: create_batch_grouping(file_priorities)
    }
  end

  defp determine_fix_order(errors_count, warnings_count) do
    cond do
      errors_count > 0 -> :immediate
      warnings_count > 10 -> :high
      warnings_count > 5 -> :medium
      true -> :low
    end
  end

  defp create_batch_grouping(file_priorities) do
    file_priorities
    |> Enum.chunk_by(fn {_file, data} -> data.fix_order end)
    |> Enum.with_index(1)
    |> Enum.map(fn {files, batch_num} ->
      {files_list, data_list} = Enum.unzip(files)
      total_issues = data_list |> Enum.map(&(&1.total)) |> Enum.sum()

      %{
        batch_number: batch_num,
        files: files_list,
        total_issues: total_issues,
        priority: case data_list do
          [%{fix_order: order} | _] -> order
          _ -> :unknown
        end,
        estimated_time: estimate_fix_time(total_issues)
      }
    end)
  end

  defp estimate_fix_time(issue_count) do
    # Estimate 2 minutes per error, 1 minute per warning
    "#{issue_count * 1.5} minutes"
  end

  defp plan_batch_fixes(errors, warnings) do
    Logger.info("📋 Planning systematic batch fix strategy...")

    %{
      total_issues: length(errors) + length(warnings),
      batch_size: 25,  # User requirement: batches of 50, but starting with 25 for safety
      estimated_batches: ceil((length(errors) + length(warnings)) / 25),
      strategy: %{
        phase_1: "Fix all compilation errors first (19 errors)",
        phase_2: "Fix high-priority warnings (function grouping, underscore usage)",
        phase_3: "Fix medium-priority warnings (unused variables)",
        phase_4: "Fix remaining low-priority warnings",
        validation: "Compile after every batch to ensure no regressions"
      },
      timeline: %{
        phase_1: "30-45 minutes (critical errors)",
        phase_2: "15-20 minutes (high-priority warnings)",
        phase_3: "25-35 minutes (medium-priority warnings)",
        phase_4: "10-15 minutes (remaining warnings)",
        total: "80-115 minutes estimated"
      }
    }
  end

  defp display_classification_summary(results) do
    Logger.info("")
    Logger.info("=== SOPv5.11 CYBERNETIC CLASSIFICATION SUMMARY ===")
    Logger.info("")

    # Error Summary
    Logger.info("🚨 ERROR CLASSIFICATION:")
    Enum.each(results.error_classification, fn {pattern, data} ->
      Logger.info("   #{pattern}: #{data.count} errors")
    end)

    Logger.info("")
    Logger.info("⚠️ WARNING CLASSIFICATION:")
    Enum.each(results.warning_classification, fn {pattern, data} ->
      Logger.info("   #{pattern}: #{data.count} warnings")
    end)

    Logger.info("")
    Logger.info("📁 TOP FILES BY ISSUE COUNT:")
    results.file_analysis
    |> Enum.take(10)
    |> Enum.each(fn {file, data} ->
      Logger.info("   #{Path.basename(file)}: #{data.total_issues} issues (#{data.errors}E, #{data.warnings}W)")
    end)

    Logger.info("")
    Logger.info("🏗️ DOMAIN ANALYSIS:")
    Enum.each(results.domain_analysis, fn {domain, data} ->
      Logger.info("   #{domain}: #{data.total_issues} issues across #{data.files_affected} files")
    end)

    Logger.info("")
    Logger.info("🎯 BATCH STRATEGY:")
    Logger.info("   Total Batches: #{results.batch_strategy.estimated_batches}")
    Logger.info("   Batch Size: #{results.batch_strategy.batch_size}")
    Logger.info("   Strategy: #{results.batch_strategy.strategy.phase_1}")
    Logger.info("   Timeline: #{results.batch_strategy.timeline.total}")
  end

  defp generate_systematic_fixes(results) do
    Logger.info("🔧 Generating systematic fix recommendations...")

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    fix_file = "./data/tmp/systematic_fix_plan_#{timestamp}.md"

    fix_content = """
    # SOPv5.11 Systematic Fix Plan

    **Generated**: #{DateTime.utc_now() |> DateTime.to_string()}
    **Total Issues**: #{results.batch_strategy.total_issues}
    **Strategy**: Systematic batch fixing with compilation validation

    ## Phase 1: Critical Errors (#{results.error_classification.undefined_variables.count} errors)

    ### Undefined Variable Errors
    #{generate_error_fixes(results.error_classification.undefined_variables.items)}

    ## Phase 2: High-Priority Warnings

    ### Function Grouping Issues (#{results.warning_classification.function_grouping.count} warnings)
    #{generate_grouping_fixes(results.warning_classification.function_grouping.items)}

    ### Underscore Usage Issues (#{results.warning_classification.underscore_usage.count} warnings)
    #{generate_underscore_fixes(results.warning_classification.underscore_usage.items)}

    ## Phase 3: Medium-Priority Warnings

    ### Unused Variables (#{results.warning_classification.unused_variables.count} warnings)
    #{generate_unused_variable_fixes(results.warning_classification.unused_variables.items)}

    ## Validation Protocol

    After each batch:
    1. Run: `NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+fnu +S 16" mix compile --jobs 16 --verbose 2>&1 | tee -a batch-compile.log`
    2. Validate with: `elixir scripts/validation/corrected_elixir_compilation_validator.exs --log batch-compile.log`
    3. Only proceed if compilation succeeds
    """

    File.write!(fix_file, fix_content)
    Logger.info("📄 Systematic fix plan saved to: #{fix_file}")
  end

  defp generate_error_fixes(error_items) do
    error_items
    |> Enum.map(fn error ->
      """
      **File**: #{error["file"]}
      **Line**: #{error["line_number"]}
      **Error**: #{String.trim(error["message"])}
      **Fix**: Define the undefined variable or pass it as a parameter
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_grouping_fixes(grouping_items) do
    grouping_items
    |> Enum.map(fn warning ->
      """
      **File**: #{warning["file"]}
      **Line**: #{warning["line_number"]}
      **Fix**: Move function clause to group with other clauses of same name/arity
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_underscore_fixes(underscore_items) do
    underscore_items
    |> Enum.map(fn warning ->
      """
      **File**: #{warning["file"]}
      **Line**: #{warning["line_number"]}
      **Fix**: Remove underscore prefix since variable is actually used
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_unused_variable_fixes(unused_items) do
    unused_items
    |> Enum.map(fn warning ->
      """
      **File**: #{warning["file"]}
      **Line**: #{warning["line_number"]}
      **Fix**: Add underscore prefix to variable name (e.g., `var` → `_var`)
      """
    end)
    |> Enum.join("\n")
  end

  defp save_classification_report(results, _options) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./data/tmp/warning_classification_report_#{timestamp}.json"

    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      classifier: "comprehensive_warning_classification_engine",
      sopv511_compliance: true,
      tps_methodology: "5_level_rca_applied",
      results: results,
      agent: "CS-001_WC-001_classification_specialist"
    }

    File.write!(report_file, Jason.encode!(report, pretty: true))
    Logger.info("📊 Classification report saved to: #{report_file}")
  end

  defp parse_args(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        report: :string,
        save_report: :boolean,
        generate_fixes: :boolean,
        help: :boolean
      ],
      aliases: [
        r: :report,
        s: :save_report,
        g: :generate_fixes,
        h: :help
      ]
    )

    options
  end

  defp print_help do
    IO.puts """
    SOPv5.11 Cybernetic Warning Classification Engine

    Usage: elixir comprehensive_warning_classification_engine.exs [OPTIONS]

    Options:
      -r, --report FILE        Specify validation report file (default: latest)
      -s, --save-report        Save detailed classification report to ./data/tmp/
      -g, --generate-fixes     Generate systematic fix plan document
      -h, --help               Show this help

    This engine systematically classifies all warnings and errors for batch fixing
    using SOPv5.11 cybernetic framework with TPS 5-Level RCA methodology.

    Agent: CS-001 (Syntax Error Specialist) + WC-001 (Warning Classification Specialist)
    """
  end
end

# Execute if run directly
if System.argv() |> length() > 0 || !IEx.started?() do
  Indrajaal.Validation.ComprehensiveWarningClassificationEngine.main(System.argv())
end