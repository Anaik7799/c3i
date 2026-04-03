#!/usr/bin/env elixir

defmodule PreciseErrorFixer do
  @moduledoc """
  Fixes undefined variable errors based on precise analysis of compilation output.
  This targets the specific issue where function parameters have underscores
  but the function body uses the variable without underscore (or vice versa).
  """

  def run do
    IO.puts("🔍 Analyzing compilation errors precisely...")

    # Based on the compilation output, we know the exact files with errors
    fixes = [
      # compliance_reporter.ex - opts vs _opts issues
      {"lib/indrajaal/access_control/compliance_reporter.ex", [
        # Line 420: opts should be _opts (parameter has underscore)
        {~r/(\s+)analysis_type = opts\[:analysis_type\]/, "\\1analysis_type = _opts[:analysis_type]"},
        {~r/(\s+)comparison_period = opts\[:comparison_period\]/, "\\1comparison_period = _opts[:comparison_period]"},
        {~r/(\s+)includedetails = opts\[:includedetails\]/, "\\1includedetails = _opts[:includedetails]"},
        {~r/(\s+)report_type = opts\[:report_type\]/, "\\1report_type = _opts[:report_type]"},
        {~r/(\s+)case format_report\(report, opts\) do/, "\\1case format_report(report, _opts) do"},
        {~r/generatecsv_report\(report, opts\)/, "generatecsv_report(report, _opts)"},
        {~r/generatexml_report\(report, opts\)/, "generatexml_report(report, _opts)"},
        {~r/\|> generate_pdf_report\(opts\)/, "|> generate_pdf_report(_opts)"},
        # Fix places where _opts is used but opts is the parameter
        {~r/runalgorithm\(algorithm, baseline_data, current_data, _opts\)/, "runalgorithm(algorithm, baseline_data, current_data, opts)"},
        {~r/detectbehavioral_anomalies\(behavioranalysis, _opts\)/, "detectbehavioral_anomalies(behavioranalysis, opts)"},
        {~r/comparebehavioral_patterns\(historicalbehavior, currentbehavior, _opts\)/, "comparebehavioral_patterns(historicalbehavior, currentbehavior, opts)"}
      ]},

      # domain_hooks.ex - context vs _context issues
      {"lib/indrajaal/access_control/domain_hooks.ex", [
        # In enrich functions, parameter is _context but body uses context
        {~r/correlation_id: context\[:correlation_id\]/, "correlation_id: _context[:correlation_id]"},
        {~r/session_id: context\[:session_id\]/, "session_id: _context[:session_id]"},
        {~r/ip_address: context\[:ip_address\]/, "ip_address: _context[:ip_address]"},
        {~r/user_agent: context\[:user_agent\]/, "user_agent: _context[:user_agent]"},
        {~r/request_id: context\[:request_id\]/, "request_id: _context[:request_id]"},
        {~r/api_version: context\[:api_version\]/, "api_version: _context[:api_version]"},
        {~r/client_id: context\[:client_id\]/, "client_id: _context[:client_id]"},
        {~r/api_key_id: context\[:api_key_id\]/, "api_key_id: _context[:api_key_id]"},
        {~r/authentication_method: context\[:authentication_method\]/, "authentication_method: _context[:authentication_method]"},
        {~r/authentication_timestamp: context\[:authentication_timestamp\]/, "authentication_timestamp: _context[:authentication_timestamp]"},
        {~r/service_account: context\[:service_account\]/, "service_account: _context[:service_account]"},
        {~r/permission_level: context\[:permission_level\]/, "permission_level: _context[:permission_level]"},
        {~r/grant_type: context\[:grant_type\]/, "grant_type: _context[:grant_type]"},
        {~r/grant_reason: context\[:grant_reason\]/, "grant_reason: _context[:grant_reason]"},
        {~r/expires_at: context\[:expires_at\]/, "expires_at: _context[:expires_at]"},
        {~r/rule_version: context\[:rule_version\]/, "rule_version: _context[:rule_version]"},
        {~r/rule_author: context\[:rule_author\]/, "rule_author: _context[:rule_author]"},
        {~r/enforcement_level: context\[:enforcement_level\]/, "enforcement_level: _context[:enforcement_level]"}
      ]},

      # analytics_engine.ex - _data and _opts issues
      {"lib/indrajaal/access_control/analytics_engine.ex", [
        # Function has _data parameter but body uses it
        # These are already correctly using _data based on previous fixes,
        # but there might be opts vs _opts issues
        {~r/threshold = opts\[:anomaly_threshold\]/, "threshold = _opts[:anomaly_threshold]"},
        {~r/window_size = opts\[:window_size\]/, "window_size = _opts[:window_size]"},
        {~r/min_events = opts\[:min_events\]/, "min_events = _opts[:min_events]"}
      ]},

      # timescale_integration.ex - might have _context issues
      {"lib/indrajaal/access_control/timescale_integration.ex", [
        {~r/tenant_id: context\[:tenant_id\]/, "tenant_id: _context[:tenant_id]"},
        {~r/inserted_by_id: context\[:user_id\]/, "inserted_by_id: _context[:user_id]"}
      ]}
    ]

    # Apply fixes
    total_fixes = 0
    for {file, replacements} <- fixes do
      if File.exists?(file) do
        content = File.read!(file)
        fixed_content = Enum.reduce(replacements, content, fn {pattern, replacement}, acc ->
          String.replace(acc, pattern, replacement)
        end)

        if content != fixed_content do
          File.write!(file, fixed_content)
          IO.puts("✅ Fixed #{file}")
          total_fixes = total_fixes + 1
        end
      end
    end

    IO.puts("\n✨ Applied fixes to #{total_fixes} files")
    IO.puts("🔄 Run compilation to verify")
  end
end

# Run the precise fixer
PreciseErrorFixer.run()