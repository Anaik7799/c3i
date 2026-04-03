defmodule Indrajaal.Cybernetic.OODA.DeciderTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.OODA.Decider.

  Decider is a stub module with a single public function make_decision/1 that
  always returns %{action: :none, confidence: 1.0, reason: "System nominal"}.
  Tests cover the contract and idempotency expectations.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cybernetic.OODA.Decider

  describe "make_decision/1 — return shape" do
    test "returns a map" do
      assert is_map(Decider.make_decision(%{}))
    end

    test "returned map has :action key" do
      assert Map.has_key?(Decider.make_decision(%{}), :action)
    end

    test "returned map has :confidence key" do
      assert Map.has_key?(Decider.make_decision(%{}), :confidence)
    end

    test "returned map has :reason key" do
      assert Map.has_key?(Decider.make_decision(%{}), :reason)
    end

    test "returned map has exactly three keys" do
      result = Decider.make_decision(%{})
      assert map_size(result) == 3
    end
  end

  describe "make_decision/1 — :action field" do
    test "action is :none for empty strategy" do
      assert Decider.make_decision(%{}).action == :none
    end

    test "action is :none for a nominal strategy" do
      strategy = %{status: :normal, threats: [], opportunities: []}
      assert Decider.make_decision(strategy).action == :none
    end

    test "action is :none for nil strategy" do
      assert Decider.make_decision(nil).action == :none
    end

    test "action is :none regardless of strategy content" do
      for strategy <- [%{}, %{foo: :bar}, %{status: :critical}, []] do
        assert Decider.make_decision(strategy).action == :none,
               "Expected :none for strategy #{inspect(strategy)}"
      end
    end
  end

  describe "make_decision/1 — :confidence field" do
    test "confidence is 1.0" do
      assert Decider.make_decision(%{}).confidence == 1.0
    end

    test "confidence is a float" do
      assert is_float(Decider.make_decision(%{}).confidence)
    end

    test "confidence is between 0.0 and 1.0 inclusive" do
      c = Decider.make_decision(%{}).confidence
      assert c >= 0.0 and c <= 1.0
    end
  end

  describe "make_decision/1 — :reason field" do
    test "reason is a binary string" do
      assert is_binary(Decider.make_decision(%{}).reason)
    end

    test "reason is non-empty" do
      assert byte_size(Decider.make_decision(%{}).reason) > 0
    end

    test "reason is 'System nominal'" do
      assert Decider.make_decision(%{}).reason == "System nominal"
    end
  end

  describe "make_decision/1 — idempotency" do
    test "calling twice with same input returns same result" do
      strategy = %{status: :normal}
      assert Decider.make_decision(strategy) == Decider.make_decision(strategy)
    end

    test "calling with different inputs returns same result (stub)" do
      r1 = Decider.make_decision(%{})
      r2 = Decider.make_decision(%{status: :critical, threats: [:high_cpu]})
      assert r1 == r2
    end
  end
end
