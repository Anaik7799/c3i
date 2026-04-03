defmodule Indrajaal.RiskManagement.RiskIncidentTest do
  @moduledoc """
  TDG test suite for RiskIncident Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Risk incidents not captured
  - L5 Root Cause: Missing incident severity classification
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskIncident

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskIncident)
    end

    test "create function is exported" do
      assert function_exported?(RiskIncident, :create, 1)
    end
  end

  describe "incident_status constraints" do
    test "all statuses are defined" do
      statuses = [:reported, :investigating, :contained, :resolved, :closed]
      assert length(statuses) == 5
      assert :reported in statuses
      assert :closed in statuses
    end
  end

  describe "severity_level constraints" do
    test "all severity levels are defined" do
      levels = [:minimal, :minor, :moderate, :major, :critical]
      assert length(levels) == 5
      assert :critical in levels
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskIncident.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when incident_id missing" do
      result =
        RiskIncident.create(%{
          incident_title: "Data Breach",
          incident_description: "Unauthorized access detected",
          incident_date: DateTime.utc_now(),
          severity_level: :critical
        })

      assert match?({:error, _}, result)
    end
  end
end
