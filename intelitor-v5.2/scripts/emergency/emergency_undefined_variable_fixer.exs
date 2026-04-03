#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule EmergencyUndefinedVariableFixer do
  @moduledoc """
  Emergency undefined variable fixer for SOPv5.11 compilation recovery.

  This script applies systematic fixes for the most common undefined variable
  patterns that are blocking compilation.
  """

  require Logger

  @blocking_modules [
    "lib/indrajaal/stamp/runtime_safety_monitors.ex",
    "lib/indrajaal/tracing.ex",
    "lib/indrajaal/deployment/feature_flag_manager.ex",
    "lib/indrajaal/coordination/advanced_multi_agent_coordinator.ex",
    "lib/indrajaal/containers/container_health_monitor.ex",
    "lib/indrajaal/coordination/performance_optimizer.ex",
    "lib/indrajaal/access_control/domain_hooks.ex",
    "lib/indrajaal/alarms/unified_alarm_processor.ex",
    "lib/indrajaal/access_control/timescale_integration.ex",
    "lib/indrajaal/access_control/unified_patterns.ex",
    "lib/indrajaal/analytics/business_intelligence.ex",
    "lib/indrajaal/analytics/business_value_measurement.ex"
  ]

  def main(args) do
    Logger.info("🚨 Emergency Undefined Variable Fixer - SOPv5.11 Mode")
    Logger.info("📋 Processing #{length(@blocking_modules)} blocking modules")

    case args do
      ["--analyze"] -> analyze_undefined_variables()
      ["--fix"] -> fix_undefined_variables()
      ["--validate"] -> validate_fixes()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts("""
    Emergency Undefined Variable Fixer - SOPv5.11 Compilation Recovery

    Usage:
      elixir scripts/emergency/emergency_undefined_variable_fixer.exs --analyze
      elixir scripts/emergency/emergency_undefined_variable_fixer.exs --fix
      elixir scripts/emergency/emergency_undefined_variable_fixer.exs --validate

    Commands:
      --analyze   Analyze undefined variable patterns in blocking modules
      --fix       Apply systematic fixes for undefined variables
      --validate  Validate fixes with compilation test
    """)
  end

  defp analyze_undefined_variables do
    Logger.info("📊 Analyzing undefined variable patterns...")

    patterns = [
      # Common undefined variable patterns from compilation log
      {"alert_config", "alertconfig"},
      {"target_value", "targetvalue"},
      {"dashboard_data", "dashboarddata"},
      {"metrics_data", "metricsdata"},
      {"monitoring_results", "monitoringresults"},
      {"dashboard_params", "dashboardparams"},
      {"__state", "_state"}  # underscore variable misuse
    ]

    results = %{}

    for module_path <- @blocking_modules do
      if File.exists?(module_path) do
        content = File.read!(module_path)

        module_patterns = Enum.reduce(patterns, [], fn {correct, incorrect}, acc ->
          if String.contains?(content, incorrect) and not String.contains?(content, correct) do
            [{correct, incorrect} | acc]
          else
            acc
          end
        end)

        if module_patterns != [] do
          results = Map.put(results, module_path, module_patterns)
        end
      end
    end

    Logger.info("🔍 Analysis Results:")
    for {module, patterns} <- results do
      Logger.info("📁 #{module}:")
      for {correct, incorrect} <- patterns do
        Logger.info("  ❌ #{incorrect} → ✅ #{correct}")
      end
    end

    save_analysis_report(results)
  end

  defp fix_undefined_variables do
    Logger.info("🔧 Applying systematic undefined variable fixes...")

    # Common fix patterns based on compilation log analysis
    fix_patterns = [
      # Underscore variable misuse fixes
      {"(__state)", "(state)"},
      {"__state.", "state."},
      {"__state,", "state,"},
      {"__state)", "state)"},

      # Variable name normalization
      {"alertconfig", "alert_config"},
      {"targetvalue", "target_value"},
      {"dashboarddata", "dashboard_data"},
      {"metricsdata", "metrics_data"},
      {"monitoringresults", "monitoring_results"},
      {"dashboardparams", "dashboard_params"},

      # Function parameter fixes
      {"def handlecall(", "def handle_call("},
      {"def handlinfo(", "def handle_info("},

      # Common variable declaration patterns
      {"= generate_dashboard_data(__state)", "= generate_dashboard_data(state)"},
      {"{:reply, dashboard_data,", "{:reply, dashboard_data,"},
    ]

    fixed_files = []

    for module_path <- @blocking_modules do
      if File.exists?(module_path) do
        content = File.read!(module_path)
        original_content = content

        # Apply fixes
        updated_content = Enum.reduce(fix_patterns, content, fn {pattern, replacement}, acc ->
          String.replace(acc, pattern, replacement)
        end)

        if updated_content != original_content do
          # Create backup
          backup_path = "#{module_path}.backup.#{DateTime.utc_now() |> DateTime.to_unix()}"
          File.write!(backup_path, original_content)

          # Apply fix
          File.write!(module_path, updated_content)

          Logger.info("✅ Fixed: #{module_path}")
          Logger.info("💾 Backup: #{backup_path}")

          fixed_files = [module_path | fixed_files]
        end
      end
    end

    Logger.info("🎯 Fixed #{length(fixed_files)} files:")
    for file <- fixed_files do
      Logger.info("  ✅ #{file}")
    end

    save_fix_report(fixed_files)
  end

  defp validate_fixes do
    Logger.info("🔍 Validating fixes with compilation test...")

    # Run compilation test
    {output, exit_code} = System.cmd("mix", ["compile", "--force"], stderr_to_stdout: true)

    if exit_code == 0 do
      Logger.info("✅ Compilation successful - fixes validated!")
    else
      Logger.error("❌ Compilation still failing:")
      Logger.error(output)

      # Extract remaining errors
      error_lines = String.split(output, "\n")
                   |> Enum.filter(&String.contains?(&1, "error:"))
                   |> Enum.take(10)

      Logger.info("🔍 Remaining errors (first 10):")
      for error <- error_lines do
        Logger.info("  ❌ #{error}")
      end
    end

    save_validation_report(exit_code, output)
  end

  defp save_analysis_report(results) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_path = "./data/tmp/emergency_analysis_#{timestamp}.json"

    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      analysis_type: "undefined_variables",
      results: results,
      total_modules: length(@blocking_modules),
      affected_modules: map_size(results)
    }

    File.write!(report_path, Jason.encode!(report, pretty: true))
    Logger.info("📊 Analysis report saved: #{report_path}")
  end

  defp save_fix_report(fixed_files) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_path = "./data/tmp/emergency_fixes_#{timestamp}.json"

    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      fix_type: "undefined_variables",
      fixed_files: fixed_files,
      total_fixed: length(fixed_files)
    }

    File.write!(report_path, Jason.encode!(report, pretty: true))
    Logger.info("🔧 Fix report saved: #{report_path}")
  end

  defp save_validation_report(exit_code, output) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_path = "./data/tmp/emergency_validation_#{timestamp}.json"

    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      validation_type: "compilation_test",
      exit_code: exit_code,
      success: exit_code == 0,
      output: output
    }

    File.write!(report_path, Jason.encode!(report, pretty: true))
    Logger.info("🔍 Validation report saved: #{report_path}")
  end
end

# Run if called directly
if System.argv() != [] do
  EmergencyUndefinedVariableFixer.main(System.argv())
end