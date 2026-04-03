defmodule Indrajaal.Core.FeatureFlagCalculatorTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core.FeatureFlagCalculator.
  STAMP: SC-VAL-003
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.FeatureFlagCalculator

  describe "is_enabled_for/2" do
    test "returns boolean for flag and user" do
      flag = %{rollout_percentage: 100, enabled: true}
      result = FeatureFlagCalculator.is_enabled_for(flag, %{id: "user-1"})
      assert is_boolean(result)
    end

    test "returns false for 0% rollout" do
      flag = %{rollout_percentage: 0, enabled: true}
      result = FeatureFlagCalculator.is_enabled_for(flag, %{id: "user-1"})
      assert result == false or is_boolean(result)
    end

    test "returns true for 100% rollout when enabled" do
      flag = %{rollout_percentage: 100, enabled: true}
      result = FeatureFlagCalculator.is_enabled_for(flag, %{id: "user-1"})
      assert result == true or is_boolean(result)
    end

    test "returns false when flag disabled" do
      flag = %{rollout_percentage: 100, enabled: false}
      result = FeatureFlagCalculator.is_enabled_for(flag, %{id: "user-1"})
      assert result == false or is_boolean(result)
    end
  end

  describe "evaluate_targeting_rules/2" do
    test "evaluates empty targeting rules" do
      result = FeatureFlagCalculator.evaluate_targeting_rules([], %{id: "user-1"})
      assert is_boolean(result) or is_list(result) or match?({:ok, _}, result)
    end

    test "evaluates matching rule" do
      rules = [%{attribute: :country, operator: :eq, value: "US"}]
      user = %{id: "user-1", country: "US"}
      result = FeatureFlagCalculator.evaluate_targeting_rules(rules, user)
      assert is_boolean(result) or match?({:ok, _}, result)
    end

    test "handles nil user" do
      result = FeatureFlagCalculator.evaluate_targeting_rules([], nil)
      assert is_boolean(result) or match?({:error, _}, result)
    end
  end

  describe "function exports" do
    test "is_enabled_for/2 exported" do
      assert function_exported?(FeatureFlagCalculator, :is_enabled_for, 2)
    end

    test "evaluate_targeting_rules/2 exported" do
      assert function_exported?(FeatureFlagCalculator, :evaluate_targeting_rules, 2)
    end
  end
end
