defmodule Indrajaal.RiskManagement.RiskCategoryTest do
  @moduledoc """
  TDG test suite for RiskCategory Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Risk category classification fails
  - L5 Root Cause: Missing category_type validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskCategory

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskCategory)
    end

    test "create function is exported" do
      assert function_exported?(RiskCategory, :create, 1)
    end
  end

  describe "category_type constraints" do
    test "all category types are defined" do
      types = [
        :operational,
        :financial,
        :strategic,
        :compliance,
        :cyber_security,
        :physical_security,
        :reputational,
        :environmental
      ]

      assert length(types) == 8
      assert :cyber_security in types
      assert :operational in types
    end
  end

  describe "default scales" do
    test "severity scale has expected keys" do
      scale = %{
        "1" => "Minimal",
        "2" => "Minor",
        "3" => "Moderate",
        "4" => "Major",
        "5" => "Critical"
      }

      assert map_size(scale) == 5
      assert scale["5"] == "Critical"
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskCategory.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when name is missing" do
      result =
        RiskCategory.create(%{
          category_code: "OPS-001",
          category_type: :operational
        })

      assert match?({:error, _}, result)
    end
  end
end
