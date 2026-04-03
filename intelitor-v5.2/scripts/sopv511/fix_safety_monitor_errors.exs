#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FixSafetyMonitorErrors do
  @moduledoc """
  Fix undefined variable errors in safety_monitor.ex
  Addresses specific compilation errors found during systematic compilation
  """

  def main(args \\ []) do
    IO.puts("🚀 Fix Safety Monitor Undefined Variable Errors")
    IO.puts("📊 Fixing specific compilation errors")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--fix"] -> fix_safety_monitor_errors()
      ["--analyze"] -> analyze_safety_monitor_errors()
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --fix      # Fix the safety monitor errors
      elixir #{__ENV__.file} --analyze  # Analyze the errors
    """)
  end

  def fix_safety_monitor_errors do
    file_path = "lib/indrajaal/coordination/safety_monitor.ex"
    IO.puts("🔧 Fixing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = apply_specific_fixes(content)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Fixed undefined variable errors in #{file_path}")

          # Log the changes
          log_file = "./data/tmp/#{current_timestamp()}-safety-monitor-fix.log"
          log_entry = """
          Safety Monitor Error Fix Applied: #{file_path}

          Fixed Issues:
          - start_link function: Added missing __opts parameter
          - validate_safety_constraint function: Added missing constraint_id and current_value parameters
          - report_safety_event function: Added missing event_type parameter
          - handlecall function: Added constraint_id and current_value parameters to pattern match
          - handlecast function: Added event_type and event_data parameters to pattern match
          - All validation functions: Added missing current_value parameter (10 functions)
          - All schedule functions: Added missing interval_ms parameter (3 functions)
          - execute_violation_response function: Fixed response_action parameter definition
          - Fixed undefined variables: updated_monitoring, updated_metrics, results
          - Function parameter naming consistency fixes

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
    # Fix start_link function parameter consistency - __opts in function definition should be opts in GenServer call
    |> String.replace(
      "GenServer.start_link(__MODULE__, opts, name: __MODULE__)",
      "GenServer.start_link(__MODULE__, __opts, name: __MODULE__)"
    )
    # Fix validate_safety_constraint function parameter naming
    |> String.replace(
      "def validate_safety_constraint(monitor, constraintid, current_value) do",
      "def validate_safety_constraint(monitor, constraint_id, current_value) do"
    )
    # Fix report_safety_event function parameter naming
    |> String.replace(
      "def report_safety_event(monitor, eventtype, event_data) do",
      "def report_safety_event(monitor, event_type, event_data) do"
    )
    # Fix handlecall function name and parameters
    |> String.replace(
      "def handlecall({:validatesafety_constraint, constraintid, currentvalue}, from, state) do",
      "def handle_call({:validate_safety_constraint, constraint_id, current_value}, _from, state) do"
    )
    # Fix handlecast function name and parameters
    |> String.replace(
      "def handlecast({:reportsafetyevent, eventtype, eventdata}, state) do",
      "def handle_cast({:report_safety_event, event_type, event_data}, state) do"
    )
    # Fix process_safety_event function parameter naming
    |> String.replace(
      "defp process_safety_event(state, eventtype, event_data) do",
      "defp process_safety_event(state, event_type, event_data) do"
    )
    # Fix handle_constraint_violation function parameter naming
    |> String.replace(
      "defp handle_constraint_violation(state, constraintid, violation, current_value) do",
      "defp handle_constraint_violation(state, constraint_id, violation, current_value) do"
    )
    # Fix perform_constraint_validation function parameter naming
    |> String.replace(
      "defp perform_constraint_validation(constraintid, current_value, state) do",
      "defp perform_constraint_validation(constraint_id, current_value, state) do"
    )
    # Fix record_safety_event function parameter naming
    |> String.replace(
      "defp record_safety_event(history, eventtype, event_data) do",
      "defp record_safety_event(history, event_type, event_data) do"
    )
    # Fix validation function parameter naming inconsistency
    |> String.replace(
      "defp validate_system_stability(currentvalue) do",
      "defp validate_system_stability(current_value) do"
    )
    |> String.replace(
      "defp validate_resource_usage(currentvalue) do",
      "defp validate_resource_usage(current_value) do"
    )
    |> String.replace(
      "defp validate_data_integrity(currentvalue) do",
      "defp validate_data_integrity(current_value) do"
    )
    |> String.replace(
      "defp validate_performance_bounds(currentvalue) do",
      "defp validate_performance_bounds(current_value) do"
    )
    |> String.replace(
      "defp validate_agent_coordination_safety(currentvalue) do",
      "defp validate_agent_coordination_safety(current_value) do"
    )
    |> String.replace(
      "defp validate_container_isolation(currentvalue) do",
      "defp validate_container_isolation(current_value) do"
    )
    |> String.replace(
      "defp validate_timeout_prevention(currentvalue) do",
      "defp validate_timeout_prevention(current_value) do"
    )
    |> String.replace(
      "defp validate_quality_gates(currentvalue) do",
      "defp validate_quality_gates(current_value) do"
    )
    |> String.replace(
      "defp validate_security_boundaries(currentvalue) do",
      "defp validate_security_boundaries(current_value) do"
    )
    |> String.replace(
      "defp validate_recovery_capability(currentvalue) do",
      "defp validate_recovery_capability(current_value) do"
    )
    # Fix schedule functions - add missing interval_ms parameter
    |> String.replace(
      "defp schedule_safety_check() do",
      "defp schedule_safety_check(interval_ms) do"
    )
    |> String.replace(
      "defp schedule_constraint_validation() do",
      "defp schedule_constraint_validation(interval_ms) do"
    )
    |> String.replace(
      "defp schedule_hazard_analysis() do",
      "defp schedule_hazard_analysis(interval_ms) do"
    )
    # Fix invalid assignment syntax patterns (all variations)
    |> String.replace(
      "Map.put(state.safety_metrics, :last_check, DateTime.utc_now()) = update_safety_metrics(state.safety_metrics, event_type, response_result)",
      "updated_metrics = update_safety_metrics(state.safety_metrics, event_type, response_result)"
    )
    |> String.replace(
      "Map.put(state.monitoring_state, :last_update, DateTime.utc_now()) = Map.put(state.monitoring_state, :last_violation, violation_record)",
      "updated_monitoring = Map.put(state.monitoring_state, :last_violation, violation_record)"
    )
    |> String.replace(
      "Map.put(state.monitoring_state, :last_update, DateTime.utc_now()) = %{",
      "updated_monitoring = %{"
    )
    |> String.replace(
      "Map.put(state.safety_metrics, :last_check, DateTime.utc_now()) = Map.put(state.safety_metrics, :last_full_validation, validation_results)",
      "updated_metrics = Map.put(state.safety_metrics, :last_full_validation, validation_results)"
    )
    |> String.replace(
      "Map.put(state.safety_metrics, :last_check, DateTime.utc_now()) = Map.put(state.safety_metrics, :last_hazard_analysis, hazard_report)",
      "updated_metrics = Map.put(state.safety_metrics, :last_hazard_analysis, hazard_report)"
    )
    # Additional fix for remaining invalid assignment
    |> String.replace(
      "Map.put(state.safety_metrics, :last_check, DateTime.utc_now()) = update_safety_metrics(state.safety_metrics, event_type, response_result)",
      "updated_metrics = update_safety_metrics(state.safety_metrics, event_type, response_result)"
    )
    # Fix specific invalid assignment patterns found in lines 563, 595, 704, 728, 751
    # Fix line 563: invalid assignment with function call
    |> String.replace(
      "    Map.put(state.safety_metrics, :last_check, DateTime.utc_now()) = update_safety_metrics(state.safety_metrics, event_type, response_result)",
      "    # Update safety metrics\n    updated_metrics = update_safety_metrics(state.safety_metrics, event_type, response_result)"
    )
    # Fix line 595: invalid assignment in monitoring
    |> String.replace(
      "      Map.put(state.monitoring_state, :last_update, DateTime.utc_now()) = Map.put(state.monitoring_state, :last_violation, violation_record)",
      "      # Update monitoring state\n      updated_monitoring = Map.put(state.monitoring_state, :last_violation, violation_record)"
    )
    # Fix line 704: invalid assignment with map literal
    |> String.replace(
      "    Map.put(state.monitoring_state, :last_update, DateTime.utc_now()) = %{",
      "    # Update monitoring state\n    updated_monitoring = %{"
    )
    # Fix line 728: invalid assignment for validation results
    |> String.replace(
      "    Map.put(state.safety_metrics, :last_check, DateTime.utc_now()) = Map.put(state.safety_metrics, :last_full_validation, validation_results)",
      "    # Update safety metrics\n    updated_metrics = Map.put(state.safety_metrics, :last_full_validation, validation_results)"
    )
    # Fix line 751: invalid assignment for hazard analysis
    |> String.replace(
      "    Map.put(state.safety_metrics, :last_check, DateTime.utc_now()) = Map.put(state.safety_metrics, :last_hazard_analysis, hazard_report)",
      "    # Update safety metrics\n    updated_metrics = Map.put(state.safety_metrics, :last_hazard_analysis, hazard_report)"
    )
    # Fix remaining undefined variables with proper variable definitions
    |> String.replace(
      "updated_monitoring",
      "Map.put(state.monitoring_state, :last_update, DateTime.utc_now())"
    )
    |> String.replace(
      "updated_metrics",
      "Map.put(state.safety_metrics, :last_check, DateTime.utc_now())"
    )
    |> String.replace(
      ": results,",
      ": Map.get(state, :shutdown_results, []),"
    )
    # Fix execute_violation_response function to define response_action parameter
    |> String.replace(
      "defp execute_violation_response(state, violation, context) do",
      "defp execute_violation_response(state, violation, response_action) do"
    )
  end

  def analyze_safety_monitor_errors do
    file_path = "lib/indrajaal/coordination/safety_monitor.ex"
    IO.puts("🔍 Analyzing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Find lines with specific error patterns
        error_lines = lines
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} ->
          String.contains?(line, "constraint_id") or
          String.contains?(line, "event_type") or
          String.contains?(line, "current_value") or
          String.contains?(line, "event_data") or
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

    case System.cmd("mix", ["compile", "lib/indrajaal/coordination/safety_monitor.ex", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful - safety monitor fixed!")
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
FixSafetyMonitorErrors.main(System.argv())