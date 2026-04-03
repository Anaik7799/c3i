#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FinalUndefinedVariableEliminator do
  @moduledoc """
  Final systematic elimination of ALL remaining undefined variable errors.

  AEE SOPv5.11 Compliance: Complete systematic elimination for zero-error validation checkpoint
  TPS Jidoka Principle: Stop-and-fix approach for final undefined variable resolution
  """

  def run do
    IO.puts("🚀 AEE SOPv5.11: Final Undefined Variable Elimination")
    IO.puts("=====================================================")

    files = [
      "lib/indrajaal/analytics/automated_reporting_alert_system.ex",
      "lib/indrajaal/accounts/authentication.ex"
    ]

    Enum.each(files, &fix_file/1)

    IO.puts("✅ AEE Final Undefined Variable Elimination Complete")
  end

  defp fix_file(file_path) do
    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          original_content = content

          fixed_content = content
          |> fix_automated_reporting_variables()
          |> fix_authentication_variables()

          if fixed_content != original_content do
            File.write!(file_path, fixed_content)
            IO.puts("✅ Fixed: #{Path.relative_to_cwd(file_path)}")
          else
            IO.puts("ℹ️  No changes needed: #{Path.relative_to_cwd(file_path)}")
          end

        {:error, reason} ->
          IO.puts("❌ Error reading #{file_path}: #{reason}")
      end
    else
      IO.puts("❌ File not found: #{file_path}")
    end
  end

  defp fix_automated_reporting_variables(content) do
    content
    # Fix tenantid → __tenant_id for all uses
    |> String.replace(~r/def initialize_automated_system\(tenantid,/, "def initialize_automated_system(__tenant_id,")
    |> String.replace(~r/def configure_escalation_procedures\(tenantid,/, "def configure_escalation_procedures(__tenant_id,")
    |> String.replace(~r/defp setup_alert_monitoring\(tenantid,/, "defp setup_alert_monitoring(__tenant_id,")
    |> String.replace(~r/defp configure_single_alert\(template, tenantid\)/, "defp configure_single_alert(template, __tenant_id)")
    |> String.replace(~r/defp setup_automated_reporting\(tenantid,/, "defp setup_automated_reporting(__tenant_id,")
    |> String.replace(~r/defp schedule_single_report\(reportconfig, __tenant_id\)/, "defp schedule_single_report(report_config, __tenant_id)")
    |> String.replace(~r/defp collect_current_metrics\(tenantid\)/, "defp collect_current_metrics(__tenant_id)")
    |> String.replace(~r/defp evaluate_alert_conditions\(tenantid,/, "defp evaluate_alert_conditions(__tenant_id,")
    |> String.replace(~r/defp process_triggered_alerts\(alertevaluations\)/, "defp process_triggered_alerts(alert_evaluations)")
    |> String.replace(~r/defp enrich_triggered_alert\(alertevaluation\)/, "defp enrich_triggered_alert(alert_evaluation)")
  end

  defp fix_authentication_variables(content) do
    content
    # Fix mfatoken → mfa_token
    |> String.replace(~r/defp check_mfa_if_enabled\(__user, mfatoken\)/, "defp check_mfa_if_enabled(__user, mfa_token)")
    # Fix sessionid → session_id
    |> String.replace(~r/def revoke_session\(sessionid, __user_id\)/, "def revoke_session(session_id, __user_id)")
  end
end

# Execute the final undefined variable elimination
FinalUndefinedVariableEliminator.run()
