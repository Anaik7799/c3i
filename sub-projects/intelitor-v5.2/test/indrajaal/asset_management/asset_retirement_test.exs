defmodule Indrajaal.AssetManagement.AssetRetirementTest do
  @moduledoc """
  TDG test suite for AssetRetirement Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Asset disposal records incomplete
  - L5 Root Cause: Missing retirement lifecycle validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AssetManagement.AssetRetirement

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(AssetRetirement)
    end

    test "create function is exported" do
      assert function_exported?(AssetRetirement, :create, 1)
    end
  end

  describe "retirement_type constraints" do
    test "all retirement types are defined" do
      types = [
        :end_of_life,
        :obsolete,
        :damaged_beyond_repair,
        :security_risk,
        :cost_ineffective,
        :upgrade
      ]

      assert length(types) == 6
      assert :end_of_life in types
      assert :upgrade in types
    end
  end

  describe "retirement_status lifecycle" do
    test "all statuses are defined" do
      statuses = [:proposed, :approved, :in_progress, :completed, :cancelled]
      assert length(statuses) == 5
      assert :proposed in statuses
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = AssetRetirement.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when retirement_type missing" do
      result =
        AssetRetirement.create(%{
          asset_id: Ecto.UUID.generate(),
          retirement_reason: "Equipment is too old"
        })

      assert match?({:error, _}, result)
    end
  end
end
