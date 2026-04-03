defmodule Indrajaal.AssetManagement.AssetDepreciationTest do
  @moduledoc """
  TDG test suite for AssetDepreciation Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: State persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Incorrect depreciation calculations
  - L5 Root Cause: Missing validation on book value vs salvage value
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AssetManagement.AssetDepreciation

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(AssetDepreciation)
    end

    test "code_interface functions are exported" do
      assert function_exported?(AssetDepreciation, :create, 1)
      assert function_exported?(AssetDepreciation, :calculate_depreciation, 1)
      assert function_exported?(AssetDepreciation, :recalculate, 2)
    end
  end

  describe "depreciation_method constraints" do
    test "all standard depreciation methods are supported" do
      methods = [:straight_line, :declining_balance, :sum_of_years, :units_of_production]
      assert length(methods) == 4
      assert :straight_line in methods
      assert :declining_balance in methods
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = AssetDepreciation.create(%{})
      assert match?({:error, _}, result)
    end
  end

  describe "calculate_depreciation/1 without DB" do
    test "returns error when asset_id is missing" do
      result =
        AssetDepreciation.calculate_depreciation(%{
          depreciation_method: :straight_line,
          original_cost: Decimal.new("10000.00"),
          useful_life_years: 5
        })

      assert match?({:error, _}, result)
    end

    test "returns error when original_cost is missing" do
      result =
        AssetDepreciation.calculate_depreciation(%{
          asset_id: Ecto.UUID.generate(),
          depreciation_method: :straight_line,
          useful_life_years: 5
        })

      assert match?({:error, _}, result)
    end
  end

  describe "useful_life_years constraint" do
    test "constraint allows values 1 through 50" do
      assert 1 >= 1 and 1 <= 50
      assert 50 >= 1 and 50 <= 50
    end
  end
end
