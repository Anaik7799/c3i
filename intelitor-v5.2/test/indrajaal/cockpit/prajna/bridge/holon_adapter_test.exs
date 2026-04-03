defmodule Indrajaal.Cockpit.Prajna.Bridge.HolonAdapterTest do
  @moduledoc """
  Tests for HolonAdapter - transforms Elixir state to F# Holon Tree structure.
  STAMP: SC-BRIDGE-001, SC-PRAJNA-004
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.Bridge.HolonAdapter
  alias Indrajaal.Cockpit.Prajna.SmartMetrics

  setup do
    # Start SmartMetrics to create the ETS table (uses default module name)
    case SmartMetrics.start_link([]) do
      {:ok, pid} -> {:ok, %{metrics_pid: pid}}
      {:error, {:already_started, pid}} -> {:ok, %{metrics_pid: pid}}
    end
  end

  describe "build_snapshot/0" do
    test "returns valid holon tree structure" do
      snapshot = HolonAdapter.build_snapshot()

      assert is_map(snapshot)
      assert Map.has_key?(snapshot, :id)
      assert Map.has_key?(snapshot, :name)
      assert Map.has_key?(snapshot, :type)
      assert Map.has_key?(snapshot, :health)
      assert Map.has_key?(snapshot, :stress)
      assert Map.has_key?(snapshot, :prediction)
      assert Map.has_key?(snapshot, :salience)
      assert Map.has_key?(snapshot, :children)
    end

    test "root holon has system type" do
      snapshot = HolonAdapter.build_snapshot()
      assert snapshot.type == :system
    end

    test "health is normalized 0-1" do
      snapshot = HolonAdapter.build_snapshot()
      assert is_float(snapshot.health)
      assert snapshot.health >= 0.0
      assert snapshot.health <= 1.0
    end

    test "stress is normalized 0-1" do
      snapshot = HolonAdapter.build_snapshot()
      assert is_float(snapshot.stress)
      assert snapshot.stress >= 0.0
      assert snapshot.stress <= 1.0
    end

    test "salience is set to 1.0 for root" do
      snapshot = HolonAdapter.build_snapshot()
      assert snapshot.salience == 1.0
    end

    test "children is a list" do
      snapshot = HolonAdapter.build_snapshot()
      assert is_list(snapshot.children)
    end

    test "generates valid UUID for id" do
      snapshot = HolonAdapter.build_snapshot()
      assert String.length(snapshot.id) == 36
      assert String.match?(snapshot.id, ~r/^[0-9a-f-]{36}$/)
    end

    test "prediction is a float or nil" do
      snapshot = HolonAdapter.build_snapshot()
      assert is_nil(snapshot.prediction) or is_float(snapshot.prediction)
    end
  end

  describe "children structure" do
    test "cluster children have required fields" do
      snapshot = HolonAdapter.build_snapshot()

      Enum.each(snapshot.children, fn child ->
        assert Map.has_key?(child, :id)
        assert Map.has_key?(child, :name)
        assert Map.has_key?(child, :type)
        assert Map.has_key?(child, :health)
        assert Map.has_key?(child, :stress)
        assert Map.has_key?(child, :children)
      end)
    end

    test "cluster children have cluster type" do
      snapshot = HolonAdapter.build_snapshot()

      Enum.each(snapshot.children, fn child ->
        assert child.type == :cluster
      end)
    end
  end
end
