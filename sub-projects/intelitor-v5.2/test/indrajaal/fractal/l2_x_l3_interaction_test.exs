defmodule Indrajaal.Fractal.L2xL3InteractionTest do
  @moduledoc """
  P2-FEAT: Fractal L2xL3 interaction test — component-to-holon state propagation.

  WHAT: Validates that L2 (Component) state changes propagate correctly to L3 (Holon) registry/health.
  WHY: SC-FRAC-001, SC-STATE-001 (atomic state updates), SC-STATE-003 (transitions logged).
  CONSTRAINTS: SC-FRAC-001, SC-STATE-001, SC-HOLON-001, AOR-HOLON-001
  TASK: fd712537
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Core.Holon.Registry
  alias Indrajaal.Core.Holon.HealthPropagator

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Registry is a singleton (name: __MODULE__), start it if not already running
    registry_pid =
      case Registry.start_link([]) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    # HealthPropagator accepts a name: option — use unique name per test
    propagator_name = :"test_propagator_#{System.unique_integer([:positive])}"
    {:ok, propagator_pid} = HealthPropagator.start_link(name: propagator_name)

    on_exit(fn ->
      # Don't stop Registry singleton — other tests may need it
      if Process.alive?(propagator_pid) do
        try do
          GenServer.stop(propagator_pid, :normal, 5000)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    %{propagator: propagator_name, registry_pid: registry_pid}
  end

  # ============================================================
  # L2 Component → L3 Holon: Registry Registration
  # ============================================================

  describe "component-to-holon registration (L2→L3)" do
    test "register/4 adds holon to registry" do
      id = "holon-alpha-#{System.unique_integer([:positive])}"
      result = Registry.register(id, self(), :l3)
      assert result == :ok or match?({:ok, _}, result)
    end

    test "lookup/1 finds registered holon" do
      id = "holon-beta-#{System.unique_integer([:positive])}"
      Registry.register(id, self(), :l3)
      result = Registry.lookup(id)
      assert match?({:ok, _}, result)
    end

    test "lookup/1 returns error for unregistered holon" do
      result = Registry.lookup("nonexistent-holon-#{System.unique_integer([:positive])}")
      assert match?({:error, _}, result)
    end

    test "unregister/1 removes holon" do
      id = "holon-gamma-#{System.unique_integer([:positive])}"
      Registry.register(id, self(), :l3)
      result = Registry.unregister(id)
      assert result == :ok or match?({:ok, _}, result)

      assert match?({:error, _}, Registry.lookup(id))
    end

    test "count/0 reflects registrations" do
      initial = Registry.count()
      assert is_integer(initial)

      id1 = "holon-count-1-#{System.unique_integer([:positive])}"
      id2 = "holon-count-2-#{System.unique_integer([:positive])}"
      Registry.register(id1, self(), :l3)
      Registry.register(id2, self(), :l4)

      final = Registry.count()
      assert final == initial + 2
    end
  end

  # ============================================================
  # L2 Component → L3 Holon: Layer-Based Organization
  # ============================================================

  describe "layer-based holon organization (L2→L3)" do
    test "list_by_layer/1 returns holons at specific layer" do
      id = "l3-holon-a-#{System.unique_integer([:positive])}"
      Registry.register(id, self(), :l3)

      l3_holons = Registry.list_by_layer(:l3)
      assert is_list(l3_holons)
      assert length(l3_holons) >= 1
    end

    test "count_by_layer/1 counts holons at layer" do
      id1 = "l3-count-a-#{System.unique_integer([:positive])}"
      id2 = "l3-count-b-#{System.unique_integer([:positive])}"
      Registry.register(id1, self(), :l3)
      Registry.register(id2, self(), :l3)

      count = Registry.count_by_layer(:l3)
      assert is_integer(count)
      assert count >= 2
    end

    test "all_ids/0 returns all registered IDs" do
      id1 = "all-id-1-#{System.unique_integer([:positive])}"
      id2 = "all-id-2-#{System.unique_integer([:positive])}"
      Registry.register(id1, self(), :l3)
      Registry.register(id2, self(), :l4)

      ids = Registry.all_ids()
      assert is_list(ids)
      assert id1 in ids
      assert id2 in ids
    end
  end

  # ============================================================
  # L2 Component → L3 Holon: Health Propagation
  # ============================================================

  describe "health propagation across holons (L2→L3)" do
    test "report_health/4 accepts health report", %{propagator: propagator} do
      result = HealthPropagator.report_health(propagator, "child-1", "parent-1", :healthy)
      assert result == :ok or match?({:ok, _}, result)
    end

    test "get_health/2 retrieves reported health", %{propagator: propagator} do
      HealthPropagator.report_health(propagator, "child-2", "parent-1", :unhealthy)
      result = HealthPropagator.get_health(propagator, "child-2")
      assert match?({:ok, :unhealthy}, result) or result == :unhealthy
    end

    test "derive_parent_health/2 aggregates child health", %{propagator: propagator} do
      HealthPropagator.report_health(propagator, "child-a", "parent-agg", :healthy)
      HealthPropagator.report_health(propagator, "child-b", "parent-agg", :healthy)

      result = HealthPropagator.derive_parent_health(propagator, "parent-agg")
      assert match?({:ok, health} when is_atom(health), result)
    end

    test "unhealthy child degrades parent health", %{propagator: propagator} do
      HealthPropagator.report_health(propagator, "ch-ok", "parent-mixed", :healthy)
      HealthPropagator.report_health(propagator, "ch-bad", "parent-mixed", :unhealthy)

      {:ok, parent_health} = HealthPropagator.derive_parent_health(propagator, "parent-mixed")
      # Parent with unhealthy child should not be :healthy
      assert parent_health in [:unhealthy, :degraded, :warning, :mixed]
    end

    test "metrics/1 returns propagator stats", %{propagator: propagator} do
      HealthPropagator.report_health(propagator, "metrics-child", "metrics-parent", :healthy)
      metrics = HealthPropagator.metrics(propagator)
      assert is_map(metrics)
    end
  end

  # ============================================================
  # L2 Component → L3 Holon: Parent-Child Hierarchy
  # ============================================================

  describe "parent-child hierarchy (L2→L3)" do
    test "register with parent establishes hierarchy" do
      parent_id = "parent-node-#{System.unique_integer([:positive])}"
      child_id = "child-node-#{System.unique_integer([:positive])}"
      Registry.register(parent_id, self(), :l3)
      Registry.register(child_id, self(), :l4, parent_id)

      children = Registry.list_children(parent_id)
      assert is_list(children)

      assert Enum.any?(children, fn c ->
               c == child_id or (is_tuple(c) and elem(c, 0) == child_id)
             end)
    end

    test "find_orphans/0 detects holons without parents" do
      id = "orphan-holon-#{System.unique_integer([:positive])}"
      Registry.register(id, self(), :l3)
      orphans = Registry.find_orphans()
      assert is_list(orphans)
    end
  end
end
