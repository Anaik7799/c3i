defmodule Indrajaal.AnalyticsContext do
  @moduledoc """
  Context module for Analytics operations using Ash actions.

  Provides __context functions for controllers while maintaining
  the Analytics Ash domain structure.
  """

  alias Indrajaal.Analytics.Report

  @doc """
  Lists analytics with pagination and filtering.
  """
  def list_reports(opts \\ []) do
    case Ash.read(Report, opts) do
      {:ok, reports} -> reports
      {:error, _} -> []
    end
  end

  @doc """
  Gets a single report by ID.
  """
  def get_report(id, opts \\ []) do
    Ash.get(Report, id, opts)
  end

  @doc """
  Creates a new report.
  """
  def create_report(attrs \\ %{}) do
    Report
    |> Ash.Changeset.for_create(:create_report, attrs)
    |> Ash.create()
  end

  @doc """
  Updates a report.
  """
  def update_report(%Report{} = report, attrs) do
    report
    |> Ash.Changeset.for_update(:update_report, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes a report.
  """
  def delete_report(%Report{} = report) do
    Ash.destroy(report)
  end

  @doc """
  Bulk creates multiple analytics reports.
  """
  def bulk_create_analytics(analytics_list) when is_list(analytics_list) do
    results =
      Enum.map(analytics_list, fn attrs ->
        case create_report(attrs) do
          {:ok, report} -> report
          {:error, _} = error -> error
        end
      end)

    {successes, errors} =
      Enum.split_with(results, fn
        {:error, _} -> false
        _ -> true
      end)

    if Enum.empty?(errors) do
      {:ok, successes}
    else
      {:error, "Bulk creation failed with #{length(errors)} errors"}
    end
  end

  @doc """
  Imports analytics from external __data source.
  """
  def import_analytics(data) when is_map(data) do
    analytics_data = Map.get(data, "analytics", [])

    case bulk_create_analytics(analytics_data) do
      {:ok, created_analytics} ->
        {:ok, %{imported: length(created_analytics), failed: 0}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Exports analytics to external format.
  """
  def export_analytics(params) when is_map(params) do
    tenant_id = Map.get(params, "tenant_id")
    analytics = list_reports(tenant_id: tenant_id)

    export_data = %{
      "analytics" => analytics,
      "exported_at" => DateTime.utc_now(),
      "count" => length(analytics)
    }

    {:ok, export_data}
  end
end
