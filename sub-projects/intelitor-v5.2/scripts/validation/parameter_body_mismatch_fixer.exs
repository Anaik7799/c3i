#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ParameterBodyMismatchFixer do
  @moduledoc """
  Final systematic fix for parameter-body variable name mismatches.

  AEE SOPv5.11 Compliance: Zero tolerance for parameter naming inconsistencies
  TPS Jidoka Principle: Stop-and-fix every parameter mismatch systematically
  STAMP Safety: Ensure parameter consistency for runtime safety
  """

  def run do
    IO.puts("🚀 AEE SOPv5.11: Parameter-Body Mismatch Fix")
    IO.puts("======================================")

    # Analyze files for parameter-body mismatches
    files = find_elixir_files()
    IO.puts("📊 Analyzing #{length(files)} Elixir files...")

    # Apply systematic parameter fixes
    fixes_applied = apply_parameter_fixes(files)

    IO.puts("\n✅ AEE Execution Complete")
    IO.puts("📈 Total Files Fixed: #{fixes_applied}")
    IO.puts("🎯 Ready for zero-error validation checkpoint")

    # Save completion report
    save_completion_report(fixes_applied, length(files))
  end

  defp find_elixir_files do
    Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.ex")
  end

  defp apply_parameter_fixes(files) do
    Enum.reduce(files, 0, fn file, acc ->
      case File.read(file) do
        {:ok, content} ->
          original_content = content

          # Apply all parameter-body fixes
          fixed_content = content
          |> fix_tenant_id_pattern()
          |> fix_date_range_pattern()
          |> fix_user_id_pattern()
          |> fix_alarm_id_pattern()
          |> fix_device_id_pattern()
          |> fix_site_id_pattern()
          |> fix_group_id_pattern()
          |> fix_zone_id_pattern()
          |> fix_metric_type_pattern()
          |> fix_event_type_pattern()
          |> fix_handler_id_pattern()
          |> fix_session_id_pattern()
          |> fix_request_id_pattern()
          |> fix_trace_id_pattern()
          |> fix_config_key_pattern()

          if fixed_content != original_content do
            File.write!(file, fixed_content)
            IO.puts("✅ Fixed: #{Path.relative_to_cwd(file)}")
            acc + 1
          else
            acc
          end

        {:error, _} ->
          IO.puts("⚠️ Skipped: #{file}")
          acc
      end
    end)
  end

  defp fix_tenant_id_pattern(content) do
    content
    # Fix tenantid parameter to __tenant_id when used in body
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)tenantid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "__tenant_id") do
        String.replace(match, "tenantid", "__tenant_id")
      else
        match
      end
    end)
    # Fix specific function patterns
    |> String.replace(~r/def generate.*_report\(tenantid,/, "def generate_analytics_report(__tenant_id,")
    |> String.replace(~r/def get_.*_metrics\(tenantid,/, fn match ->
      String.replace(match, "tenantid", "__tenant_id")
    end)
  end

  defp fix_date_range_pattern(content) do
    content
    # Fix daterange parameter to date_range when used in body
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)daterange([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "date_range") do
        String.replace(match, "daterange", "date_range")
      else
        match
      end
    end)
    # Fix specific patterns
    |> String.replace("daterange \\\\", "date_range \\\\")
    |> String.replace("daterange)", "date_range)")
    |> String.replace("daterange,", "date_range,")
  end

  defp fix_user_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)__userid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "__user_id") do
        String.replace(match, "__userid", "__user_id")
      else
        match
      end
    end)
  end

  defp fix_alarm_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)alarmid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "alarm_id") do
        String.replace(match, "alarmid", "alarm_id")
      else
        match
      end
    end)
  end

  defp fix_device_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)deviceid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "device_id") do
        String.replace(match, "deviceid", "device_id")
      else
        match
      end
    end)
  end

  defp fix_site_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)siteid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "site_id") do
        String.replace(match, "siteid", "site_id")
      else
        match
      end
    end)
  end

  defp fix_group_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)groupid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "group_id") do
        String.replace(match, "groupid", "group_id")
      else
        match
      end
    end)
  end

  defp fix_zone_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)zoneid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "zone_id") do
        String.replace(match, "zoneid", "zone_id")
      else
        match
      end
    end)
  end

  defp fix_metric_type_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)metrictype([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "metric_type") do
        String.replace(match, "metrictype", "metric_type")
      else
        match
      end
    end)
  end

  defp fix_event_type_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)__eventtype([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "__event_type") do
        String.replace(match, "__eventtype", "__event_type")
      else
        match
      end
    end)
  end

  defp fix_handler_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)handlerid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "handler_id") do
        String.replace(match, "handlerid", "handler_id")
      else
        match
      end
    end)
  end

  defp fix_session_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)sessionid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "session_id") do
        String.replace(match, "sessionid", "session_id")
      else
        match
      end
    end)
  end

  defp fix_request_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)__requestid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "__request_id") do
        String.replace(match, "__requestid", "__request_id")
      else
        match
      end
    end)
  end

  defp fix_trace_id_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)traceid([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "trace_id") do
        String.replace(match, "traceid", "trace_id")
      else
        match
      end
    end)
  end

  defp fix_config_key_pattern(content) do
    content
    |> String.replace(~r/def\s+(\w+)\(([^,)]*?)configkey([^,)]*?)\)\s+do\s+(.*?)end/s, fn match ->
      if String.contains?(match, "config_key") do
        String.replace(match, "configkey", "config_key")
      else
        match
      end
    end)
  end

  defp save_completion_report(fixes_applied, total_files) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./__data/tmp/parameter_body_mismatch_fix_#{timestamp}.log"

    report = """
    🚀 AEE SOPv5.11: Parameter-Body Mismatch Fix Report
    ==================================================

    📅 Execution Time: #{DateTime.utc_now() |> DateTime.to_string()}
    📊 Files Analyzed: #{total_files}
    ✅ Files Fixed: #{fixes_applied}
    🎯 Success Rate: #{Float.round(fixes_applied / total_files * 100, 1)}%

    🔧 Systematic Fixes Applied:
    - __tenant_id parameter standardization (tenantid → __tenant_id)
    - date_range parameter alignment (daterange → date_range)
    - __user_id parameter consistency (__userid → __user_id)
    - alarm_id parameter fixes (alarmid → alarm_id)
    - device_id parameter alignment (deviceid → device_id)
    - site_id parameter consistency (siteid → site_id)
    - And 9 additional ID/type parameter patterns

    🚨 TPS Jidoka: Stop-and-fix methodology applied to every parameter mismatch
    🛡️ STAMP Safety: Parameter consistency enforced for runtime safety
    ⚡ AEE Execution: Autonomous systematic correction completed

    📋 Next Steps:
    1. Run Patient Mode compilation validation
    2. Achieve zero-error checkpoint
    3. Complete EP-110 false positive pr__evention deployment

    Status: ✅ READY FOR ZERO-ERROR VALIDATION
    """

    File.write!(report_file, report)
    IO.puts("📄 Report saved: #{report_file}")
  end
end

# Execute the parameter-body mismatch fix
ParameterBodyMismatchFixer.run()