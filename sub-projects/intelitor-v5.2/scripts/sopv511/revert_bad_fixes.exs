#!/usr/bin/env elixir

defmodule RevertBadFixes do
  @moduledoc """
  Reverts the problematic changes from simple_warning_fixer
  that caused undefined variable errors
  """

  def run do
    IO.puts("\n🔄 Reverting problematic warning fixes")
    IO.puts("=" <> String.duplicate("=", 79))
    
    files = [
      "lib/indrajaal/access_control/domain_hooks.ex",
      "lib/indrajaal/access_control/timescale_integration.ex",
      "lib/indrajaal/access_control/unified_patterns.ex"
    ]
    
    for file <- files do
      fix_file(file)
    end
    
    IO.puts("\n✅ Reverted problematic changes!")
  end
  
  defp fix_file(file) do
    IO.puts("📝 Fixing #{file}")
    
    content = File.read!(file)
    
    # Fix the specific patterns that caused errors
    fixed = content
    # In domain_hooks.ex - fix context usage
    |> String.replace("correlation_id: context[", "correlation_id: _context[")
    |> String.replace("session_id: context[", "session_id: _context[")
    |> String.replace("enrich_access_log_context(log, _context)", "enrich_access_log_context(log, context)")
    |> String.replace("is_policy_weakening?(access_rule, event_type, _context)", 
                      "is_policy_weakening?(access_rule, event_type, context)")
    |> String.replace("handle_access_rule_event(access_rule, event_type, context)", 
                      "handle_access_rule_event(access_rule, event_type, _context)")
    
    # In timescale_integration.ex - fix opts usage
    |> String.replace("extract_tenant_id(context, _opts)", "extract_tenant_id(context, opts)")
    |> String.replace("extract_user_id(context, _opts)", "extract_user_id(context, opts)")
    |> String.replace("report_authorization_denial(:tenant_id, metadata, _opts)", 
                      "report_authorization_denial(:tenant_id, metadata, opts)")
    |> String.replace("report_access_security_event(:event_type, :tenant_id, metadata, _opts)",
                      "report_access_security_event(:event_type, :tenant_id, metadata, opts)")
    |> String.replace("is_security_event?(eventtype, _context)", "is_security_event?(eventtype, context)")
    |> String.replace("logaccesscontrol_event(eventtype, context, opts)", 
                      "logaccesscontrol_event(eventtype, context, _opts)")
    |> String.replace("log_authorization_event(outcome, context, opts)",
                      "log_authorization_event(outcome, context, _opts)")
    |> String.replace("log_authentication_event(outcome, context, opts)",
                      "log_authentication_event(outcome, context, _opts)")
    |> String.replace("report_security_violation(violation_type, context, metadata, opts)",
                      "report_security_violation(violation_type, context, metadata, _opts)")
                      
    # In unified_patterns.ex - fix context parameter
    |> String.replace("determine_access_level(validated_params, context)", 
                      "determine_access_level(validated_params, _context)")
    |> String.replace("enforce_access_policy(access_level, context)",
                      "enforce_access_policy(access_level, _context)")
    |> String.replace("def validate_access(params, _context \\\\", "def validate_access(params, context \\\\")
    
    File.write!(file, fixed)
    IO.puts("  ✅ Fixed variable references")
  end
end

RevertBadFixes.run()
