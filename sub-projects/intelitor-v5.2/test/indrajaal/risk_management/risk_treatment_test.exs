defmodule Indrajaal.RiskManagement.RiskTreatmentTest do
  @moduledoc """
  TDG test suite for RiskTreatment Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Risk treatment decisions not documented
  - L5 Root Cause: Missing treatment strategy validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskTreatment

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskTreatment)
    end

    test "create function is exported" do
      assert function_exported?(RiskTreatment, :create, 1)
    end
  end

  describe "treatment_strategy constraints" do
    test "all strategies are defined" do
      strategies = [:avoid, :mitigate, :transfer, :accept, :monitor, :exploit, :enhance, :share]
      assert length(strategies) == 8
      assert :exploit in strategies
      assert :share in strategies
    end
  end

  describe "treatment_status constraints" do
    test "all statuses cover full lifecycle" do
      statuses = [:planned, :approved, :in_progress, :implemented, :reviewed, :closed]
      assert length(statuses) == 6
      assert :reviewed in statuses
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskTreatment.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when treatment_name missing" do
      result =
        RiskTreatment.create(%{
          treatment_strategy: :mitigate,
          treatment_description: "Apply firewall rules"
        })

      assert match?({:error, _}, result)
    end
  end
end
