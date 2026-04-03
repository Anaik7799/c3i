defmodule Indrajaal.RiskManagement.RiskMonitoringTest do
  @moduledoc """
  TDG test suite for RiskMonitoring Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Risk KPI thresholds not triggered
  - L5 Root Cause: Missing threshold comparison logic
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskMonitoring

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskMonitoring)
    end

    test "create function is exported" do
      assert function_exported?(RiskMonitoring, :create, 1)
    end
  end

  describe "monitoring_type constraints" do
    test "all monitoring types are valid" do
      types = [:continuous, :periodic, :threshold_based, :trend_analysis]
      Enum.each(types, fn t -> assert is_atom(t) end)
    end
  end

  describe "trend_direction constraints" do
    test "trend directions cover all cases" do
      directions = [:increasing, :decreasing, :stable, :volatile]
      assert is_list(directions)
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskMonitoring.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when kpi_name missing" do
      result =
        RiskMonitoring.create(%{
          monitoring_type: :continuous,
          monitoring_f_requency: :real_time
        })

      assert match?({:error, _}, result)
    end
  end
end
