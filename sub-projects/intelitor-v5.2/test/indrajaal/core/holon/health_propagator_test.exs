defmodule Indrajaal.Core.Holon.HealthPropagatorTest do
  @moduledoc """
  TDG-Compliant tests for HealthPropagator module.

  Tests health propagation between parent and child holons.

  STAMP Constraints:
  - SC-HOL-003: Holons MUST report to parent within 100ms
  - SC-HOL-004: Holons MUST propagate health to children
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Core.Holon.HealthPropagator

  describe "HealthPropagator.start_link/1" do
    test "starts health propagator" do
      assert {:ok, pid} = HealthPropagator.start_link(name: :test_hp_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "HealthPropagator.report_health/4" do
    test "SC-HOL-003: reports health to propagator" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_2)

      :ok = HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)

      state = HealthPropagator.get_health(hp, "child-1")
      assert state.health == :healthy
      GenServer.stop(hp)
    end

    test "updates health when it changes" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_3)

      :ok = HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      :ok = HealthPropagator.report_health(hp, "child-1", "parent-1", :degraded)

      state = HealthPropagator.get_health(hp, "child-1")
      assert state.health == :degraded
      GenServer.stop(hp)
    end
  end

  describe "HealthPropagator.derive_parent_health/2" do
    test "SC-HOL-004: derives parent health from children" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_4)

      # Register children
      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-2", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-3", "parent-1", :healthy)

      # All healthy -> parent healthy
      health = HealthPropagator.derive_parent_health(hp, "parent-1")
      assert health == :healthy
      GenServer.stop(hp)
    end

    test "derives degraded if any child degraded" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_5)

      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-2", "parent-1", :degraded)
      HealthPropagator.report_health(hp, "child-3", "parent-1", :healthy)

      health = HealthPropagator.derive_parent_health(hp, "parent-1")
      assert health == :degraded
      GenServer.stop(hp)
    end

    test "derives critical if any child critical" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_6)

      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-2", "parent-1", :critical)
      HealthPropagator.report_health(hp, "child-3", "parent-1", :degraded)

      health = HealthPropagator.derive_parent_health(hp, "parent-1")
      assert health == :critical
      GenServer.stop(hp)
    end

    test "derives failed if any child failed" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_7)

      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-2", "parent-1", :failed)

      health = HealthPropagator.derive_parent_health(hp, "parent-1")
      assert health == :failed
      GenServer.stop(hp)
    end
  end

  describe "HealthPropagator.subscribe/2" do
    test "notifies subscriber on health change" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_8)

      HealthPropagator.subscribe(hp, self())

      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-1", "parent-1", :degraded)

      assert_receive {:health_changed, "child-1", :healthy, :degraded}, 1000
      GenServer.stop(hp)
    end
  end

  describe "HealthPropagator.get_children_health/2" do
    test "returns health of all children for a parent" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_9)

      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)
      HealthPropagator.report_health(hp, "child-2", "parent-1", :degraded)
      HealthPropagator.report_health(hp, "child-3", "parent-2", :healthy)

      children = HealthPropagator.get_children_health(hp, "parent-1")

      assert length(children) == 2
      assert Enum.any?(children, &(&1.holon_id == "child-1"))
      assert Enum.any?(children, &(&1.holon_id == "child-2"))
      GenServer.stop(hp)
    end
  end

  describe "HealthPropagator.detect_staleness/2" do
    test "detects stale health reports" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_10, staleness_threshold_ms: 50)

      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)

      # Wait for staleness
      Process.sleep(100)

      stale = HealthPropagator.detect_staleness(hp, "parent-1")
      assert "child-1" in stale
      GenServer.stop(hp)
    end
  end

  describe "HealthPropagator.metrics/1" do
    test "returns propagator metrics" do
      {:ok, hp} = HealthPropagator.start_link(name: :test_hp_11)

      HealthPropagator.report_health(hp, "child-1", "parent-1", :healthy)

      metrics = HealthPropagator.metrics(hp)

      assert Map.has_key?(metrics, :total_holons)
      assert Map.has_key?(metrics, :health_reports)
      assert metrics.total_holons == 1
      GenServer.stop(hp)
    end
  end
end
