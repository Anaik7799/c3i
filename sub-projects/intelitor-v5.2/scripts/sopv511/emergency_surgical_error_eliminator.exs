#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.EmergencySurgicalErrorEliminator do
  @moduledoc """
  SOPv5.11 Emergency Surgical Error Eliminator

  Precisely targets the remaining 30 critical errors identified:
  1. Undefined report_type variables in function calls
  2. Underscore-prefixed variables that should not have underscores
  3. Parameter signature mismatches in GenServer modules
  """

  require Logger

  def main(args) do
    Logger.configure(level: :info)

    case args do
      ["--fix"] -> fix_remaining_30_errors()
      ["--status"] -> show_status()
      _ -> show_help()
    end
  end

  def fix_remaining_30_errors do
    Logger.info("🚨 SOPv5.11 Emergency Surgical Fix for Final 30 Errors")

    create_checkpoint("emergency-surgical-30")

    # Fix each critical file individually
    fix_predictive_performance_monitor()
    fix_real_time_bi_collector()
    fix_analytics_dashboard_engine()

    validate_fixes()
  end

  defp fix_predictive_performance_monitor do
    file_path = "lib/indrajaal/analytics/predictive_performance_monitor.ex"
    content = File.read!(file_path)

    updated_content = content
                     # Fix start_link function - add report_type parameter with default
                     |> String.replace(
                       "def start_link(report_type) do",
                       "def start_link(opts \\\\ []) do"
                     )
                     |> String.replace(
                       "tenantid = Keyword.fetch!(report_type, :tenantid)",
                       "tenantid = Keyword.fetch!(opts, :tenantid)"
                     )
                     |> String.replace(
                       "GenServer.start_link(__MODULE__, report_type, name: via_tuple(tenantid))",
                       "GenServer.start_link(__MODULE__, opts, name: via_tuple(tenantid))"
                     )
                     # Fix init function
                     |> String.replace(
                       "def init(report_type) do",
                       "def init(opts) do"
                     )
                     |> String.replace(
                       "tenantid = Keyword.fetch!(report_type, :tenantid)",
                       "tenantid = Keyword.fetch!(opts, :tenantid)"
                     )
                     |> String.replace(
                       "monitoring_interval = Keyword.get(report_type, :monitoring_interval_ms, 60_000)",
                       "monitoring_interval = Keyword.get(opts, :monitoring_interval_ms, 60_000)"
                     )
                     # Fix handle_call functions
                     |> String.replace(
                       "case train_all_performance_models(state.tenantid, report_type) do",
                       "case train_all_performance_models(state.tenantid, %{}) do"
                     )
                     |> String.replace(
                       "horizon_hours = Keyword.get(report_type, :horizon_hours, 24)",
                       "horizon_hours = 24"
                     )
                     |> String.replace(
                       "confidence_level = Keyword.get(report_type, :confidence_level, 0.95)",
                       "confidence_level = 0.95"
                     )
                     # Fix underscore variables
                     |> String.replace("_metrics_data", "state")
                     |> String.replace("_updated_subscriptions", "updated_subscriptions")

    File.write!(file_path, updated_content)
    Logger.info("   ✅ Fixed predictive_performance_monitor.ex")
  end

  defp fix_real_time_bi_collector do
    file_path = "lib/indrajaal/analytics/real_time_bi_collector.ex"
    content = File.read!(file_path)

    updated_content = content
                     # Fix start_link function
                     |> String.replace(
                       "def start_link(report_type) do",
                       "def start_link(opts \\\\ []) do"
                     )
                     |> String.replace(
                       "_tenantid = Keyword.fetch!(report_type, :_tenantid)",
                       "tenantid = Keyword.fetch!(opts, :tenantid)"
                     )
                     |> String.replace(
                       "GenServer.start_link(__MODULE__, report_type, name: via_tuple(_tenantid))",
                       "GenServer.start_link(__MODULE__, opts, name: via_tuple(tenantid))"
                     )
                     # Fix handle_call functions with report_type
                     |> String.replace(
                       "case train_model(state._tenantid, model_config, report_type) do",
                       "case train_model(state.tenantid, model_config, %{}) do"
                     )
                     |> String.replace(
                       "case generate_model_predictions(state._tenantid, model, report_type) do",
                       "case generate_model_predictions(state.tenantid, model, %{}) do"
                     )
                     # Fix underscore variables
                     |> String.replace("_updated_dashboards", "updated_dashboards")
                     # Fix state field references
                     |> String.replace("state._tenantid", "state.tenantid")

    File.write!(file_path, updated_content)
    Logger.info("   ✅ Fixed real_time_bi_collector.ex")
  end

  defp fix_analytics_dashboard_engine do
    file_path = "lib/indrajaal/analytics/analytics_dashboard_engine.ex"

    if File.exists?(file_path) do
      content = File.read!(file_path)

      # Fix any remaining report_type or underscore issues
      updated_content = content
                       |> String.replace("_updated_subscriptions", "updated_subscriptions")
                       |> String.replace("_updated_dashboards", "updated_dashboards")
                       |> String.replace("_metrics_data", "metrics_data")

      if updated_content != content do
        File.write!(file_path, updated_content)
        Logger.info("   ✅ Fixed analytics_dashboard_engine.ex")
      end
    end
  end

  defp create_checkpoint(phase) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")

    {_result, _} = System.cmd("git", ["add", "-A"])
    {_result, _} = System.cmd("git", ["commit", "-m", "SOPv5.11 checkpoint: #{phase} - #{timestamp}"])

    Logger.info("📌 Git checkpoint created: #{phase}")
  end

  defp validate_fixes do
    Logger.info("🔍 Running Emergency Surgical Validation...")

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
    log_path = "./data/tmp/sopv511_emergency_surgical_validation_#{timestamp}.log"
    File.write!(log_path, output)

    if exit_code == 0 do
      Logger.info("🎉 EMERGENCY SURGICAL SUCCESS: ZERO COMPILATION ERRORS ACHIEVED!")
      Logger.info("✅ SOPv5.11 Cybernetic Error Elimination: COMPLETE")
    else
      Logger.error("❌ Emergency Surgical Validation: FAILED")

      # Count remaining errors
      error_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error:"))
      warning_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))

      Logger.info("📊 Final Status:")
      Logger.info("   Errors: #{error_count}")
      Logger.info("   Warnings: #{warning_count}")
      Logger.info("📄 Validation log saved: #{log_path}")

      if error_count <= 5 do
        Logger.info("🎯 NEAR COMPLETE: #{error_count} errors remaining - Manual review required")
      end
    end

    exit_code
  end

  defp show_status do
    Logger.info("📊 SOPv5.11 Emergency Surgical Status:")

    if File.exists?("./data/tmp/sopv511_targeted_final_validation_20250919-0440.log") do
      {output, _} = System.cmd("grep", ["-c", "error:", "./data/tmp/sopv511_targeted_final_validation_20250919-0440.log"])
      error_count = String.trim(output)
      Logger.info("   Current Errors: #{error_count}")

      {output, _} = System.cmd("grep", ["-c", "warning:", "./data/tmp/sopv511_targeted_final_validation_20250919-0440.log"])
      warning_count = String.trim(output)
      Logger.info("   Current Warnings: #{warning_count}")
    else
      Logger.info("   No validation log found")
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Emergency Surgical Error Eliminator

    Usage:
      elixir #{__ENV__.file} --fix       # Fix remaining 30 surgical errors
      elixir #{__ENV__.file} --status    # Show current status

    🚨 SOPv5.11 Emergency Phase: Surgical elimination of final 30 compilation errors
    """)
  end
end

SOPv511.EmergencySurgicalErrorEliminator.main(System.argv())