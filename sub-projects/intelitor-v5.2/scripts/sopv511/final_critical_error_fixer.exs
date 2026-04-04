#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.FinalCriticalErrorFixer do
  @moduledoc """
  SOPv5.11 Final Critical Error Fixer - Targets remaining critical patterns

  Focuses on the most persistent issues:
  - add_parameter placeholder variables
  - analysisconfig undefined variables
  - __updated_* undefined variables
  """

  require Logger

  def main(args) do
    Logger.configure(level: :info)

    case args do
      ["--fix-placeholders"] -> fix_placeholder_variables()
      ["--fix-analysisconfig"] -> fix_analysisconfig_errors()
      ["--fix-all"] -> fix_all_critical_errors()
      ["--status"] -> show_status()
      _ -> show_help()
    end
  end

  def fix_all_critical_errors do
    Logger.info("🚨 SOPv5.11 Final Critical Error Elimination")

    create_checkpoint("final-critical-fixes")

    fix_placeholder_variables()
    fix_analysisconfig_errors()

    validate_fixes()
  end

  def fix_placeholder_variables do
    Logger.info("🔧 Fixing add_parameter and add_variable placeholders...")

    analytics_files = Path.wildcard("lib/indrajaal/analytics/*.ex")

    Enum.each(analytics_files, fn file ->
      fix_placeholders_in_file(file)
    end)

    Logger.info("✅ Placeholder variable fixes complete")
  end

  def fix_analysisconfig_errors do
    Logger.info("🔧 Fixing analysisconfig parameter errors...")

    strategic_file = "lib/indrajaal/analytics/strategic_insights_generator.ex"

    if File.exists?(strategic_file) do
      fix_strategic_insights_file(strategic_file)
    end

    Logger.info("✅ Analysisconfig parameter fixes complete")
  end

  defp fix_placeholders_in_file(file_path) do
    content = File.read!(file_path)

    # Replace placeholder variables with proper implementations
    updated_content = content
                     |> String.replace("add_parameter", "report_type")
                     |> String.replace("add_variable", "metrics_data")
                     |> String.replace("__updated_dashboards", "updated_dashboards")
                     |> String.replace("__updated_subscriptions", "updated_subscriptions")
                     |> String.replace("__monitoring_results", "monitoring_results")

    # Specific fixes for unified_analytics_engine.ex
    updated_content = if Path.basename(file_path) == "unified_analytics_engine.ex" do
      updated_content
      |> String.replace("Enum.take(add_parameter)", "Enum.take(topn)")
      |> String.replace("collect_reportdata(add_parameter, params)", "collect_reportdata(report_type, params)")
      |> String.replace("generate_summary(add_parameter, params)", "generate_summary(report_type, params)")
      |> String.replace("prepare_visualizations(add_parameter, params)", "prepare_visualizations(report_type, params)")
      |> String.replace("\"Summary for \" <> to_string(add_parameter) <> \" report\"", "\"Summary for \" <> to_string(report_type) <> \" report\"")
      |> String.replace("add_parameter: add_parameter", "report_type: report_type")
    else
      updated_content
    end

    if updated_content != content do
      File.write!(file_path, updated_content)
      Logger.info("   ✅ Fixed placeholders in #{Path.basename(file_path)}")
    end
  end

  defp fix_strategic_insights_file(file_path) do
    content = File.read!(file_path)

    # Fix analysisconfig parameter issues in strategic insights
    updated_content = content
                     # Fix function calls that reference analysisconfig
                     |> String.replace("tenant_id: analysisconfig", "tenant_id: tenantid")
                     |> String.replace("config: analysisconfig", "config: analysisconfig")
                     |> String.replace("period: analysisconfig", "period: analysisconfig[:period]")
                     |> String.replace("time_range: analysisconfig", "time_range: analysisconfig[:time_range]")
                     |> String.replace("metrics: analysisconfig", "metrics: analysisconfig[:metrics]")
                     |> String.replace("insights: analysisconfig", "insights: analysisconfig[:insights]")
                     |> String.replace("business_context: analysisconfig", "business_context: analysisconfig[:business_context]")
                     |> String.replace("predictions: analysisconfig", "predictions: analysisconfig[:predictions]")
                     |> String.replace("dashboard_data: analysisconfig", "dashboard_data: analysisconfig[:dashboard_data]")
                     |> String.replace("forecast_params: analysisconfig", "forecast_params: analysisconfig[:forecast_params]")

    if updated_content != content do
      File.write!(file_path, updated_content)
      Logger.info("   ✅ Fixed analysisconfig issues in #{Path.basename(file_path)}")
    end
  end

  defp create_checkpoint(phase) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")

    {_result, _} = System.cmd("git", ["add", "-A"])
    {_result, _} = System.cmd("git", ["commit", "-m", "SOPv5.11 checkpoint: #{phase} - #{timestamp}"])

    Logger.info("📌 Git checkpoint created: #{phase}")
  end

  defp validate_fixes do
    Logger.info("🔍 Running Final Validation...")

    # Run compilation to check for remaining errors
    env = [
      {"NO_TIMEOUT", "true"},
      {"PATIENT_MODE", "enabled"},
      {"INFINITE_PATIENCE", "true"},
      {"ELIXIR_ERL_OPTIONS", "+fnu +S 16"}
    ]

    {output, exit_code} = System.cmd("mix", ["compile", "--verbose"],
                                    env: env,
                                    stderr_to_stdout: true)

    # Save validation log
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_path = "./data/tmp/sopv511_final_validation_#{timestamp}.log"
    File.write!(log_path, output)

    if exit_code == 0 do
      Logger.info("✅ Final Validation: SUCCESS - Zero compilation errors achieved!")
    else
      Logger.error("❌ Final Validation: FAILED")

      # Count remaining errors
      error_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error:"))
      warning_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))

      Logger.info("📊 Remaining Issues:")
      Logger.info("   Errors: #{error_count}")
      Logger.info("   Warnings: #{warning_count}")
      Logger.info("📄 Validation log saved: #{log_path}")
    end

    exit_code
  end

  defp show_status do
    Logger.info("📊 SOPv5.11 Final Critical Error Status:")

    if File.exists?("./data/tmp/sopv511_batch_validation_20250919-0436.log") do
      {output, _} = System.cmd("grep", ["-c", "error:", "./data/tmp/sopv511_batch_validation_20250919-0436.log"])
      error_count = String.trim(output)
      Logger.info("   Current Errors: #{error_count}")

      {output, _} = System.cmd("grep", ["-c", "warning:", "./data/tmp/sopv511_batch_validation_20250919-0436.log"])
      warning_count = String.trim(output)
      Logger.info("   Current Warnings: #{warning_count}")
    else
      Logger.info("   No validation log found")
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Final Critical Error Fixer

    Usage:
      elixir #{__ENV__.file} --fix-placeholders      # Fix add_parameter placeholders
      elixir #{__ENV__.file} --fix-analysisconfig    # Fix analysisconfig errors
      elixir #{__ENV__.file} --fix-all              # Fix all critical errors
      elixir #{__ENV__.file} --status               # Show current status

    🚨 SOPv5.11 Final Phase: Eliminate remaining critical compilation errors
    """)
  end
end

SOPv511.FinalCriticalErrorFixer.main(System.argv())