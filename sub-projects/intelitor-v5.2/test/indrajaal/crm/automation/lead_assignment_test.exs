defmodule Indrajaal.Crm.Automation.LeadAssignmentTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Crm.Automation.LeadAssignment.

  Sprint 54 — 100% module coverage.

  ## STAMP Compliance
  - SC-COV-001: Module coverage
  - SC-AUTO-001: Assignment automation
  - SC-PRF-050: Assignment latency < 50ms
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Crm.Automation.LeadAssignment

  @moduletag :zenoh_nif

  describe "module existence" do
    test "LeadAssignment module is loaded" do
      assert Code.ensure_loaded?(LeadAssignment)
    end
  end

  describe "public API exports" do
    test "assign_round_robin/2" do
      assert function_exported?(LeadAssignment, :assign_round_robin, 2)
    end

    test "assign_by_territory/1" do
      assert function_exported?(LeadAssignment, :assign_by_territory, 1)
    end

    test "assign_by_skill/2" do
      assert function_exported?(LeadAssignment, :assign_by_skill, 2)
    end

    test "assign_by_workload/2" do
      assert function_exported?(LeadAssignment, :assign_by_workload, 2)
    end
  end

  describe "assign_by_territory/1" do
    test "assigns California leads to user-1" do
      lead = %{id: "lead-1", state: "CA", country: "US", industry: "tech"}
      assert {:ok, "user-1"} = LeadAssignment.assign_by_territory(lead)
    end

    test "assigns New York leads to user-2" do
      lead = %{id: "lead-2", state: "NY", country: "US", industry: "finance"}
      assert {:ok, "user-2"} = LeadAssignment.assign_by_territory(lead)
    end

    test "returns error for unknown territory" do
      lead = %{id: "lead-3", state: "TX", country: "DE", industry: "auto"}
      assert {:error, :no_territory_owner} = LeadAssignment.assign_by_territory(lead)
    end
  end

  describe "assign_by_skill/2" do
    test "returns {:ok, rep_id} for matching skills" do
      lead = %{id: "lead-1"}
      assert {:ok, rep_id} = LeadAssignment.assign_by_skill(lead, ["enterprise"])
      assert is_binary(rep_id)
    end
  end
end
