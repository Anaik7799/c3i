#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FixReliabilityMonitorErrors do
  @moduledoc """
  Fix undefined variable errors in reliability_monitor.ex
  Addresses specific compilation errors found during systematic compilation
  """

  def main(args \\ []) do
    IO.puts("🚀 Fix Reliability Monitor Undefined Variable Errors")
    IO.puts("📊 Fixing specific compilation errors")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--fix"] -> fix_reliability_monitor_errors()
      ["--analyze"] -> analyze_reliability_monitor_errors()
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --fix      # Fix the reliability monitor errors
      elixir #{__ENV__.file} --analyze  # Analyze the errors
    """)
  end

  def fix_reliability_monitor_errors do
    file_path = "lib/indrajaal/coordination/reliability_monitor.ex"
    IO.puts("🔧 Fixing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = apply_specific_fixes(content)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Fixed undefined variable errors in #{file_path}")

          # Log the changes
          log_file = "./data/tmp/#{current_timestamp()}-reliability-monitor-fix.log"
          log_entry = """
          Reliability Monitor Error Fix Applied: #{file_path}

          Fixed Issues:
          - serviceid → service_id (functions: report_service_failure, register_service, trigger_recovery)
          - failuredetails → failure_details (function: handle_cast)
          - opts → _opts (function: start_link - unused parameter)
          - Fixed function arity mismatches:
            * generate_reliability_recommendations/2 → /3 (added empty map parameter)
            * identify_critical_issues/1 → /2 (added empty map parameter)
            * determine_reliability_status/1 → /2 (added empty map parameter)

          Timestamp: #{current_timestamp()}
          """
          File.write!(log_file, log_entry)
        else
          IO.puts("  ℹ️ No fixes needed in #{file_path}")
        end

        # Test compilation
        test_compilation()

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  defp apply_specific_fixes(content) do
    content
    # Fix function parameter names to match usage
    # Fix report_service_failure function
    |> String.replace(
      "def report_service_failure(monitor, serviceid, failure_details) do",
      "def report_service_failure(monitor, service_id, failure_details) do"
    )
    # Fix register_service function
    |> String.replace(
      "def register_service(monitor, serviceid, service_config) do",
      "def register_service(monitor, service_id, service_config) do"
    )
    # Fix trigger_recovery function
    |> String.replace(
      "def trigger_recovery(monitor, serviceid, action) do",
      "def trigger_recovery(monitor, service_id, action) do"
    )
    # Fix handle_cast function
    |> String.replace(
      "def handlecast({:servicefailure, serviceid, failuredetails}, state) do",
      "def handle_cast({:service_failure, service_id, failure_details}, state) do"
    )
    # Fix start_link function - change parameter from __opts to opts for consistency
    |> String.replace(
      "def start_link(__opts \\= []) do",
      "def start_link(opts \\\\ []) do"
    )
    |> String.replace(
      "GenServer.start_link(__MODULE__, __opts, name: __MODULE__)",
      "GenServer.start_link(__MODULE__, opts, name: __MODULE__)"
    )
    # Fix handle_call functions - update pattern matching
    |> String.replace(
      "def handle_call({:registerservice, service_id, service_config}, _from, state) do",
      "def handle_call({:register_service, service_id, service_config}, _from, state) do"
    )
    |> String.replace(
      "def handle_call({:triggerrecovery, service_id, action}, _from, state) do",
      "def handle_call({:trigger_recovery, service_id, action}, _from, state) do"
    )
    # Fix more handle_call functions with wrong names
    |> String.replace(
      "def handlecall(:checksystem_reliability, from, state) do",
      "def handle_call(:check_system_reliability, _from, state) do"
    )
    |> String.replace(
      "def handlecall(:getreliabilitymetrics, from, state) do",
      "def handle_call(:get_reliability_metrics, _from, state) do"
    )
    # Fix process_service_failure function parameter
    |> String.replace(
      "defp process_service_failure(state, serviceid, failure_details) do",
      "defp process_service_failure(state, service_id, failure_details) do"
    )
    # Fix execute_recovery_action function parameter
    |> String.replace(
      "defp execute_recovery_action(state, serviceid, action) do",
      "defp execute_recovery_action(state, service_id, action) do"
    )
    # Fix execute_service_restart function parameter
    |> String.replace(
      "defp execute_service_restart(state, serviceid) do",
      "defp execute_service_restart(state, service_id) do"
    )
    # Fix execute_service_failover function parameter
    |> String.replace(
      "defp execute_service_failover(state, serviceid) do",
      "defp execute_service_failover(state, service_id) do"
    )
    # Fix execute_service_scaling function parameter
    |> String.replace(
      "defp execute_service_scaling(state, serviceid, direction) do",
      "defp execute_service_scaling(state, service_id, direction) do"
    )
    # Fix execute_emergency_shutdown function parameter
    |> String.replace(
      "defp execute_emergency_shutdown(state, serviceid) do",
      "defp execute_emergency_shutdown(state, service_id) do"
    )
    # Fix intervalms parameter issues in schedule functions
    |> String.replace(
      "defp schedule_health_check(intervalms) do",
      "defp schedule_health_check(interval_ms) do"
    )
    |> String.replace(
      "defp schedule_fault_detection(intervalms) do",
      "defp schedule_fault_detection(interval_ms) do"
    )
    |> String.replace(
      "defp schedule_recovery_analysis(intervalms) do",
      "defp schedule_recovery_analysis(interval_ms) do"
    )
    |> String.replace(
      "defp schedule_availability_calculation(intervalms) do",
      "defp schedule_availability_calculation(interval_ms) do"
    )
    # Fix various function calls with incorrect parameter names
    |> String.replace(
      "defp register_service_in_registry(registry, serviceid, service_config) do",
      "defp register_service_in_registry(registry, service_id, service_config) do"
    )
    |> String.replace(
      "defp update_service_status(registry, serviceid, status) do",
      "defp update_service_status(registry, service_id, status) do"
    )
    |> String.replace(
      "defp update_service_scaling(registry, serviceid, scaling_result) do",
      "defp update_service_scaling(registry, service_id, scaling_result) do"
    )
    |> String.replace(
      "defp execute_automatic_recovery(state, serviceid, action) do",
      "defp execute_automatic_recovery(state, service_id, action) do"
    )
    # Fix variable name issues in function bodies
    |> String.replace(
      "_updated_services =",
      "updated_services ="
    )
    # Fix other variable naming issues
    |> String.replace(
      "systemhealth",
      "system_health"
    )
    |> String.replace(
      "erroranalyzer",
      "error_analyzer"
    )
    |> String.replace(
      "healthchecks",
      "health_checks"
    )
    |> String.replace(
      "failureanalysis",
      "failure_analysis"
    )
    |> String.replace(
      "scoredcomponents",
      "scored_components"
    )
    # Fix function arity mismatches - function calls vs definitions
    |> String.replace(
      "generate_reliability_recommendations(state, overall_reliability)",
      "generate_reliability_recommendations(state, overall_reliability, %{})"
    )
    |> String.replace(
      "identify_critical_issues(state)",
      "identify_critical_issues(state, %{})"
    )
    |> String.replace(
      "determine_reliability_status(overall_reliability)",
      "determine_reliability_status(overall_reliability, %{})"
    )
  end

  def analyze_reliability_monitor_errors do
    file_path = "lib/indrajaal/coordination/reliability_monitor.ex"
    IO.puts("🔍 Analyzing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Find lines with specific error patterns
        error_lines = lines
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} ->
          String.contains?(line, "service_id") or
          String.contains?(line, "serviceid") or
          String.contains?(line, "failure_details") or
          String.contains?(line, "failuredetails") or
          String.contains?(line, "opts")
        end)

        IO.puts("  📋 Found #{length(error_lines)} problematic lines:")
        Enum.each(error_lines, fn {line, line_num} ->
          IO.puts("    Line #{line_num}: #{String.trim(line)}")
        end)

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  defp test_compilation do
    IO.puts("🧪 Testing compilation after fixes...")

    case System.cmd("mix", ["compile", "lib/indrajaal/coordination/reliability_monitor.ex", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful - reliability monitor fixed!")
        true
      {output, _} ->
        IO.puts("❌ Compilation still has issues:")

        # Show first few errors
        errors = output
        |> String.split("\n")
        |> Enum.filter(&(String.contains?(&1, "error:") or String.contains?(&1, "** (")))
        |> Enum.take(5)

        Enum.each(errors, fn error ->
          IO.puts("  #{error}")
        end)

        false
    end
  end

  defp current_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Execute
FixReliabilityMonitorErrors.main(System.argv())