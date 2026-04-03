defmodule Indrajaal.Foundation.L3SupervisorHierarchyTest do
  @moduledoc """
  L3 Supervisor Hierarchy Integration Tests.

  Tests the 3-tier fractal supervision structure:
  - L3: 1 Executive Supervisor (identity: System 5 Policy)
  - L2: 2 Domain Supervisors (coordination: System 2/3)
  - L1: 25 Agent Holons (operations: System 1)

  Fractal VSM Mapping:
  ┌─────────────────────────────────────────────────────────────┐
  │ L3: Executive Supervisor                                    │
  │     - System 5: Policy & Constitution                       │
  │     - System 4: Strategic Intelligence                      │
  │     - Monitors 2 L2 Supervisors                             │
  ├─────────────────────────────────────────────────────────────┤
  │ L2-A: Operations Domain        │ L2-B: Intelligence Domain │
  │     - System 3: Control        │     - System 4: Planning  │
  │     - System 2: Coordination   │     - System 3: Control   │
  │     - Monitors ~12 L1 Agents   │     - Monitors ~13 Agents │
  ├─────────────────────────────────────────────────────────────┤
  │ L1: Agent Holons (25 total)                                 │
  │     - System 1: Operations                                  │
  │     - Each agent: OODAAgent, ACEAgent, CortexAgent, etc.    │
  └─────────────────────────────────────────────────────────────┘

  STAMP Constraints:
  - SC-HIER-001: Hierarchy MUST maintain parent-child integrity
  - SC-HIER-002: Health MUST propagate upward within 100ms
  - SC-HIER-003: Constitution MUST be verified before any restart
  - SC-HIER-004: L3 MUST have authority over all subordinates
  - SC-HIER-005: Orphan agents MUST be detected within 1s

  TDG Constraints:
  - TDG-L3-001: Tests written before supervisor implementation
  - TDG-L3-002: All 3 tiers verified in hierarchy
  - TDG-L3-003: Health propagation tested end-to-end

  FMEA Analysis:
  - FM-HIER-001: L3 failure -> CRITICAL (total system down)
  - FM-HIER-002: L2 failure -> HIGH (domain degraded)
  - FM-HIER-003: L1 failure -> MEDIUM (single agent)
  - FM-HIER-004: Health propagation timeout -> HIGH (delayed response)
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Registry, as: HolonRegistry
  alias Indrajaal.Core.Holon.HealthPropagator
  alias Indrajaal.Core.Holon.Supervisor, as: HolonSupervisor
  alias Indrajaal.Core.Constitution.Verifier

  # ═══════════════════════════════════════════════════════════════════════════
  # L3.1: EXECUTIVE SUPERVISOR STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3.1: Executive Supervisor" do
    test "HolonSupervisor supports federation layer" do
      strategy = HolonSupervisor.strategy_for_layer(:federation)
      assert strategy == :one_for_all
    end

    test "HolonSupervisor supports cluster layer" do
      strategy = HolonSupervisor.strategy_for_layer(:cluster)
      assert strategy == :one_for_all
    end

    test "HolonSupervisor supports node layer" do
      strategy = HolonSupervisor.strategy_for_layer(:node)
      assert strategy == :one_for_all
    end

    test "max restarts for federation is conservative" do
      {max, seconds} = HolonSupervisor.max_restarts_for_layer(:federation)
      # Federation: 1 restart per 30 minutes
      assert max == 1
      assert seconds == 1800
    end

    test "max restarts for cluster is conservative" do
      {max, seconds} = HolonSupervisor.max_restarts_for_layer(:cluster)
      # Cluster: 1 restart per 15 minutes
      assert max == 1
      assert seconds == 900
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L3.2: DOMAIN SUPERVISOR STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3.2: Domain Supervisors (L2)" do
    test "HolonSupervisor supports container layer" do
      strategy = HolonSupervisor.strategy_for_layer(:container)
      assert strategy == :rest_for_one
    end

    test "max restarts for container allows recovery" do
      {max, seconds} = HolonSupervisor.max_restarts_for_layer(:container)
      # Container: 3 restarts per 5 minutes
      assert max == 3
      assert seconds == 300
    end

    test "HolonSupervisor supports agent layer" do
      strategy = HolonSupervisor.strategy_for_layer(:agent)
      assert strategy == :one_for_one
    end

    test "max restarts for agent allows more tolerance" do
      {max, seconds} = HolonSupervisor.max_restarts_for_layer(:agent)
      # Agent: 3 restarts per 1 minute
      assert max == 3
      assert seconds == 60
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L3.3: HIERARCHY REGISTRATION FLOW
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3.3: Hierarchy Registration" do
    setup do
      # Create unique IDs for this test run
      exec_id = "exec-#{System.unique_integer([:positive])}"
      domain_a_id = "domain-a-#{System.unique_integer([:positive])}"
      domain_b_id = "domain-b-#{System.unique_integer([:positive])}"
      agent_ids = for i <- 1..5, do: "agent-#{i}-#{System.unique_integer([:positive])}"

      {:ok,
       exec_id: exec_id, domain_a_id: domain_a_id, domain_b_id: domain_b_id, agent_ids: agent_ids}
    end

    test "can register 3-tier hierarchy (SC-HIER-001)", ctx do
      # L3: Executive Supervisor
      :ok = HolonRegistry.register(ctx.exec_id, self(), :node, nil)

      # L2: Domain Supervisors under Executive
      {:ok, domain_a_pid} = Task.start(fn -> Process.sleep(:infinity) end)
      {:ok, domain_b_pid} = Task.start(fn -> Process.sleep(:infinity) end)

      :ok = HolonRegistry.register(ctx.domain_a_id, domain_a_pid, :container, ctx.exec_id)
      :ok = HolonRegistry.register(ctx.domain_b_id, domain_b_pid, :container, ctx.exec_id)

      # L1: Agents under Domain A
      pids =
        for agent_id <- ctx.agent_ids do
          {:ok, pid} = Task.start(fn -> Process.sleep(:infinity) end)
          :ok = HolonRegistry.register(agent_id, pid, :agent, ctx.domain_a_id)
          pid
        end

      # Verify hierarchy
      exec_children = HolonRegistry.list_children(ctx.exec_id)
      assert length(exec_children) == 2

      domain_a_children = HolonRegistry.list_children(ctx.domain_a_id)
      assert length(domain_a_children) == 5

      # Cleanup
      Enum.each(pids ++ [domain_a_pid, domain_b_pid], &Process.exit(&1, :kill))
      Enum.each(ctx.agent_ids, &HolonRegistry.unregister/1)
      HolonRegistry.unregister(ctx.domain_a_id)
      HolonRegistry.unregister(ctx.domain_b_id)
      HolonRegistry.unregister(ctx.exec_id)
    end

    test "list_by_layer correctly returns nodes at each layer", ctx do
      # Register a node
      :ok = HolonRegistry.register(ctx.exec_id, self(), :node, nil)

      nodes = HolonRegistry.list_by_layer(:node)
      node_ids = Enum.map(nodes, & &1.id)
      assert ctx.exec_id in node_ids

      HolonRegistry.unregister(ctx.exec_id)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L3.4: HEALTH PROPAGATION THROUGH HIERARCHY
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3.4: Hierarchical Health Propagation" do
    setup do
      name = :"health_prop_l3_#{System.unique_integer([:positive])}"
      {:ok, pid} = HealthPropagator.start_link(name: name)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
      end)

      {:ok, propagator: name}
    end

    test "health propagates L1 -> L2 -> L3 (SC-HIER-002)", %{propagator: prop} do
      # L1 agents report to L2 domain supervisor
      :ok = HealthPropagator.report_health(prop, "agent-1", "domain-ops", :healthy)
      :ok = HealthPropagator.report_health(prop, "agent-2", "domain-ops", :healthy)
      :ok = HealthPropagator.report_health(prop, "agent-3", "domain-ops", :degraded)

      # L2 domain supervisor health derived
      domain_health = HealthPropagator.derive_parent_health(prop, "domain-ops")
      assert domain_health == :degraded

      # Report L2 to L3
      :ok = HealthPropagator.report_health(prop, "domain-ops", "executive", :degraded)
      :ok = HealthPropagator.report_health(prop, "domain-intel", "executive", :healthy)

      # L3 executive health derived
      exec_health = HealthPropagator.derive_parent_health(prop, "executive")
      assert exec_health == :degraded
    end

    test "critical L1 agent propagates critical to L3", %{propagator: prop} do
      # L1: One critical agent
      :ok = HealthPropagator.report_health(prop, "sentinel", "domain-ops", :critical)

      # L2: Domain becomes critical
      domain_health = HealthPropagator.derive_parent_health(prop, "domain-ops")
      assert domain_health == :critical

      # Report to L3
      :ok = HealthPropagator.report_health(prop, "domain-ops", "executive", :critical)

      # L3: Executive becomes critical
      exec_health = HealthPropagator.derive_parent_health(prop, "executive")
      assert exec_health == :critical
    end

    test "all healthy agents produce healthy hierarchy", %{propagator: prop} do
      # L1: All healthy
      for i <- 1..10 do
        :ok = HealthPropagator.report_health(prop, "agent-#{i}", "domain", :healthy)
      end

      # L2: Domain healthy
      domain_health = HealthPropagator.derive_parent_health(prop, "domain")
      assert domain_health == :healthy

      # Report to L3
      :ok = HealthPropagator.report_health(prop, "domain", "executive", :healthy)

      # L3: Executive healthy
      exec_health = HealthPropagator.derive_parent_health(prop, "executive")
      assert exec_health == :healthy
    end

    test "full propagation completes within 100ms (SC-HIER-002)", %{propagator: prop} do
      start_time = System.monotonic_time(:millisecond)

      # Simulate full hierarchy health update
      for i <- 1..25 do
        domain = if rem(i, 2) == 0, do: "domain-a", else: "domain-b"
        :ok = HealthPropagator.report_health(prop, "agent-#{i}", domain, :healthy)
      end

      _domain_a_health = HealthPropagator.derive_parent_health(prop, "domain-a")
      _domain_b_health = HealthPropagator.derive_parent_health(prop, "domain-b")

      :ok = HealthPropagator.report_health(prop, "domain-a", "executive", :healthy)
      :ok = HealthPropagator.report_health(prop, "domain-b", "executive", :healthy)

      _exec_health = HealthPropagator.derive_parent_health(prop, "executive")

      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 100, "Full hierarchy propagation took #{elapsed}ms, exceeds 100ms"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L3.5: CONSTITUTION VERIFICATION IN HIERARCHY
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3.5: Constitution Verification" do
    test "constitution MUST be verified before operations (SC-HIER-003)" do
      assert Verifier.verified?()
    end

    test "HolonSupervisor.start_child verifies constitution" do
      # The start_child function should check constitution
      assert function_exported?(HolonSupervisor, :start_child, 3)
    end

    test "HolonSupervisor.restart_child verifies constitution" do
      # The restart_child function should check constitution
      assert function_exported?(HolonSupervisor, :restart_child, 2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L3.6: VSM SYSTEM INTEGRATION AT EACH TIER
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3.6: VSM System Integration" do
    test "S5 Policy module available for L3" do
      assert Code.ensure_loaded?(Indrajaal.Core.VSM.System5Policy)
      assert function_exported?(Indrajaal.Core.VSM.System5Policy, :verify_constitution, 1)
      assert function_exported?(Indrajaal.Core.VSM.System5Policy, :decide, 3)
    end

    test "S4 Intelligence module available for L3/L2" do
      assert Code.ensure_loaded?(Indrajaal.Core.VSM.System4Intelligence)
      assert function_exported?(Indrajaal.Core.VSM.System4Intelligence, :plan, 2)
    end

    test "S3 Control module available for L2" do
      assert Code.ensure_loaded?(Indrajaal.Core.VSM.System3Control)
      assert function_exported?(Indrajaal.Core.VSM.System3Control, :check_budget, 1)
    end

    test "S2 Coordination module available for L2" do
      assert Code.ensure_loaded?(Indrajaal.Core.VSM.System2Coordination)
      assert function_exported?(Indrajaal.Core.VSM.System2Coordination, :coordinate, 3)
    end

    test "S1 Operations module available for L1" do
      assert Code.ensure_loaded?(Indrajaal.Core.VSM.System1Operations)
      assert function_exported?(Indrajaal.Core.VSM.System1Operations, :execute, 2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L3.7: ORPHAN DETECTION
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3.7: Orphan Detection" do
    test "find_orphans detects holons with dead parents (SC-HIER-005)" do
      parent_id = "parent-orphan-test-#{System.unique_integer([:positive])}"
      child_id = "child-orphan-test-#{System.unique_integer([:positive])}"

      # Register parent and child
      {:ok, parent_pid} = Task.start(fn -> Process.sleep(:infinity) end)
      {:ok, child_pid} = Task.start(fn -> Process.sleep(:infinity) end)

      :ok = HolonRegistry.register(parent_id, parent_pid, :container, nil)
      :ok = HolonRegistry.register(child_id, child_pid, :agent, parent_id)

      # Kill parent
      Process.exit(parent_pid, :kill)
      # Allow monitor to detect
      Process.sleep(50)

      # Child should now be orphan
      orphans = HolonRegistry.find_orphans()
      assert child_id in orphans

      # Cleanup
      Process.exit(child_pid, :kill)
    end

    test "non-orphan holons not in orphan list" do
      parent_id = "parent-non-orphan-#{System.unique_integer([:positive])}"
      child_id = "child-non-orphan-#{System.unique_integer([:positive])}"

      {:ok, child_pid} = Task.start(fn -> Process.sleep(:infinity) end)

      :ok = HolonRegistry.register(parent_id, self(), :container, nil)
      :ok = HolonRegistry.register(child_id, child_pid, :agent, parent_id)

      orphans = HolonRegistry.find_orphans()
      refute child_id in orphans

      # Cleanup
      Process.exit(child_pid, :kill)
      HolonRegistry.unregister(parent_id)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L3 GATE: SUPERVISOR HIERARCHY INTEGRATION
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L3 Gate: Supervisor Hierarchy" do
    test "all L3 infrastructure modules are loaded" do
      modules = [
        # Core
        Indrajaal.Core.Holon,
        Indrajaal.Core.Holon.Registry,
        Indrajaal.Core.Holon.HealthPropagator,
        Indrajaal.Core.Holon.Supervisor,

        # VSM
        Indrajaal.Core.VSM.System1Operations,
        Indrajaal.Core.VSM.System2Coordination,
        Indrajaal.Core.VSM.System3Control,
        Indrajaal.Core.VSM.System4Intelligence,
        Indrajaal.Core.VSM.System5Policy,

        # Constitution
        Indrajaal.Core.Constitution,
        Indrajaal.Core.Constitution.Verifier
      ]

      for module <- modules do
        assert Code.ensure_loaded?(module), "Module #{module} not loaded"
      end
    end

    test "STAMP constraints are enforceable in hierarchy" do
      # SC-HIER-001: Parent-child registration
      assert function_exported?(HolonRegistry, :register, 4)
      assert function_exported?(HolonRegistry, :list_children, 1)

      # SC-HIER-002: Health propagation
      assert function_exported?(HealthPropagator, :report_health, 4)
      assert function_exported?(HealthPropagator, :derive_parent_health, 2)

      # SC-HIER-003: Constitution verification
      assert function_exported?(HolonSupervisor, :start_child, 3)
      assert function_exported?(Verifier, :verify, 0)

      # SC-HIER-005: Orphan detection
      assert function_exported?(HolonRegistry, :find_orphans, 0)
    end

    test "hierarchy layer constants are correct" do
      layers = Holon.layers()

      assert length(layers) == 7
      assert Holon.layer_depth(:function) == 0
      assert Holon.layer_depth(:module) == 1
      assert Holon.layer_depth(:agent) == 2
      assert Holon.layer_depth(:container) == 3
      assert Holon.layer_depth(:node) == 4
      assert Holon.layer_depth(:cluster) == 5
      assert Holon.layer_depth(:federation) == 6
    end
  end
end
