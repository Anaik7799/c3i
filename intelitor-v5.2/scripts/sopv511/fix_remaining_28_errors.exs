#!/usr/bin/env elixir

defmodule FixRemaining28Errors do
  @moduledoc """
  Comprehensive fix for the remaining 28 compilation errors after syntax fix.
  """

  def run do
    IO.puts("\n🔧 Fixing remaining 28 compilation errors...")

    fixes_applied = 0

    # Fix domain_hooks.ex context issues
    fixes_applied = fixes_applied + fix_domain_hooks()

    # Fix compliance_reporter.ex variable issues
    fixes_applied = fixes_applied + fix_compliance_reporter()

    # Fix timescale_integration.ex _opts issues
    fixes_applied = fixes_applied + fix_timescale_integration()

    IO.puts("\n✅ Total fixes applied: #{fixes_applied}")
  end

  defp fix_domain_hooks do
    file_path = "lib/indrajaal/access_control/domain_hooks.ex"
    IO.puts("\n📝 Fixing #{file_path}...")

    content = File.read!(file_path)
    fixes = 0

    # Fix enrich_access_log_context - uses context but param is _context
    content = Regex.replace(
      ~r/(defp enrich_access_log_context\(access_log,\s*)_context(\))/,
      content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    # Fix enrich_access_grant_context - uses context but param is _context
    content = Regex.replace(
      ~r/(defp enrich_access_grant_context\(access_grant,\s*)_context(\))/,
      content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    # Fix enrich_access_rule_context - uses context but param is _context
    content = Regex.replace(
      ~r/(defp enrich_access_rule_context\(access_rule,\s*)_context(\))/,
      content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    # Fix is_privilege_escalation? - uses context but param is _context
    content = Regex.replace(
      ~r/(defp is_privilege_escalation\?\(access_grant,\s*)_context(\))/,
      content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    # Fix is_anomalous_access_event? - uses context in body but param is _context
    updated_content = String.replace(
      content,
      "defp is_anomalous_access_event?(access_log, _context) do",
      "defp is_anomalous_access_event?(access_log, context) do"
    )

    # Also fix the Map.get call
    updated_content = String.replace(
      updated_content,
      "repeated_attempts = Map.get(context || %{}, :repeated_attempts, 0)",
      "repeated_attempts = Map.get(context || %{}, :repeated_attempts, 0)"
    )
    fixes = fixes + 1

    # Fix broadcast_security_alert - uses context but param is _context
    updated_content = Regex.replace(
      ~r/(defp broadcast_security_alert\(exception,\s*)_context(\))/,
      updated_content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    # Fix analyze_privilege_escalation/2 - uses context but param is _context
    updated_content = String.replace(
      updated_content,
      "defp analyze_privilege_escalation(access_grant, _context) do\n    analyze_privilege_escalation(access_grant, context, nil)",
      "defp analyze_privilege_escalation(access_grant, context) do\n    analyze_privilege_escalation(access_grant, context, nil)"
    )
    fixes = fixes + 1

    # Fix analyze_policy_change - uses _context in parameters where context is used
    updated_content = Regex.replace(
      ~r/(defp analyze_policy_change\(access_rule, event_type,\s*)_context(\))/,
      updated_content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    # Fix handle_access_rule_event calls that use _context
    updated_content = String.replace(
      updated_content,
      "if is_policy_weakening?(access_rule, event_type, _context) do",
      "if is_policy_weakening?(access_rule, event_type, context) do"
    )

    updated_content = String.replace(
      updated_content,
      "policy_change: analyze_policy_change(access_rule, event_type, _context)",
      "policy_change: analyze_policy_change(access_rule, event_type, context)"
    )
    fixes = fixes + 2

    # Fix handle_security_exception that uses _context
    updated_content = String.replace(
      updated_content,
      "event_context = enrich_security_exception_context(exception, _context)",
      "event_context = enrich_security_exception_context(exception, context)"
    )

    updated_content = Regex.replace(
      ~r/(def handle_security_exception\(exception,\s*)_context(\))/,
      updated_content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    # Fix handle_access_credential_event that uses _context
    updated_content = String.replace(
      updated_content,
      "event_context = enrich_credential_context(credential, _context)",
      "event_context = enrich_credential_context(credential, context)"
    )

    updated_content = Regex.replace(
      ~r/(def handle_access_credential_event\(credential, event_type,\s*)_context(\))/,
      updated_content,
      "\\1context\\2"
    )
    fixes = fixes + 1

    File.write!(file_path, updated_content)
    IO.puts("  ✓ Fixed #{fixes} context variable issues")
    fixes
  end

  defp fix_compliance_reporter do
    file_path = "lib/indrajaal/access_control/compliance_reporter.ex"
    IO.puts("\n📝 Fixing #{file_path}...")

    content = File.read!(file_path)
    fixes = 0

    # Fix generate_analytics_report - uses _opts and framework_config without them being defined
    content = String.replace(
      content,
      "{:ok, report_period} <- validate_report_period(opts, framework_config),",
      "{:ok, report_period} <- validate_report_period(opts, framework),"
    )

    content = String.replace(
      content,
      "{:ok, report} <- generate_report_content(framework, analysis, _opts),",
      "{:ok, report} <- generate_report_content(framework, analysis, opts),"
    )
    fixes = fixes + 2

    # Fix generate_report_content - uses opts but param is _opts
    content = Regex.replace(
      ~r/(defp generate_report_content\(framework, analysis,\s*)_opts(\))/,
      content,
      "\\1opts\\2"
    )
    fixes = fixes + 1

    # Fix analyze_violations - uses data but it's not defined
    content = Regex.replace(
      ~r/(defp analyze_violations\(tenant_id, framework,\s*)_data(\))/,
      content,
      "\\1data\\2"
    )
    fixes = fixes + 1

    # Fix get_compliance_score - uses framework_config without it being defined
    content = String.replace(
      content,
      "{:ok, score} <- calculate_compliance_score(current_data, framework_config) do",
      "{:ok, score} <- calculate_compliance_score(current_data, framework) do"
    )
    fixes = fixes + 1

    # Fix calculate_compliance_score parameter
    content = Regex.replace(
      ~r/(defp calculate_compliance_score\(data,\s*)framework_config(\))/,
      content,
      "\\1framework\\2"
    )
    fixes = fixes + 1

    # Fix break_down_score_components parameters
    content = Regex.replace(
      ~r/(defp break_down_score_components\(data, framework_config\))/,
      content,
      "break_down_score_components(_data, _framework)"
    )
    fixes = fixes + 1

    # Fix validate_report_data - uses framework_config[:requirements]
    content = String.replace(
      content,
      "if Enum.empty?(framework_config[:requirements] || []) do",
      "if Enum.empty?(framework[:requirements] || []) do"
    )
    fixes = fixes + 1

    # Fix the malformed line 870 with data[:violations]
    content = String.replace(
      content,
      "defp perform_violation_analysis(data[:violations] || []) do",
      "defp perform_violation_analysis(violations) when is_list(violations) do"
    )
    fixes = fixes + 1

    File.write!(file_path, content)
    IO.puts("  ✓ Fixed #{fixes} variable issues")
    fixes
  end

  defp fix_timescale_integration do
    file_path = "lib/indrajaal/access_control/timescale_integration.ex"
    IO.puts("\n📝 Fixing #{file_path}...")

    content = File.read!(file_path)
    fixes = 0

    # Fix report_security_violation - uses _opts but it's not defined
    content = String.replace(
      content,
      "trigger_security_alert(:violation_type, tenant_id, metadata, _opts)",
      "trigger_security_alert(:violation_type, tenant_id, metadata, opts)"
    )
    fixes = fixes + 1

    # Fix extract_user_id - uses opts but param is _opts (if exists)
    content = Regex.replace(
      ~r/(defp extract_user_id\(context,\s*)_opts(\))/,
      content,
      "\\1opts\\2"
    )

    File.write!(file_path, content)
    IO.puts("  ✓ Fixed #{fixes} variable issues")
    fixes
  end
end

# Run the fix
FixRemaining28Errors.run()