#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComplianceReporterComprehensiveFixer do
  @moduledoc """
  Comprehensive fix for compliance_reporter.ex undefined variable errors.

  AEE SOPv5.11 Compliance: Systematic parameter-body variable mismatch resolution
  TPS Jidoka Principle: Stop-and-fix approach to eliminate all undefined variables
  """

  def run do
    IO.puts("🚀 AEE SOPv5.11: Compliance Reporter Comprehensive Fix")
    IO.puts("=====================================================")

    file_path = "lib/indrajaal/access_control/compliance_reporter.ex"

    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          original_content = content

          # Apply comprehensive parameter-body fixes
          fixed_content = content
          |> fix_tenant_id_parameters()
          |> fix_time_range_parameters()
          |> fix_report_data_parameters()
          |> fix_compliance_data_parameters()
          |> fix_framework_config_parameters()

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

    IO.puts("✅ AEE Execution Complete")
  end

  defp fix_tenant_id_parameters(content) do
    content
    # Fix tenantid parameter in function definitions
    |> String.replace(~r/def get_compliance_score\(tenantid,/, "def get_compliance_score(__tenant_id,")
    |> String.replace(~r/def analyzeviolations\(tenantid,/, "def analyzeviolations(__tenant_id,")
    |> String.replace(~r/def schedule_automated_reports\(tenantid,/, "def schedule_automated_reports(__tenant_id,")
    |> String.replace(~r/defp collect_compliance_data\(tenantid,/, "defp collect_compliance_data(__tenant_id,")
    |> String.replace(~r/defp log_report_generation\(tenantid,/, "defp log_report_generation(__tenant_id,")
  end

  defp fix_time_range_parameters(content) do
    content
    # Fix timerange parameter
    |> String.replace(~r/def analyzeviolations\(__tenant_id, timerange/, "def analyzeviolations(__tenant_id, time_range")
  end

  defp fix_report_data_parameters(content) do
    content
    # Fix report__data parameter in function definitions
    |> String.replace(~r/def validate_report_data\(report__data,/, "def validate_report_data(report_data,")
    |> String.replace(~r/defp validate_required_data_elements\(report__data,/, "defp validate_required_data_elements(report_data,")
  end

  defp fix_compliance_data_parameters(content) do
    content
    # Fix compliance__data parameter
    |> String.replace(~r/defp analyze_compliance_data\(compliance__data,/, "defp analyze_compliance_data(compliance_data,")
  end

  defp fix_framework_config_parameters(content) do
    content
    # Fix frameworkconfig parameter
    |> String.replace(~r/defp validate_report_period\(__opts, frameworkconfig\)/, "defp validate_report_period(__opts, framework_config)")
  end
end

# Execute the comprehensive fix
ComplianceReporterComprehensiveFixer.run()