defmodule Indrajaal.Cybernetic.OODA.OrientatorTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.OODA.Orientator.

  Orientator is a stub module with a single public function analyze/1 that
  always returns %{status: :normal, threats: [], opportunities: []}.
  Tests cover the contract and idempotency expectations.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cybernetic.OODA.Orientator

  describe "analyze/1 — return shape" do
    test "returns a map" do
      assert is_map(Orientator.analyze(%{}))
    end

    test "returned map has :status key" do
      assert Map.has_key?(Orientator.analyze(%{}), :status)
    end

    test "returned map has :threats key" do
      assert Map.has_key?(Orientator.analyze(%{}), :threats)
    end

    test "returned map has :opportunities key" do
      assert Map.has_key?(Orientator.analyze(%{}), :opportunities)
    end

    test "returned map has exactly three keys" do
      result = Orientator.analyze(%{})
      assert map_size(result) == 3
    end
  end

  describe "analyze/1 — :status field" do
    test "status is :normal for empty observation" do
      assert Orientator.analyze(%{}).status == :normal
    end

    test "status is :normal for richly populated observation" do
      obs = %{cpu: 95, memory: 90, latency: 500, errors: 50}
      assert Orientator.analyze(obs).status == :normal
    end

    test "status is an atom" do
      assert is_atom(Orientator.analyze(%{}).status)
    end

    test "status is :normal for nil observation" do
      assert Orientator.analyze(nil).status == :normal
    end
  end

  describe "analyze/1 — :threats field" do
    test "threats is an empty list" do
      assert Orientator.analyze(%{}).threats == []
    end

    test "threats is a list" do
      assert is_list(Orientator.analyze(%{}).threats)
    end

    test "threats has no elements regardless of observation" do
      obs = %{cpu: 99, memory: 99}
      assert length(Orientator.analyze(obs).threats) == 0
    end
  end

  describe "analyze/1 — :opportunities field" do
    test "opportunities is an empty list" do
      assert Orientator.analyze(%{}).opportunities == []
    end

    test "opportunities is a list" do
      assert is_list(Orientator.analyze(%{}).opportunities)
    end

    test "opportunities has no elements regardless of observation" do
      obs = %{status: :excellent}
      assert length(Orientator.analyze(obs).opportunities) == 0
    end
  end

  describe "analyze/1 — idempotency" do
    test "same observation always yields the same result" do
      obs = %{cpu: 50, memory: 60}
      assert Orientator.analyze(obs) == Orientator.analyze(obs)
    end

    test "different observations yield the same result (stub behaviour)" do
      r1 = Orientator.analyze(%{})
      r2 = Orientator.analyze(%{cpu: 99, memory: 99, latency: 1000})
      assert r1 == r2
    end
  end
end
