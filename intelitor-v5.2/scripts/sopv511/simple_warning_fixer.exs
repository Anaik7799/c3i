#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SimpleWarningFixer do
  @moduledoc """
  Simple direct warning fixer for Phase 1
  """

  def run(_args \\ []) do
    IO.puts """
    ╔══════════════════════════════════════════════════════════════╗
    ║           Simple Warning Fixer - Phase 1                    ║
    ╚══════════════════════════════════════════════════════════════╝
    """

    # Focus on access_control files first
    fix_access_control_warnings()
    
    IO.puts("\n✅ Warning fixes applied!")
  end

  defp fix_access_control_warnings do
    files = [
      "lib/indrajaal/access_control/unified_patterns.ex",
      "lib/indrajaal/access_control/timescale_integration.ex",
      "lib/indrajaal/access_control/analytics_engine.ex",
      "lib/indrajaal/access_control/compliance_reporter.ex",
      "lib/indrajaal/access_control/domain_hooks.ex"
    ]
    
    Enum.each(files, &fix_file/1)
  end

  defp fix_file(file) do
    if File.exists?(file) do
      IO.puts("\n📝 Fixing #{Path.basename(file)}")
      content = File.read!(file)
      
      fixed = content
      |> fix_unused_variables()
      |> fix_used_underscore_variables()
      
      if fixed != content do
        File.write!(file, fixed)
        IO.puts("  ✅ Fixed warnings in #{Path.basename(file)}")
      else
        IO.puts("  ⏭️ No changes needed")
      end
    end
  end

  defp fix_unused_variables(content) do
    content
    # Fix unused opts parameters
    |> String.replace(~r/\bopts\)/, "_opts)")
    # Fix unused context parameters
    |> String.replace(~r/\bcontext\) do\b/, "_context) do")
    # Fix unused data parameters
    |> String.replace(~r/\bdata\) do\b/, "_data) do")
    # Fix specific patterns
    |> String.replace("defp extract_user_id(context, opts)", "defp extract_user_id(context, _opts)")
    |> String.replace("defp extract_tenant_id(tenant_id, context)", "defp extract_tenant_id(tenant_id, _context)")
    |> String.replace("defp calculaterisk_score(_eventdata, context)", "defp calculaterisk_score(_eventdata, _context)")
    |> String.replace("defp collect_access_data(tenant_id, time_range, opts)", "defp collect_access_data(tenant_id, time_range, _opts)")
    |> String.replace("defp preprocess_data(raw_data, opts)", "defp preprocess_data(raw_data, _opts)")
    |> String.replace("defp analyze_temporal_patterns(data)", "defp analyze_temporal_patterns(_data)")
    |> String.replace("defp analyze_behavioral_patterns(data)", "defp analyze_behavioral_patterns(_data)")
    |> String.replace("defp analyze_geographical_patterns(data)", "defp analyze_geographical_patterns(_data)")
    |> String.replace("defp runalgorithm(:timeseries, baseline, current, opts)", "defp runalgorithm(:timeseries, baseline, current, _opts)")
    |> String.replace("defp runalgorithm(:behavioral, baseline, current, opts)", "defp runalgorithm(:behavioral, baseline, current, _opts)")
    |> String.replace("defp runalgorithm(:mlclustering, baseline, current, opts)", "defp runalgorithm(:mlclustering, baseline, current, _opts)")
    |> String.replace("defp calculate_individual_factor_scores(factors, opts)", "defp calculate_individual_factor_scores(factors, _opts)")
    |> String.replace("defp apply_risk_weights(scores, opts)", "defp apply_risk_weights(scores, _opts)")
    |> String.replace("defp broadcastevent(_event_type, _eventdata, context)", "defp broadcastevent(_event_type, _eventdata, _context)")
    |> String.replace("defp is_policy_weakening?(access_rule, event_type, context)", "defp is_policy_weakening?(access_rule, event_type, _context)")
  end

  defp fix_used_underscore_variables(content) do
    content
    # Fix used _context variables in unified_patterns.ex
    |> String.replace("determine_access_level(validated_params, _context)", "determine_access_level(validated_params, context)")
    |> String.replace("enforce_access_policy(access_level, _context)", "enforce_access_policy(access_level, context)")
    |> String.replace("defp validate_access(params, _context) do", "defp validate_access(params, context) do")
    
    # Fix used _framework_config in compliance_reporter.ex
    |> String.replace("validate_report_period(opts, _framework_config)", "validate_report_period(opts, framework_config)")
    |> String.replace("calculate_compliance_score(current_data, _framework_config)", "calculate_compliance_score(current_data, framework_config)")
    |> String.replace("if Enum.empty?(_framework_config[:requirements]", "if Enum.empty?(framework_config[:requirements]")
    |> String.replace("perform_violation_analysis(_violation_data)", "perform_violation_analysis(violation_data)")
    |> String.replace("defp analyze_violations(tenant_id, _framework_config) do", "defp analyze_violations(tenant_id, framework_config) do")
    |> String.replace("defp get_compliance_score(tenant_id, _framework_config) do", "defp get_compliance_score(tenant_id, framework_config) do")
    |> String.replace("defp generate_analytics_report(tenant_id, opts, _framework_config) do", "defp generate_analytics_report(tenant_id, opts, framework_config) do")
  end
end

# Run the fixer
SimpleWarningFixer.run()
