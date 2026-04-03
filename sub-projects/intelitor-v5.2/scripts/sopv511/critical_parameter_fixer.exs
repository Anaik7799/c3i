#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule CriticalParameterFixer do
  @moduledoc """
  AEE SOPv5.11 Critical Parameter Fixer

  Systematically fixes parameter scope errors causing compilation failures.
  """

  def main(_args) do
    IO.puts "[#{timestamp()}] 🚀 AEE SOPv5.11 Critical Parameter Fixer Starting..."

    # Target specific files with known parameter issues
    critical_fixes = [
      {"lib/indrajaal/accounts/session_security.ex", :parameter_scope},
      {"lib/indrajaal/agent_comments/comprehensive_agent_integrator.ex", :parameter_scope},
      {"lib/indrajaal/access_control/analytics_engine.ex", :parameter_scope},
      {"lib/indrajaal/access_control/timescale_integration.ex", :parameter_scope}
    ]

    Enum.each(critical_fixes, fn {file_path, fix_type} ->
      apply_critical_fix(file_path, fix_type)
    end)

    # Test compilation
    test_compilation()

    IO.puts "[#{timestamp()}] ✅ AEE SOPv5.11 Critical Parameter Fixer Complete"
  end

  defp apply_critical_fix(file_path, :parameter_scope) do
    IO.puts "[#{timestamp()}] 🔧 Fixing parameter scope in #{file_path}"

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = fix_parameter_scope_issues(content)
        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts "[#{timestamp()}] ✅ Fixed parameter scope in #{file_path}"
        else
          IO.puts "[#{timestamp()}] ℹ️ No fixes needed in #{file_path}"
        end
      {:error, reason} ->
        IO.puts "[#{timestamp()}] ❌ Could not read #{file_path}: #{reason}"
    end
  end

  defp fix_parameter_scope_issues(content) do
    content
    # Fix function definitions that reference undefined variables
    |> fix_function_definitions()
    # Add missing parameters
    |> add_missing_parameters()
    # Fix underscore parameter issues
    |> fix_underscore_parameters()
  end

  defp fix_function_definitions(content) do
    # Fix specific patterns we know are problematic
    content
    |> String.replace("def validate_session(session, token)", "def validate_session(session, token, conn, __opts \\\\ [])")
    |> String.replace("def create_session(__user_id, token, device_info)", "def create_session(__user_id, token, device_info, conn, __opts \\\\ [])")
    |> String.replace("def generate_fingerprint()", "def generate_fingerprint(conn)")
    |> String.replace("def detect_anomalies(session)", "def detect_anomalies(session, conn)")
    |> String.replace("def handle_call({:get_stats}, _from, _state)", "def handle_call({:get_stats}, _from, __state)")
    |> String.replace("def handle_call({:validate_compliance}, _from, _state)", "def handle_call({:validate_compliance}, _from, __state)")
    |> String.replace("def handle_call({:add_comment, file_path, module_analysis}, _from, _state)", "def handle_call({:add_comment, file_path, module_analysis}, _from, __state)")
    |> String.replace("def handle_call(:scan_modules, _from, _state)", "def handle_call(:scan_modules, _from, __state)")
    |> String.replace("def handle_call({:execute_comprehensive_integration, _opts}, _from, _state)", "def handle_call({:execute_comprehensive_integration, __opts}, _from, __state)")
    |> String.replace("def start_link(_opts)", "def start_link(__opts \\\\ [])")
    |> String.replace("def execute_comprehensive_integration(_opts)", "def execute_comprehensive_integration(__opts \\\\ [])")
  end

  defp add_missing_parameters(content) do
    content
    # Add parameters to analytics functions
    |> String.replace("def analyze_user_behavior(__tenant_id, __user_id)", "def analyze_user_behavior(__tenant_id, __user_id, __opts \\\\ [])")
    |> String.replace("def predict_security_incidents(__tenant_id)", "def predict_security_incidents(__tenant_id, __opts \\\\ [])")
    |> String.replace("def calculate_risk_score(__tenant_id, __user_id)", "def calculate_risk_score(__tenant_id, __user_id, __opts \\\\ [])")
    |> String.replace("def detect_anomalies(__tenant_id)", "def detect_anomalies(__tenant_id, __opts \\\\ [])")
    |> String.replace("def analyze_access_patterns(__tenant_id)", "def analyze_access_patterns(__tenant_id, __opts \\\\ [])")
    # Add parameters to timescale functions
    |> String.replace("def log_authentication_event(__event_type, __context)", "def log_authentication_event(__event_type, __context, __opts \\\\ [])")
    |> String.replace("def log_authorization_event(__event_type, __context)", "def log_authorization_event(__event_type, __context, __opts \\\\ [])")
    |> String.replace("def log_access_control_event(__event_type, __context)", "def log_access_control_event(__event_type, __context, __opts \\\\ [])")
    |> String.replace("def report_security_violation(violation_type, __context)", "def report_security_violation(violation_type, __context, __opts \\\\ [])")
    |> String.replace("def analyze_access_patterns(__tenant_id)", "def analyze_access_patterns(__tenant_id, __opts \\\\ [])")
    |> String.replace("def generate_compliance_report(__tenant_id, report_type)", "def generate_compliance_report(__tenant_id, report_type, __opts \\\\ [])")
  end

  defp fix_underscore_parameters(content) do
    # Fix common underscore parameter mismatches
    content
    |> String.replace("_state) do\n    __state", "__state) do\n    __state")
    |> String.replace("_opts) do\n    __opts", "__opts) do\n    __opts")
    |> String.replace("_params) do\n    __params", "__params) do\n    __params")
    |> String.replace("_conn) do\n    conn", "conn) do\n    conn")
  end

  defp test_compilation do
    IO.puts "[#{timestamp()}] 🔍 Testing compilation after fixes..."

    {_output, _exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true, env: [{"ELIXIR_ERL_OPTIONS", "+S 16"}])

    File.write!("5-critical-parameter-fix-compile.log", output)

    error_count = count_errors(output)
    warning_count = count_warnings(output)

    IO.puts "[#{timestamp()}] 📊 Compilation Results:"
    IO.puts "[#{timestamp()}]   - Exit code: #{exit_code}"
    IO.puts "[#{timestamp()}]   - Errors: #{error_count}"
    IO.puts "[#{timestamp()}]   - Warnings: #{warning_count}"

    if exit_code == 0 do
      IO.puts "[#{timestamp()}] 🎉 COMPILATION SUCCESS!"
    else
      IO.puts "[#{timestamp()}] ❌ Compilation still has errors - see 5-critical-parameter-fix-compile.log"
    end
  end

  defp count_errors(output) do
    (Regex.scan(~r/error:/, output) |> length()) +
    (Regex.scan(~r/\*\* \(/, output) |> length()) +
    (Regex.scan(~r/undefined variable/, output) |> length()) +
    (Regex.scan(~r/undefined function/, output) |> length())
  end

  defp count_warnings(output) do
    (Regex.scan(~r/warning:/, output) |> length()) +
    (Regex.scan(~r/is unused/, output) |> length())
  end

  defp timestamp do
    DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")
  end
end

CriticalParameterFixer.main(System.argv())