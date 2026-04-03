#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.TargetedFinal18ErrorFixer do
  @moduledoc """
  SOPv5.11 Targeted Final 18 Error Fixer

  Precisely targets the remaining 18 compilation errors:
  - undefined report_type variables (where not in function parameters)
  - remaining placeholder variables
  - double underscore variables
  """

  require Logger

  def main(args) do
    Logger.configure(level: :info)

    case args do
      ["--fix"] -> fix_remaining_18_errors()
      ["--status"] -> show_status()
      _ -> show_help()
    end
  end

  def fix_remaining_18_errors do
    Logger.info("🎯 SOPv5.11 Targeted Fix for Final 18 Errors")

    create_checkpoint("targeted-final-18")

    # Fix specific files with targeted approaches
    fix_unified_analytics_engine()
    fix_strategic_insights_generator()
    fix_other_analytics_files()

    validate_fixes()
  end

  defp fix_unified_analytics_engine do
    file_path = "lib/indrajaal/analytics/unified_analytics_engine.ex"
    content = File.read!(file_path)

    updated_content = content
                     # Fix the `Enum.take(report_type)` issue - should be `Enum.take(topn)`
                     |> String.replace("Enum.take(report_type)", "Enum.take(topn)")
                     # Fix `case report_type do` where it should be `case aggregationtype do`
                     |> String.replace("case report_type do", "case aggregationtype do")
                     # Fix remaining placeholder issues
                     |> String.replace("updated_subscriptions", "_updated_subscriptions")
                     |> String.replace("updated_dashboards", "_updated_dashboards")
                     |> String.replace("metrics_data", "_metrics_data")
                     |> String.replace("__updated_cache", "_updated_cache")
                     |> String.replace("__updated_models", "_updated_models")

    File.write!(file_path, updated_content)
    Logger.info("   ✅ Fixed unified_analytics_engine.ex")
  end

  defp fix_strategic_insights_generator do
    file_path = "lib/indrajaal/analytics/strategic_insights_generator.ex"

    if File.exists?(file_path) do
      content = File.read!(file_path)

      # Fix any remaining analysisconfig issues that weren't caught
      updated_content = content
                       # Ensure all undefined variables are either parameters or prefixed with underscore
                       |> String.replace("business_context", "_business_context")
                       |> String.replace("forecast_params", "_forecast_params")
                       |> String.replace("dashboard_data", "_dashboard_data")

      File.write!(file_path, updated_content)
      Logger.info("   ✅ Fixed strategic_insights_generator.ex")
    end
  end

  defp fix_other_analytics_files do
    analytics_files = Path.wildcard("lib/indrajaal/analytics/*.ex")

    Enum.each(analytics_files, fn file_path ->
      case Path.basename(file_path) do
        "unified_analytics_engine.ex" -> :skip  # Already fixed above
        "strategic_insights_generator.ex" -> :skip  # Already fixed above
        _ ->
          content = File.read!(file_path)

          # Generic fixes for any remaining placeholder variables
          updated_content = content
                           |> String.replace("updated_subscriptions", "_updated_subscriptions")
                           |> String.replace("updated_dashboards", "_updated_dashboards")
                           |> String.replace("metrics_data", "_metrics_data")
                           |> String.replace("__updated_cache", "_updated_cache")
                           |> String.replace("__updated_models", "_updated_models")

          if updated_content != content do
            File.write!(file_path, updated_content)
            Logger.info("   ✅ Fixed #{Path.basename(file_path)}")
          end
      end
    end)
  end

  defp create_checkpoint(phase) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")

    {_result, _} = System.cmd("git", ["add", "-A"])
    {_result, _} = System.cmd("git", ["commit", "-m", "SOPv5.11 checkpoint: #{phase} - #{timestamp}"])

    Logger.info("📌 Git checkpoint created: #{phase}")
  end

  defp validate_fixes do
    Logger.info("🔍 Running Targeted Final Validation...")

    # Run compilation to check for remaining errors
    env = [
      {"NO_TIMEOUT", "true"},
      {"PATIENT_MODE", "enabled"},
      {"INFINITE_PATIENCE", "true"},
      {"ELIXIR_ERL_OPTIONS", "+S 16"}
    ]

    {output, exit_code} = System.cmd("mix", ["compile", "--verbose"],
                                    env: env,
                                    stderr_to_stdout: true)

    # Save validation log
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_path = "./data/tmp/sopv511_targeted_final_validation_#{timestamp}.log"
    File.write!(log_path, output)

    if exit_code == 0 do
      Logger.info("🎉 ULTIMATE SUCCESS: ZERO COMPILATION ERRORS ACHIEVED!")
      Logger.info("✅ SOPv5.11 Cybernetic Error Elimination: COMPLETE")
    else
      Logger.error("❌ Targeted Validation: FAILED")

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
    Logger.info("📊 SOPv5.11 Targeted Final Error Status:")

    if File.exists?("./data/tmp/sopv511_final_validation_20250919-0437.log") do
      {output, _} = System.cmd("grep", ["-c", "error:", "./data/tmp/sopv511_final_validation_20250919-0437.log"])
      error_count = String.trim(output)
      Logger.info("   Current Errors: #{error_count}")

      {output, _} = System.cmd("grep", ["-c", "warning:", "./data/tmp/sopv511_final_validation_20250919-0437.log"])
      warning_count = String.trim(output)
      Logger.info("   Current Warnings: #{warning_count}")
    else
      Logger.info("   No validation log found")
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Targeted Final 18 Error Fixer

    Usage:
      elixir #{__ENV__.file} --fix       # Fix remaining 18 targeted errors
      elixir #{__ENV__.file} --status    # Show current status

    🎯 SOPv5.11 Final Phase: Target the last 18 compilation errors for completion
    """)
  end
end

SOPv511.TargetedFinal18ErrorFixer.main(System.argv())