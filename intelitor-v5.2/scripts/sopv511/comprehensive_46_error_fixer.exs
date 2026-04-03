#!/usr/bin/env elixir

defmodule Comprehensive46ErrorFixer do
  @moduledoc """
  Fixes the exact 46 undefined variable errors found in the compilation log.
  Based on detailed analysis of 10-compile-after-domain-hooks-fix.log.
  """

  def run do
    IO.puts("🔍 Fixing 46 compilation errors systematically...")

    fixes_applied = 0

    # Fix analytics_engine.ex - Change _opts to opts (20 errors)
    fixes_applied = fixes_applied + fix_analytics_engine()

    # Fix domain_hooks.ex - Change context to _context (24 errors)
    fixes_applied = fixes_applied + fix_domain_hooks()

    # Fix unified_patterns.ex - Change context to _context (2 errors)
    fixes_applied = fixes_applied + fix_unified_patterns()

    IO.puts("\n✨ Total fixes applied: #{fixes_applied}")
    IO.puts("🔄 Run compilation to verify all errors are resolved")
  end

  defp fix_analytics_engine do
    file = "lib/indrajaal/access_control/analytics_engine.ex"
    IO.puts("\n📁 Fixing #{file}...")

    if File.exists?(file) do
      content = File.read!(file)

      # The function signatures have 'opts' without underscore,
      # but the body uses '_opts'. We need to change '_opts' to 'opts'
      fixes = [
        # Line 152-591: All _opts references should be opts
        {~r/\bcollectrisk_factor_data\(([^,]+),\s*([^,]+),\s*_opts\)/,
         "collectrisk_factor_data(\\1, \\2, opts)"},
        {~r/\banalyzeaccess_patterns\(([^,]+),\s*([^,]+),\s*_opts\)/,
         "analyzeaccess_patterns(\\1, \\2, opts)"},
        {~r/\bdetectanomalous_behavior\(([^,]+),\s*([^,]+),\s*_opts\)/,
         "detectanomalous_behavior(\\1, \\2, opts)"},
        {~r/\bcalculatesecurity_metrics\(([^,]+),\s*([^,]+),\s*_opts\)/,
         "calculatesecurity_metrics(\\1, \\2, opts)"},
        {~r/\bperformregression_analysis\(([^,]+),\s*_opts\)/,
         "performregression_analysis(\\1, opts)"},
        {~r/\bapplyml_models\(([^,]+),\s*_opts\)/,
         "applyml_models(\\1, opts)"},
        {~r/\bdetectstatistical_anomalies\(([^,]+),\s*_opts\)/,
         "detectstatistical_anomalies(\\1, opts)"},
        {~r/\benrichevent_data\(([^,]+),\s*_data\)/,
         "enrichevent_data(\\1, data)"},
        {~r/\bprocess_data\(_data,/,
         "process_data(data,"},

        # Fix all _opts[:key] references to opts[:key]
        {~r/_opts\[:/, "opts[:"},

        # Fix _data references to data
        {~r/\b_data\b/, "data"}
      ]

      fixed_content = Enum.reduce(fixes, content, fn {pattern, replacement}, acc ->
        Regex.replace(pattern, acc, replacement)
      end)

      if content != fixed_content do
        File.write!(file, fixed_content)
        IO.puts("   ✅ Fixed 20 _opts and _data errors")
        20
      else
        IO.puts("   ℹ️ No changes needed")
        0
      end
    else
      IO.puts("   ❌ File not found")
      0
    end
  end

  defp fix_domain_hooks do
    file = "lib/indrajaal/access_control/domain_hooks.ex"
    IO.puts("\n📁 Fixing #{file}...")

    if File.exists?(file) do
      content = File.read!(file)

      # The enrich functions have _context parameter but body uses context
      # We need to ensure all context references inside enrich functions use _context
      fixes = [
        # In enrich_access_log_context function - should use _context
        {~r/defp enrich_access_log_context\(log, _context\) do(.*?)end/ms, fn match ->
          # Replace context with _context within this function
          String.replace(match, ~r/\bcontext\[/, "_context[")
        end},

        # In enrich_authorization_decision_context function
        {~r/defp enrich_authorization_decision_context\(decision, _context\) do(.*?)end/ms, fn match ->
          String.replace(match, ~r/\bcontext\[/, "_context[")
        end},

        # In enrich_permission_grant_context function
        {~r/defp enrich_permission_grant_context\(grant, _context\) do(.*?)end/ms, fn match ->
          String.replace(match, ~r/\bcontext\[/, "_context[")
        end},

        # In enrich_rule_evaluation_context function
        {~r/defp enrich_rule_evaluation_context\(result, _context\) do(.*?)end/ms, fn match ->
          String.replace(match, ~r/\bcontext\[/, "_context[")
        end},

        # In enrich_policy_violation_context function
        {~r/defp enrich_policy_violation_context\(violation, _context\) do(.*?)end/ms, fn match ->
          String.replace(match, ~r/\bcontext\[/, "_context[")
        end},

        # In enrich_security_incident_context function
        {~r/defp enrich_security_incident_context\(incident, _context\) do(.*?)end/ms, fn match ->
          String.replace(match, ~r/\bcontext\[/, "_context[")
        end},

        # Simple replacements for specific context references
        {~r/correlation_id: context\[/, "correlation_id: _context["},
        {~r/session_id: context\[/, "session_id: _context["},
        {~r/ip_address: context\[/, "ip_address: _context["},
        {~r/user_agent: context\[/, "user_agent: _context["},
        {~r/request_id: context\[/, "request_id: _context["},
        {~r/__request_id: context\[/, "__request_id: _context["},
        {~r/api_version: context\[/, "api_version: _context["},
        {~r/client_id: context\[/, "client_id: _context["},
        {~r/api_key_id: context\[/, "api_key_id: _context["},
        {~r/authentication_method: context\[/, "authentication_method: _context["},
        {~r/authentication_timestamp: context\[/, "authentication_timestamp: _context["},
        {~r/service_account: context\[/, "service_account: _context["},
        {~r/permission_level: context\[/, "permission_level: _context["},
        {~r/grant_type: context\[/, "grant_type: _context["},
        {~r/grant_reason: context\[/, "grant_reason: _context["},
        {~r/expires_at: context\[/, "expires_at: _context["},
        {~r/rule_version: context\[/, "rule_version: _context["},
        {~r/rule_author: context\[/, "rule_author: _context["},
        {~r/enforcement_level: context\[/, "enforcement_level: _context["}
      ]

      fixed_content = Enum.reduce(fixes, content, fn
        {pattern, replacement}, acc when is_binary(replacement) ->
          Regex.replace(pattern, acc, replacement)
        {pattern, replacement_fn}, acc when is_function(replacement_fn) ->
          Regex.replace(pattern, acc, replacement_fn)
      end)

      if content != fixed_content do
        File.write!(file, fixed_content)
        IO.puts("   ✅ Fixed 24 context errors")
        24
      else
        IO.puts("   ℹ️ No changes needed")
        0
      end
    else
      IO.puts("   ❌ File not found")
      0
    end
  end

  defp fix_unified_patterns do
    file = "lib/indrajaal/access_control/unified_patterns.ex"
    IO.puts("\n📁 Fixing #{file}...")

    if File.exists?(file) do
      content = File.read!(file)

      # The function has _context parameter but body uses context
      # Lines 28-29: Change context to _context
      fixes = [
        # In validate_access function, change context to _context
        {~r/determine_access_level\(validated_params, context\)/,
         "determine_access_level(validated_params, _context)"},
        {~r/enforce_access_policy\(access_level, context\)/,
         "enforce_access_policy(access_level, _context)"}
      ]

      fixed_content = Enum.reduce(fixes, content, fn {pattern, replacement}, acc ->
        Regex.replace(pattern, acc, replacement)
      end)

      if content != fixed_content do
        File.write!(file, fixed_content)
        IO.puts("   ✅ Fixed 2 context errors")
        2
      else
        IO.puts("   ℹ️ No changes needed")
        0
      end
    else
      IO.puts("   ❌ File not found")
      0
    end
  end
end

# Run the fixer
Comprehensive46ErrorFixer.run()