#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveAnalyticsVariableFixer do
  @moduledoc """
  Comprehensive fix for all remaining undefined variable errors in analytics files.

  AEE SOPv5.11 Compliance: Systematic resolution of all analytics parameter mismatches
  TPS Jidoka Principle: Complete stop-and-fix for zero-error validation checkpoint
  """

  def run do
    IO.puts("🚀 AEE SOPv5.11: Comprehensive Analytics Variable Fixing")
    IO.puts("===================================================")

    files = [
      "lib/indrajaal/analytics/bi_data_warehouse.ex",
      "lib/indrajaal/analytics/multi_dimensional_reporting_system.ex"
    ]

    Enum.each(files, &fix_file/1)

    IO.puts("✅ AEE Comprehensive Analytics Variable Fixing Complete")
  end

  defp fix_file(file_path) do
    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          original_content = content

          fixed_content = content
          |> fix_bi_data_warehouse_variables()
          |> fix_multi_dimensional_variables()

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

  defp fix_bi_data_warehouse_variables(content) do
    content
    # Fix all tenantid → __tenant_id parameter names
    |> String.replace(~r/def run_etl_pipeline\(tenantid,/, "def run_etl_pipeline(__tenant_id,")
    |> String.replace(~r/def manage_data_quality\(tenantid,/, "def manage_data_quality(__tenant_id,")
    |> String.replace(~r/def manage_data_retention\(tenantid,/, "def manage_data_retention(__tenant_id,")
    |> String.replace(~r/defp extract_source_data\(tenantid,/, "defp extract_source_data(__tenant_id,")
    
    # Fix underscore parameter names for used variables
    |> String.replace(~r/defp create_single_hypertable\(hypertableconfig\)/, "defp create_single_hypertable(hypertable_config)")
    |> String.replace(~r/defp create_single_dimension_table\(dimensionconfig\)/, "defp create_single_dimension_table(dimension_config)")
    |> String.replace(~r/defp transform_data\(extractionresults,/, "defp transform_data(extraction_results,")
    |> String.replace(~r/defp load_data_to_warehouse\(transformed__data,/, "defp load_data_to_warehouse(transformed_data,")
    |> String.replace(~r/defp setup_compression\(hypertableconfig\)/, "defp setup_compression(hypertable_config)")
    |> String.replace(~r/defp setup_retention_policy\(hypertableconfig\)/, "defp setup_retention_policy(hypertable_config)")
    |> String.replace(~r/defp generate_dimension_attributes\(tablename\)/, "defp generate_dimension_attributes(table_name)")
  end

  defp fix_multi_dimensional_variables(content) do
    content
    # Fix all tenantid → __tenant_id parameter names
    |> String.replace(~r/def create_olap_data_cube\(tenantid,/, "def create_olap_data_cube(__tenant_id,")
    |> String.replace(~r/def setup_automated_reporting\(tenantid,/, "def setup_automated_reporting(__tenant_id,")
    |> String.replace(~r/def createstreaming_report\(tenantid, streamingconfig\)/, "def createstreaming_report(__tenant_id, streaming_config)")
    |> String.replace(~r/def perform_drill_analysis\(tenantid,/, "def perform_drill_analysis(__tenant_id,")
    
    # Fix underscore parameter names for used variables
    |> String.replace(~r/defp analyze_cross_domain_correlations\(domain__data\)/, "defp analyze_cross_domain_correlations(domain_data)")
    |> String.replace(~r/defp perform_dimensional_analysis\(domain__data,/, "defp perform_dimensional_analysis(domain_data,")
    |> String.replace(~r/defp generate_report_content\(dimensionalanalysis,/, "defp generate_report_content(dimensional_analysis,")
    |> String.replace(~r/defp get_domain_metric\(domain__data,/, "defp get_domain_metric(domain_data,")
    
    # Fix specific issues with streaming_config usage
    |> String.replace(~r/__datasources = Map\.get\(streaming_config,/, "__data_sources = Map.get(streaming_config,")
    |> String.replace(~r/^\s*__datasources = /, "    __data_sources = ")
  end
end

# Execute the comprehensive analytics variable fixing
ComprehensiveAnalyticsVariableFixer.run()
