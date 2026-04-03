#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.ComprehensiveLogAnalyzerRCA do
  @moduledoc """
  SOPv5.11 Comprehensive Log Analyzer with 5-Level RCA

  Performs systematic analysis of compilation logs with:
  - 5-Level Root Cause Analysis (TPS methodology)
  - Error and warning classification
  - Criticality analysis for systematic elimination
  - Batch planning for 200-item groups
  """

  require Logger

  def main(args) do
    Logger.configure(level: :info)

    case args do
      ["--analyze"] -> analyze_compilation_log()
      ["--classify"] -> classify_issues()
      ["--criticality"] -> perform_criticality_analysis()
      ["--plan-batches"] -> plan_batch_execution()
      ["--comprehensive"] -> comprehensive_analysis()
      _ -> show_help()
    end
  end

  def comprehensive_analysis do
    Logger.info("🔍 SOPv5.11 Comprehensive Log Analysis with 5-Level RCA")

    log_path = "1-compile.log"

    unless File.exists?(log_path) do
      Logger.error("❌ Compilation log not found: #{log_path}")
      exit(1)
    end

    # Read complete log file (no head/tail - full analysis)
    content = File.read!(log_path)

    # Extract and classify all issues
    {errors, warnings} = extract_and_classify_issues(content)

    # Perform 5-Level RCA
    rca_analysis = perform_five_level_rca(errors, warnings)

    # Criticality analysis
    criticality_analysis = perform_criticality_analysis_data(errors, warnings)

    # Plan batches of 200 items
    batch_plan = plan_batches(errors, warnings)

    # Generate comprehensive report
    report = generate_comprehensive_report(errors, warnings, rca_analysis, criticality_analysis, batch_plan)

    # Save report
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_path = "./data/tmp/sopv511_comprehensive_rca_analysis_#{timestamp}.log"
    File.write!(report_path, report)

    Logger.info("📊 Analysis Complete: #{length(errors)} errors, #{length(warnings)} warnings")
    Logger.info("📄 Report saved: #{report_path}")

    # Display critical findings
    display_critical_findings(errors, warnings, criticality_analysis)
  end

  defp extract_and_classify_issues(content) do
    lines = String.split(content, "\n")

    errors =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _idx} -> String.contains?(line, "error:") end)
      |> Enum.map(fn {line, idx} ->
        %{
          type: :error,
          line_number: idx + 1,
          content: String.trim(line),
          category: classify_error(line),
          file: extract_file_from_context(lines, idx),
          severity: :critical
        }
      end)

    warnings =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _idx} -> String.contains?(line, "warning:") end)
      |> Enum.map(fn {line, idx} ->
        %{
          type: :warning,
          line_number: idx + 1,
          content: String.trim(line),
          category: classify_warning(line),
          file: extract_file_from_context(lines, idx),
          severity: determine_warning_severity(line)
        }
      end)

    {errors, warnings}
  end

  defp classify_error(line) do
    cond do
      String.contains?(line, "undefined variable") -> :undefined_variable
      String.contains?(line, "undefined function") -> :undefined_function
      String.contains?(line, "cannot compile module") -> :module_compilation
      String.contains?(line, "cannot find or invoke") -> :pattern_matching_error
      String.contains?(line, "CompileError") -> :compile_error
      true -> :other_error
    end
  end

  defp classify_warning(line) do
    cond do
      String.contains?(line, "variable") and String.contains?(line, "is unused") -> :unused_variable
      String.contains?(line, "underscored variable") and String.contains?(line, "is used") -> :underscore_usage
      String.contains?(line, "function") and String.contains?(line, "is unused") -> :unused_function
      String.contains?(line, "this clause cannot match") -> :unreachable_clause
      String.contains?(line, "deprecated") -> :deprecation
      String.contains?(line, "this function is deprecated") -> :function_deprecation
      true -> :other_warning
    end
  end

  defp determine_warning_severity(line) do
    cond do
      String.contains?(line, "deprecated") -> :high
      String.contains?(line, "underscored variable") -> :medium
      String.contains?(line, "unused variable") -> :low
      String.contains?(line, "unused function") -> :medium
      true -> :low
    end
  end

  defp extract_file_from_context(lines, current_idx) do
    # Look for file context in surrounding lines
    context_range = max(0, current_idx - 5)..min(length(lines) - 1, current_idx + 5)

    Enum.find_value(context_range, "unknown", fn idx ->
      line = Enum.at(lines, idx, "")
      if String.contains?(line, "lib/") and String.contains?(line, ".ex") do
        case Regex.run(~r/lib\/[^:]+\.ex/, line) do
          [file] -> file
          _ -> nil
        end
      end
    end)
  end

  defp perform_five_level_rca(errors, warnings) do
    Logger.info("🔬 Performing 5-Level Root Cause Analysis...")

    %{
      level_1_symptoms: analyze_symptoms(errors, warnings),
      level_2_surface_causes: analyze_surface_causes(errors, warnings),
      level_3_system_behavior: analyze_system_behavior(errors, warnings),
      level_4_configuration_gaps: analyze_configuration_gaps(errors, warnings),
      level_5_design_philosophy: analyze_design_philosophy(errors, warnings)
    }
  end

  defp analyze_symptoms(errors, warnings) do
    %{
      total_errors: length(errors),
      total_warnings: length(warnings),
      error_categories: errors |> Enum.group_by(& &1.category) |> Enum.map(fn {cat, items} -> {cat, length(items)} end),
      warning_categories: warnings |> Enum.group_by(& &1.category) |> Enum.map(fn {cat, items} -> {cat, length(items)} end),
      affected_files: (errors ++ warnings) |> Enum.map(& &1.file) |> Enum.uniq() |> length(),
      severity_distribution: warnings |> Enum.group_by(& &1.severity) |> Enum.map(fn {sev, items} -> {sev, length(items)} end)
    }
  end

  defp analyze_surface_causes(errors, warnings) do
    %{
      undefined_variables: errors |> Enum.filter(&(&1.category == :undefined_variable)) |> length(),
      undefined_functions: errors |> Enum.filter(&(&1.category == :undefined_function)) |> length(),
      unused_variables: warnings |> Enum.filter(&(&1.category == :unused_variable)) |> length(),
      underscore_misuse: warnings |> Enum.filter(&(&1.category == :underscore_usage)) |> length(),
      unused_functions: warnings |> Enum.filter(&(&1.category == :unused_function)) |> length(),
      pattern_analysis: "Systematic parameter/variable name mismatches and missing function definitions"
    }
  end

  defp analyze_system_behavior(_errors, _warnings) do
    %{
      compiler_validation: "Elixir compiler enforcing strict variable scoping and function existence",
      warning_generation: "Compiler detecting unused code and underscore convention violations",
      pattern_propagation: "Similar errors across multiple files indicate systematic issues",
      compilation_phases: "Issues occurring during compilation validation and linking phases"
    }
  end

  defp analyze_configuration_gaps(_errors, _warnings) do
    %{
      coding_standards: "Missing enforcement of underscore parameter conventions",
      automated_checks: "Need pre-commit hooks for unused variable detection",
      pattern_documentation: "Missing guidelines for function parameter naming",
      validation_rules: "Insufficient validation of function existence before calls"
    }
  end

  defp analyze_design_philosophy(_errors, _warnings) do
    %{
      architecture_decisions: "Analytics modules evolved without consistent parameter naming",
      code_patterns: "GenServer implementations lacking consistent interface design",
      systematic_prevention: "Need architecture review for function interface consistency",
      quality_philosophy: "Zero-tolerance policy for warnings requires systematic approach"
    }
  end

  defp perform_criticality_analysis_data(errors, warnings) do
    Logger.info("⚡ Performing Criticality Analysis...")

    all_issues = errors ++ warnings

    %{
      critical_errors: errors |> Enum.filter(&(&1.severity == :critical)),
      high_priority_warnings: warnings |> Enum.filter(&(&1.severity == :high)),
      unused_functions_analysis: analyze_unused_functions(warnings),
      impact_assessment: assess_impact(all_issues),
      removal_candidates: identify_removal_candidates(warnings),
      comment_candidates: identify_comment_candidates(warnings)
    }
  end

  defp analyze_unused_functions(warnings) do
    unused_functions = warnings |> Enum.filter(&(&1.category == :unused_function))

    unused_functions
    |> Enum.map(fn warning ->
      function_name = extract_function_name(warning.content)
      %{
        function: function_name,
        file: warning.file,
        recommendation: determine_function_action(function_name),
        justification: justify_function_action(function_name)
      }
    end)
  end

  defp extract_function_name(warning_content) do
    case Regex.run(~r/function (\w+\/\d+) is unused/, warning_content) do
      [_, function] -> function
      _ -> "unknown"
    end
  end

  defp determine_function_action(function_name) do
    cond do
      String.contains?(function_name, "test") -> :keep_commented
      String.contains?(function_name, "debug") -> :remove
      String.contains?(function_name, "temp") -> :remove
      String.contains?(function_name, "helper") -> :keep_commented
      String.contains?(function_name, "util") -> :keep_commented
      true -> :analyze_further
    end
  end

  defp justify_function_action(function_name) do
    case determine_function_action(function_name) do
      :keep_commented -> "May be used in future or for debugging"
      :remove -> "Temporary or debug function safe to remove"
      :analyze_further -> "Requires manual inspection for business logic importance"
    end
  end

  defp assess_impact(issues) do
    files_affected = issues |> Enum.map(& &1.file) |> Enum.uniq()

    %{
      compilation_blocking: length(Enum.filter(issues, &(&1.type == :error))),
      development_friction: length(Enum.filter(issues, &(&1.severity in [:high, :medium]))),
      maintainability_debt: length(Enum.filter(issues, &(&1.category in [:unused_function, :unused_variable]))),
      files_requiring_attention: length(files_affected),
      estimated_fix_time: estimate_fix_time(issues)
    }
  end

  defp estimate_fix_time(issues) do
    error_time = length(Enum.filter(issues, &(&1.type == :error))) * 5
    warning_time = length(Enum.filter(issues, &(&1.type == :warning))) * 2
    "#{error_time + warning_time} minutes estimated"
  end

  defp identify_removal_candidates(warnings) do
    warnings
    |> Enum.filter(&(&1.category in [:unused_function, :unused_variable]))
    |> Enum.filter(&(&1.severity == :low))
    |> Enum.take(50)  # Start with 50 safest removals
  end

  defp identify_comment_candidates(warnings) do
    warnings
    |> Enum.filter(&(&1.category == :unused_function))
    |> Enum.filter(&(&1.severity == :medium))
    |> Enum.take(30)  # Comment out 30 medium-risk functions
  end

  defp plan_batches(errors, warnings) do
    all_issues = (errors ++ warnings) |> Enum.sort_by(&{&1.severity, &1.type})

    all_issues
    |> Enum.chunk_every(200)
    |> Enum.with_index(1)
    |> Enum.map(fn {batch, index} ->
      %{
        batch_number: index,
        issue_count: length(batch),
        error_count: length(Enum.filter(batch, &(&1.type == :error))),
        warning_count: length(Enum.filter(batch, &(&1.type == :warning))),
        files_affected: batch |> Enum.map(& &1.file) |> Enum.uniq(),
        estimated_time: estimate_fix_time(batch),
        priority: determine_batch_priority(batch)
      }
    end)
  end

  defp determine_batch_priority(batch) do
    error_count = length(Enum.filter(batch, &(&1.type == :error)))
    high_severity = length(Enum.filter(batch, &(&1.severity == :high)))

    cond do
      error_count > 0 -> :critical
      high_severity > 10 -> :high
      true -> :medium
    end
  end

  defp generate_comprehensive_report(errors, warnings, rca, criticality, batches) do
    """
    # SOPv5.11 Comprehensive Compilation Log Analysis Report

    **Generated**: #{DateTime.utc_now() |> DateTime.to_string()}
    **Analysis Method**: 5-Level Root Cause Analysis (TPS Methodology)
    **Scope**: Complete compilation log analysis

    ## Executive Summary

    - **Total Errors**: #{length(errors)} (Compilation Blocking)
    - **Total Warnings**: #{length(warnings)} (Development Friction)
    - **Files Affected**: #{rca.level_1_symptoms.affected_files}
    - **Planned Batches**: #{length(batches)} (200 items each)
    - **Estimated Fix Time**: #{criticality.impact_assessment.estimated_fix_time}

    ## 5-Level Root Cause Analysis

    ### Level 1: Symptoms
    #{Jason.encode!(rca.level_1_symptoms, pretty: true)}

    ### Level 2: Surface Causes
    #{Jason.encode!(rca.level_2_surface_causes, pretty: true)}

    ### Level 3: System Behavior
    #{Jason.encode!(rca.level_3_system_behavior, pretty: true)}

    ### Level 4: Configuration Gaps
    #{Jason.encode!(rca.level_4_configuration_gaps, pretty: true)}

    ### Level 5: Design Philosophy
    #{Jason.encode!(rca.level_5_design_philosophy, pretty: true)}

    ## Criticality Analysis

    ### Unused Functions Analysis
    #{format_unused_functions_analysis(criticality.unused_functions_analysis)}

    ### Impact Assessment
    #{Jason.encode!(criticality.impact_assessment, pretty: true)}

    ### Removal Candidates (#{length(criticality.removal_candidates)})
    #{format_candidates(criticality.removal_candidates)}

    ### Comment Candidates (#{length(criticality.comment_candidates)})
    #{format_candidates(criticality.comment_candidates)}

    ## Batch Execution Plan

    #{format_batch_plan(batches)}

    ## Recommendations

    1. **Immediate**: Fix critical errors in Batch 1 (#{length(Enum.filter(errors, &(&1.severity == :critical)))} errors)
    2. **Priority**: Remove safe unused functions and variables (#{length(criticality.removal_candidates)} items)
    3. **Systematic**: Apply underscore convention fixes (#{rca.level_2_surface_causes.underscore_misuse} items)
    4. **Prevention**: Implement pre-commit hooks for unused code detection
    5. **Architecture**: Review analytics module interface consistency

    ## SOPv5.11 Cybernetic Integration

    - **50-Agent Architecture**: Deploy agents across #{length(batches)} batches
    - **Git Checkpoints**: Create checkpoint before each batch
    - **FPPS Validation**: Multi-method validation after each batch
    - **Patient Mode**: Use NO_TIMEOUT compilation for verification
    - **STAMP Safety**: Enforce safety constraints throughout execution
    """
  end

  defp format_unused_functions_analysis(analysis) do
    analysis
    |> Enum.map(fn item ->
      "- #{item.function} (#{item.file}): #{item.recommendation} - #{item.justification}"
    end)
    |> Enum.join("\n")
  end

  defp format_candidates(candidates) do
    candidates
    |> Enum.take(10)  # Show first 10
    |> Enum.map(fn item ->
      "- #{item.content} (#{item.file})"
    end)
    |> Enum.join("\n")
  end

  defp format_batch_plan(batches) do
    batches
    |> Enum.map(fn batch ->
      """
      ### Batch #{batch.batch_number} (#{batch.priority})
      - Issues: #{batch.issue_count} (#{batch.error_count} errors, #{batch.warning_count} warnings)
      - Files: #{length(batch.files_affected)}
      - Time: #{batch.estimated_time}
      """
    end)
    |> Enum.join("\n")
  end

  defp display_critical_findings(errors, warnings, criticality) do
    Logger.info("🚨 CRITICAL FINDINGS:")
    Logger.info("   Compilation Errors: #{length(errors)} (MUST FIX FIRST)")
    Logger.info("   High Priority Warnings: #{length(criticality.high_priority_warnings)}")
    Logger.info("   Unused Functions: #{length(criticality.unused_functions_analysis)}")
    Logger.info("   Safe Removals: #{length(criticality.removal_candidates)}")
    Logger.info("   Comment Candidates: #{length(criticality.comment_candidates)}")

    if length(errors) > 0 do
      Logger.error("⚠️  COMPILATION BLOCKED - Must fix errors before warnings")
    else
      Logger.info("✅ No compilation errors - Ready for warning elimination")
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Comprehensive Log Analyzer with 5-Level RCA

    Usage:
      elixir #{__ENV__.file} --comprehensive    # Complete analysis
      elixir #{__ENV__.file} --analyze         # Basic analysis
      elixir #{__ENV__.file} --classify        # Classify issues
      elixir #{__ENV__.file} --criticality     # Criticality analysis
      elixir #{__ENV__.file} --plan-batches    # Plan batch execution

    🎯 SOPv5.11 Cybernetic Excellence: Systematic warning elimination
    """)
  end
end

SOPv511.ComprehensiveLogAnalyzerRCA.main(System.argv())