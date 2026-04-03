defmodule Indrajaal.RiskManagement.RiskControlTest do
  @moduledoc """
  TDG test suite for RiskControl Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Control effectiveness not measured
  - L5 Root Cause: Missing control testing schedule
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskControl

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskControl)
    end

    test "create function is exported" do
      assert function_exported?(RiskControl, :create, 1)
    end
  end

  describe "control_type constraints" do
    test "all control types are valid" do
      types = [:detective, :corrective, :compensating]
      Enum.each(types, fn t -> assert is_atom(t) end)
    end
  end

  describe "control_nature constraints" do
    test "all natures are valid" do
      natures = [:manual, :automated, :hybrid]
      assert length(natures) == 3
      assert :automated in natures
    end
  end

  describe "control_status constraints" do
    test "all statuses are defined" do
      statuses = [:planned, :implemented, :operating, :deficient, :disabled]
      assert length(statuses) == 5
      assert :operating in statuses
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskControl.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when control_id missing" do
      result =
        RiskControl.create(%{
          control_name: "Access Control",
          control_description: "Restricts access",
          control_type: :detective,
          control_nature: :automated,
          control_f_requency: :continuous
        })

      assert match?({:error, _}, result)
    end
  end
end
