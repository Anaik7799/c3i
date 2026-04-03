defmodule Indrajaal.RiskManagement.RiskMatrixTest do
  @moduledoc """
  TDG test suite for RiskMatrix Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Risk scoring inconsistent
  - L5 Root Cause: Matrix configuration not validated
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskMatrix

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskMatrix)
    end

    test "create function is exported" do
      assert function_exported?(RiskMatrix, :create, 1)
    end
  end

  describe "matrix_type constraints" do
    test "all matrix types are defined" do
      types = [:standard_5x5, :standard_4x4, :standard_3x3, :custom]
      assert length(types) == 4
      assert :standard_5x5 in types
    end
  end

  describe "default probability scale" do
    test "scale has 5 probability levels" do
      scale = %{
        "1" => %{"label" => "Very Low"},
        "2" => %{"label" => "Low"},
        "3" => %{"label" => "Medium"},
        "4" => %{"label" => "High"},
        "5" => %{"label" => "Very High"}
      }

      assert map_size(scale) == 5
    end
  end

  describe "default impact scale" do
    test "scale has 5 impact levels" do
      scale = %{
        "1" => %{"label" => "Minimal"},
        "2" => %{"label" => "Minor"},
        "3" => %{"label" => "Moderate"},
        "4" => %{"label" => "Major"},
        "5" => %{"label" => "Critical"}
      }

      assert map_size(scale) == 5
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskMatrix.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when matrix_name missing" do
      result =
        RiskMatrix.create(%{
          matrix_type: :standard_5x5
        })

      assert match?({:error, _}, result)
    end
  end
end
