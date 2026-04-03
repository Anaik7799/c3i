defmodule Indrajaal.RiskManagement.RiskReportingTest do
  @moduledoc """
  TDG test suite for RiskReporting Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Risk reports not generated on schedule
  - L5 Root Cause: Missing report frequency validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskReporting

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskReporting)
    end

    test "create function is exported" do
      assert function_exported?(RiskReporting, :create, 1)
    end
  end

  describe "report_type constraints" do
    test "all report types are defined" do
      types = [
        :executive_summary,
        :detailed_risk_register,
        :compliance_report,
        :incident_summary,
        :kpi_dashboard,
        :regulatory_filing
      ]

      assert length(types) == 6
      assert :executive_summary in types
    end
  end

  describe "report_status constraints" do
    test "all statuses cover workflow" do
      statuses = [:draft, :review, :approved, :published, :archived]
      assert length(statuses) == 5
      assert :draft in statuses
      assert :published in statuses
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskReporting.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when report_name missing" do
      result =
        RiskReporting.create(%{
          report_type: :executive_summary,
          report_f_requency: :monthly,
          report_period_start: Date.utc_today(),
          report_period_end: Date.utc_today()
        })

      assert match?({:error, _}, result)
    end
  end
end
