#!/usr/bin/env elixir

defmodule MobileApi.CompilationFixer do
  @moduledoc """
  Fixes compilation warnings in the Mobile API implementation.

  SOPv5.1 Compliance: ✅
  Agent: Helper-1 (Compilation Management)
  Timestamp: 2025-08-03T22:58:00+02:00
  """

  @files_to_fix [
    {"lib/indrajaal/analytics/performance_validation_framework.ex",
      ["BusinessValueMeasurement", "PerformanceMetrics"]},
    {"lib/indrajaal/analytics/business_intelligence.ex", ["DataExport"]},
    {"lib/indrajaal/analytics/stamp_tdg_gde_analytics.ex", ["MetricsCollector"]},
    {"lib/indrajaal/analytics/strategic_impact_dashboard.ex",
    ["BusinessValueMeasurement", "PerformanceValidationFramework"]},
    {"lib/indrajaal/instrumentation/communication_instrumentation.ex", ["measurements"]}
  ]

  @spec fix_all() :: any()
  def fix_all do
    IO.puts("🔧 Fixing compilation warnings...")

    Enum.each(@files_to_fix, fn {file, issues} ->
      fix_file(file, issues)
    end)

    IO.puts("✅ Compilation warnings fixed!")
  end

  @spec fix_file(term(), term()) :: term()
  defp fix_file(file_path, issues) do
    IO.puts("  Fixing #{file_path}...")

    case File.read(file_path) do
      {:ok, content} ->
        _fixed_content = Enum.reduce(issues, _content, fn issue, acc ->
          fix_issue(acc, issue)
        end)

        File.write!(file_path, fixed_content)

      {:error, reason} ->
        IO.puts("    ⚠️  Could not read file: #{reason}")
    end
  end

  @spec fix_issue(term(), String.t()) :: term()
  defp fix_issue(content, "measurements") do
    # Fix unused variable by prefixing with underscore
    String.replace(content, "__event, measurements, metadata", "__event, _measurements, metadata")
  end

  @spec fix_issue(term(), term()) :: term()
  defp fix_issue(content, alias_name) do
    # Comment out unused aliases
    String.replace(content, ~r/^(\s*)alias .+\.#{alias_name}$/m, "\\1# alias remo
  end
end

# Execute
MobileApi.CompilationFixer.fix_all()
