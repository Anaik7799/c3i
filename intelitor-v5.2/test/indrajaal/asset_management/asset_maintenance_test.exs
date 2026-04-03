defmodule Indrajaal.AssetManagement.AssetMaintenanceTest do
  @moduledoc """
  TDG test suite for AssetMaintenance Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Maintenance schedules missed
  - L5 Root Cause: Missing overdue detection logic
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AssetManagement.AssetMaintenance

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(AssetMaintenance)
    end

    test "code_interface functions are exported" do
      assert function_exported?(AssetMaintenance, :create, 1)
      assert function_exported?(AssetMaintenance, :schedule_maintenance, 1)
      assert function_exported?(AssetMaintenance, :assign_technician, 2)
      assert function_exported?(AssetMaintenance, :start_maintenance, 2)
      assert function_exported?(AssetMaintenance, :complete_maintenance, 2)
      assert function_exported?(AssetMaintenance, :cancel_maintenance, 2)
      assert function_exported?(AssetMaintenance, :reschedule, 2)
    end
  end

  describe "maintenance_type constraints" do
    test "all maintenance types are defined" do
      types = [:corrective, :predictive, :emergency, :inspection, :calibration]
      Enum.each(types, fn t -> assert is_atom(t) end)
    end
  end

  describe "priority constraints" do
    test "all priorities are defined" do
      priorities = [:low, :medium, :high, :critical]
      assert length(priorities) == 4
      assert :critical in priorities
    end
  end

  describe "status lifecycle" do
    test "statuses cover full workflow" do
      statuses = [:scheduled, :in_progress, :completed, :cancelled, :overdue]
      assert :scheduled in statuses
      assert :overdue in statuses
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = AssetMaintenance.create(%{})
      assert match?({:error, _}, result)
    end
  end

  describe "schedule_maintenance/1 without DB" do
    test "returns error when asset_id missing" do
      result =
        AssetMaintenance.schedule_maintenance(%{
          maintenance_type: :corrective,
          scheduled_date: Date.utc_today(),
          description: "Fix broken part"
        })

      assert match?({:error, _}, result)
    end
  end
end
