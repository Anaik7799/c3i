defmodule Indrajaal.Cybernetic.OODA.ActorTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.OODA.Actor.

  Covers all four branches of execute/1:
    - :none   → :ok
    - :scale_up → :ok (with optional pool/count)
    - :apoptosis → :ok
    - unknown → :error
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cybernetic.OODA.Actor

  describe "execute/1 — :none action" do
    test "returns :ok for minimal decision" do
      assert Actor.execute(%{action: :none}) == :ok
    end

    test "returns :ok regardless of extra fields" do
      assert Actor.execute(%{action: :none, confidence: 0.99, reason: "all clear"}) == :ok
    end
  end

  describe "execute/1 — :scale_up action" do
    test "returns :ok with explicit pool and count" do
      assert Actor.execute(%{action: :scale_up, pool: SomePool, count: 3}) == :ok
    end

    test "returns :ok when pool key is missing (uses default)" do
      assert Actor.execute(%{action: :scale_up, count: 2}) == :ok
    end

    test "returns :ok when count key is missing (uses default 1)" do
      assert Actor.execute(%{action: :scale_up, pool: SomePool}) == :ok
    end

    test "returns :ok with only the action key" do
      assert Actor.execute(%{action: :scale_up}) == :ok
    end

    test "returns :ok with count 1" do
      assert Actor.execute(%{action: :scale_up, count: 1}) == :ok
    end

    test "returns :ok with large count" do
      assert Actor.execute(%{action: :scale_up, count: 50}) == :ok
    end
  end

  describe "execute/1 — :apoptosis action" do
    test "returns :ok for bare apoptosis decision" do
      assert Actor.execute(%{action: :apoptosis}) == :ok
    end

    test "returns :ok for apoptosis with context fields" do
      assert Actor.execute(%{action: :apoptosis, reason: "critical failure", severity: :high}) ==
               :ok
    end
  end

  describe "execute/1 — unknown action returns :error" do
    test "returns :error for unrecognised atom :restart" do
      assert Actor.execute(%{action: :restart}) == :error
    end

    test "returns :error for :scale_down (not handled)" do
      assert Actor.execute(%{action: :scale_down}) == :error
    end

    test "returns :error for string action" do
      assert Actor.execute(%{action: "none"}) == :error
    end

    test "returns :error for nil action" do
      assert Actor.execute(%{action: nil}) == :error
    end

    test "returns :error for integer action" do
      assert Actor.execute(%{action: 0}) == :error
    end

    test "returns :error for completely unknown atom" do
      assert Actor.execute(%{action: :fly_to_moon}) == :error
    end
  end

  describe "execute/1 — return value contract" do
    test "always returns an atom" do
      decisions = [
        %{action: :none},
        %{action: :scale_up},
        %{action: :apoptosis},
        %{action: :bogus}
      ]

      for decision <- decisions do
        assert is_atom(Actor.execute(decision)),
               "Expected atom result for #{inspect(decision)}"
      end
    end

    test "result is always :ok or :error" do
      decisions = [
        %{action: :none},
        %{action: :scale_up},
        %{action: :apoptosis},
        %{action: :mystery}
      ]

      for decision <- decisions do
        result = Actor.execute(decision)

        assert result in [:ok, :error],
               "Expected :ok or :error, got #{inspect(result)} for #{inspect(decision)}"
      end
    end

    test "all three known-good actions return :ok" do
      known_good = [:none, :scale_up, :apoptosis]

      for action <- known_good do
        assert Actor.execute(%{action: action}) == :ok,
               "Expected :ok for known-good action #{inspect(action)}"
      end
    end
  end
end
