#!/usr/bin/env elixir

defmodule FixUndefinedContextErrors do
  @moduledoc """
  Fixes undefined variable errors caused by incorrect underscore usage
  """

  def run do
    IO.puts("\n🔧 AEE SOPv5.11: Fixing undefined context and variable errors")
    IO.puts("=" <> String.duplicate("=", 79))
    
    fixes = [
      # domain_hooks.ex fixes
      {"lib/indrajaal/access_control/domain_hooks.ex", [
        # Fix context usage in enrich functions
        {"enrich_access_log_context(log, context)", "enrich_access_log_context(log, _context)"},
        {"enrich_credential_context(credential, context)", "enrich_credential_context(credential, _context)"},
        {"enrich_access_grant_context(grant, context)", "enrich_access_grant_context(grant, _context)"},
        {"enrich_access_rule_context(rule, context)", "enrich_access_rule_context(rule, _context)"},
        {"enrich_security_exception_context(exception, context)", "enrich_security_exception_context(exception, _context)"},
        
        # Fix internal context usage - now use the renamed parameter
        {"correlation_id: _context[", "correlation_id: context["},
        {"session_id: _context[", "session_id: context["},
        {"__request_id: context[", "__request_id: _context["},
        {"admin_user_id: context[", "admin_user_id: _context["},
        {"__requestcontext: context[", "__requestcontext: _context["},
        {"admincontext: context[", "admincontext: _context["},
        {"detection_method: context[", "detection_method: _context["},
        {"_context: context", "_context: _context"},
        
        # Fix analyze functions
        {"analyze_privilege_escalation(access_grant, context, nil)", "analyze_privilege_escalation(access_grant, _context, nil)"},
        {"analyze_policy_change(access_rule, event_type, context)", "analyze_policy_change(access_rule, event_type, _context)"},
        
        # Fix is_ predicate functions
        {"is_anomalous_access_event?(access_log, context)", "is_anomalous_access_event?(access_log, _context)"},
        {"is_privilege_escalation?(access_grant, context)", "is_privilege_escalation?(access_grant, _context)"},
        {"is_policy_weakening?(access_rule, event_type, context)", "is_policy_weakening?(access_rule, event_type, _context)"},
        
        # Fix broadcast function
        {"broadcast_security_alert(alert, context)", "broadcast_security_alert(alert, _context)"},
        
        # Fix handle event functions - these need _context in signature but context in body
        {"handle_access_log_created(access_log, context)", "handle_access_log_created(access_log, _context)"},
        {"handle_access_credential_event(credential, event_type, context)", "handle_access_credential_event(credential, event_type, _context)"},
        {"handle_access_grant_event(grant, event_type, context)", "handle_access_grant_event(grant, event_type, _context)"},
        {"handle_access_rule_event(rule, event_type, context)", "handle_access_rule_event(rule, event_type, _context)"},
        {"handle_security_exception(exception, context)", "handle_security_exception(exception, _context)"}
      ]},
      
      # analytics_engine.ex fixes
      {"lib/indrajaal/access_control/analytics_engine.ex", [
        # Fix function signatures to match usage
        {"process_real_time_event(data)", "process_real_time_event(_data)"},
        {"analyze_all_patterns(data)", "analyze_all_patterns(_data)"},
        {"enrichevent_data(data)", "enrichevent_data(_data)"},
        {"validate_time_range(_opts)", "validate_time_range(opts)"},
        
        # Fix internal variable usage - use data not _data
        {"Map.merge(data, %{", "Map.merge(_data, %{"},
        {"data[:ip_address]", "_data[:ip_address]"},
        {"data[:_user_id]", "_data[:_user_id]"},
        {"data[:device_id]", "_data[:device_id]"},
        {"data.eventtype", "_data.eventtype"},
        {"data.tenant_id", "_data.tenant_id"},
        {"data.userid", "_data.userid"},
        
        # Fix pattern analysis
        {"analyze_temporal_patterns(data)", "analyze_temporal_patterns(_data)"},
        {"analyze_behavioral_patterns(data)", "analyze_behavioral_patterns(_data)"},
        {"analyze_geographical_patterns(data)", "analyze_geographical_patterns(_data)"},
        
        # Fix function calls with opts
        {"perform_pattern_analysis(events, _opts)", "perform_pattern_analysis(events, opts)"},
        {"run_anomaly_detection_algorithms(baseline_data, current_data, _opts)", "run_anomaly_detection_algorithms(baseline_data, current_data, opts)"}
      ]},
      
      # compliance_reporter.ex fixes  
      {"lib/indrajaal/access_control/compliance_reporter.ex", [
        # Fix format_report opts usage
        {"format_report(report, _opts)", "format_report(report, opts)"},
        {"generate_pdf_report(report, _opts)", "generate_pdf_report(report, opts)"},
        {"generate_csv_report(report, _opts)", "generate_csv_report(report, opts)"},
        {"generate_xml_report(report, _opts)", "generate_xml_report(report, opts)"},
        
        # Fix violation analysis
        {"analyze_violations(compliance_data, _framework_config)", "analyze_violations(compliance_data, framework_config)"},
        {"perform_violation_analysis(violation_data, violation_data)", "perform_violation_analysis(violation_data, _duplicate_data)"},
        {"perform_violation_analysis(violation_data)", "perform_violation_analysis(violation_data)"},
        
        # Fix validation and score functions
        {"validate_report_data(data, _framework_config)", "validate_report_data(data, framework_config)"},
        {"calculate_compliance_score(current_data, framework_config)", "calculate_compliance_score(current_data, _framework_config)"},
        {"get_compliance_score(tenant_id, framework_config)", "get_compliance_score(tenant_id, _framework_config)"},
        
        # Fix comprehensive report
        {"generate_comprehensive_report(tenant_id, _opts)", "generate_comprehensive_report(tenant_id, opts)"},
        {"generate_analytics_report(tenant_id, framework, _opts)", "generate_analytics_report(tenant_id, framework, opts)"}
      ]},
      
      # unified_patterns.ex fixes
      {"lib/indrajaal/access_control/unified_patterns.ex", [
        {"def validate_access(params, context \\\\", "def validate_access(params, _context \\\\"},
        {"determine_access_level(validated_params, _context)", "determine_access_level(validated_params, context)"},
        {"enforce_access_policy(access_level, _context)", "enforce_access_policy(access_level, context)"}
      ]}
    ]
    
    for {file, replacements} <- fixes do
      fix_file(file, replacements)
    end
    
    IO.puts("\n✅ Fixed undefined variable errors!")
  end
  
  defp fix_file(file, replacements) do
    IO.puts("\n📝 Fixing #{file}")
    
    if File.exists?(file) do
      content = File.read!(file)
      
      fixed_content = Enum.reduce(replacements, content, fn {from, to}, acc ->
        String.replace(acc, from, to)
      end)
      
      if content != fixed_content do
        File.write!(file, fixed_content)
        IO.puts("  ✅ Applied #{length(replacements)} fixes")
      else
        IO.puts("  ℹ️  No changes needed")
      end
    else
      IO.puts("  ⚠️  File not found")
    end
  end
end

FixUndefinedContextErrors.run()
