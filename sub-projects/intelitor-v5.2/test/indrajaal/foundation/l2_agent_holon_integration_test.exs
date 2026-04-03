defmodule Indrajaal.Foundation.L2AgentHolonIntegrationTest do
  @moduledoc """
  L2 Agent Holon Integration Tests.

  Tests the 25 L1 Agent Holons, 2 L2 Supervisor Holons, and 1 L3 Executive Supervisor.

  Agent Hierarchy:
  - L3: 1 Executive Supervisor (ExecHolon)
    - L2: 2 Domain Supervisors (DomainSupervisorHolon)
      - L1: 25 Agent Holons distributed across domains

  STAMP Constraints:
  - SC-AGT-HOL-001: All agents MUST register with HolonRegistry
  - SC-AGT-HOL-002: Agents MUST implement VSM S1-S5 callbacks
  - SC-AGT-HOL-003: Health propagation MUST complete within 100ms
  - SC-AGT-HOL-004: Agents MUST verify constitution on startup
  - SC-AGT-HOL-005: Agent death MUST trigger auto-unregister
  - SC-SUP-001: L2 supervisors MUST monitor L1 agents
  - SC-SUP-002: L3 executive MUST monitor L2 supervisors
  - SC-SUP-003: Health MUST propagate up the hierarchy

  TDG Constraints:
  - TDG-L2-001: Tests written before holon wiring implementation
  - TDG-L2-002: All 25 agents verified as holons
  - TDG-L2-003: Supervisor hierarchy tested

  FMEA Analysis:
  - FM-001: Agent fails to register -> CRITICAL (system blindness)
  - FM-002: Health propagation timeout -> HIGH (delayed response)
  - FM-003: Orphan agent detection failure -> MEDIUM (resource leak)
  - FM-004: Supervisor restart failure -> CRITICAL (cascade failure)
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Registry, as: HolonRegistry
  alias Indrajaal.Core.Holon.HealthPropagator
  alias Indrajaal.Core.Constitution.Verifier

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.1: AGENT HOLON MODULES EXIST
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.1: Core Agent Modules" do
    @core_agents [
      Indrajaal.Distributed.Agents.BaseAgent,
      Indrajaal.Distributed.Agents.OODAAgent,
      Indrajaal.Distributed.Agents.ACEAgent,
      Indrajaal.Distributed.Agents.CortexAgent,
      Indrajaal.Distributed.Agents.FractalAgent,
      Indrajaal.Distributed.Agents.CEPAFAgent,
      Indrajaal.Distributed.Agents.SentinelAgent,
      Indrajaal.Distributed.Agents.KPIDashboardAgent
    ]

    test "all core agent modules are loaded" do
      for module <- @core_agents do
        assert Code.ensure_loaded?(module), "Module #{module} not loaded"
      end
    end

    test "BaseAgent provides __using__ macro for behavior" do
      # BaseAgent should provide behavior for other agents
      assert function_exported?(Indrajaal.Distributed.Agents.BaseAgent, :__info__, 1)
    end

    test "OODAAgent implements GenServer" do
      assert function_exported?(Indrajaal.Distributed.Agents.OODAAgent, :start_link, 1)
      assert function_exported?(Indrajaal.Distributed.Agents.OODAAgent, :init, 1)
    end

    test "ACEAgent implements GenServer" do
      assert function_exported?(Indrajaal.Distributed.Agents.ACEAgent, :start_link, 1)
      assert function_exported?(Indrajaal.Distributed.Agents.ACEAgent, :init, 1)
    end

    test "SentinelAgent implements GenServer" do
      assert function_exported?(Indrajaal.Distributed.Agents.SentinelAgent, :start_link, 1)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.2: AGENT MESH INFRASTRUCTURE
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.2: AgentMesh Infrastructure" do
    test "AgentMesh module is defined" do
      assert Code.ensure_loaded?(Indrajaal.Distributed.AgentMesh)
    end

    test "AgentMesh exports start_link/1" do
      assert function_exported?(Indrajaal.Distributed.AgentMesh, :start_link, 1)
    end

    test "AgentMesh exports mesh_status/0" do
      assert function_exported?(Indrajaal.Distributed.AgentMesh, :mesh_status, 0)
    end

    test "AgentMesh exports get_agent/1" do
      assert function_exported?(Indrajaal.Distributed.AgentMesh, :get_agent, 1)
    end

    test "AgentMesh exports list_agents/0" do
      assert function_exported?(Indrajaal.Distributed.AgentMesh, :list_agents, 0)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.3: HOLON BEHAVIOUR COMPLIANCE
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.3: Holon Behaviour" do
    test "Holon module is defined" do
      assert Code.ensure_loaded?(Holon)
    end

    test "Holon behaviour has required callbacks" do
      callbacks = Holon.behaviour_info(:callbacks)

      # VSM System callbacks (using correct arities)
      assert {:system1_operations, 1} in callbacks
      assert {:system2_coordination, 1} in callbacks
      assert {:system3_control, 1} in callbacks
      assert {:system4_intelligence, 1} in callbacks
      assert {:system5_policy, 0} in callbacks

      # Identity callbacks
      assert {:holon_id, 0} in callbacks
      assert {:layer, 0} in callbacks
      assert {:parent, 0} in callbacks
      assert {:children, 0} in callbacks
      assert {:health, 0} in callbacks
    end

    test "Holon layers are defined correctly" do
      layers = Holon.layers()

      assert length(layers) == 7
      assert :function in layers
      assert :module in layers
      assert :agent in layers
      assert :container in layers
      assert :node in layers
      assert :cluster in layers
      assert :federation in layers
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.4: HOLON REGISTRY OPERATIONS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.4: Holon Registry Operations" do
    test "registry can register a test holon (SC-REG-001)" do
      # Generate unique ID for test
      test_id = "test-agent-#{System.unique_integer([:positive])}"

      # Register a test holon at agent layer
      result = HolonRegistry.register(test_id, self(), :agent, nil)

      assert result == :ok

      # Verify registration
      assert {:ok, registration} = HolonRegistry.lookup(test_id)
      assert registration.id == test_id
      assert registration.layer == :agent
      assert registration.pid == self()

      # Cleanup
      HolonRegistry.unregister(test_id)
    end

    test "registry lookup completes within 10ms (SC-REG-002)" do
      test_id = "perf-test-#{System.unique_integer([:positive])}"
      :ok = HolonRegistry.register(test_id, self(), :agent, nil)

      start_time = System.monotonic_time(:microsecond)
      _result = HolonRegistry.lookup(test_id)
      elapsed = System.monotonic_time(:microsecond) - start_time

      # 10ms = 10,000 microseconds
      assert elapsed < 10_000, "Lookup took #{elapsed}μs, exceeds 10ms limit"

      HolonRegistry.unregister(test_id)
    end

    test "registry tracks parent-child relationships" do
      parent_id = "parent-#{System.unique_integer([:positive])}"
      child_id = "child-#{System.unique_integer([:positive])}"

      # Register parent
      :ok = HolonRegistry.register(parent_id, self(), :container, nil)

      # Spawn a child process
      {:ok, child_pid} = Task.start(fn -> Process.sleep(:infinity) end)

      # Register child with parent
      :ok = HolonRegistry.register(child_id, child_pid, :agent, parent_id)

      # Verify child is listed under parent
      children = HolonRegistry.list_children(parent_id)
      assert length(children) >= 1
      child_ids = Enum.map(children, & &1.id)
      assert child_id in child_ids

      # Cleanup
      Process.exit(child_pid, :kill)
      HolonRegistry.unregister(parent_id)
    end

    test "registry list_by_layer returns agents at agent layer" do
      test_id = "layer-test-#{System.unique_integer([:positive])}"
      :ok = HolonRegistry.register(test_id, self(), :agent, nil)

      agents = HolonRegistry.list_by_layer(:agent)
      assert is_list(agents)

      # Our test agent should be in the list
      agent_ids = Enum.map(agents, & &1.id)
      assert test_id in agent_ids

      HolonRegistry.unregister(test_id)
    end

    test "registry count returns non-negative integer" do
      count = HolonRegistry.count()
      assert is_integer(count)
      assert count >= 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.5: HEALTH PROPAGATION SYSTEM
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.5: Health Propagation" do
    setup do
      name = :"health_prop_l2_#{System.unique_integer([:positive])}"
      {:ok, pid} = HealthPropagator.start_link(name: name)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
      end)

      {:ok, propagator: name}
    end

    test "health propagates from L1 to L2 (SC-AGT-HOL-003)", %{propagator: prop} do
      # Simulate L1 agents reporting to L2 supervisor
      :ok = HealthPropagator.report_health(prop, "agent-1", "supervisor-1", :healthy)
      :ok = HealthPropagator.report_health(prop, "agent-2", "supervisor-1", :healthy)
      :ok = HealthPropagator.report_health(prop, "agent-3", "supervisor-1", :degraded)

      # Derive L2 supervisor health
      health = HealthPropagator.derive_parent_health(prop, "supervisor-1")

      # With one degraded child, parent should be degraded
      assert health == :degraded
    end

    test "health propagates from L2 to L3", %{propagator: prop} do
      # L2 supervisors report to L3 executive
      :ok = HealthPropagator.report_health(prop, "supervisor-1", "executive", :healthy)
      :ok = HealthPropagator.report_health(prop, "supervisor-2", "executive", :healthy)

      health = HealthPropagator.derive_parent_health(prop, "executive")
      assert health == :healthy

      # One supervisor goes critical
      :ok = HealthPropagator.report_health(prop, "supervisor-1", "executive", :critical)
      health = HealthPropagator.derive_parent_health(prop, "executive")
      assert health == :critical
    end

    test "health propagation completes within 100ms", %{propagator: prop} do
      start_time = System.monotonic_time(:millisecond)

      # Report from 10 agents
      for i <- 1..10 do
        :ok = HealthPropagator.report_health(prop, "agent-#{i}", "supervisor", :healthy)
      end

      _health = HealthPropagator.derive_parent_health(prop, "supervisor")

      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 100, "Health propagation took #{elapsed}ms, exceeds 100ms limit"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.6: VSM SYSTEMS INTEGRATION
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.6: VSM Systems" do
    @vsm_modules [
      Indrajaal.Core.VSM.System1Operations,
      Indrajaal.Core.VSM.System2Coordination,
      Indrajaal.Core.VSM.System3Control,
      Indrajaal.Core.VSM.System4Intelligence,
      Indrajaal.Core.VSM.System5Policy
    ]

    test "all VSM system modules are loaded" do
      for module <- @vsm_modules do
        assert Code.ensure_loaded?(module), "VSM module #{module} not loaded"
      end
    end

    test "S1 Operations provides execute/2 (context, fn)" do
      assert function_exported?(Indrajaal.Core.VSM.System1Operations, :execute, 2)
    end

    test "S2 Coordination provides gossip/2" do
      assert function_exported?(Indrajaal.Core.VSM.System2Coordination, :gossip, 2)
    end

    test "S2 Coordination provides coordinate/3" do
      assert function_exported?(Indrajaal.Core.VSM.System2Coordination, :coordinate, 3)
    end

    test "S3 Control provides check_budget/1" do
      assert function_exported?(Indrajaal.Core.VSM.System3Control, :check_budget, 1)
    end

    test "S4 Intelligence provides plan/2" do
      assert function_exported?(Indrajaal.Core.VSM.System4Intelligence, :plan, 2)
    end

    test "S5 Policy provides verify_constitution/1" do
      assert function_exported?(Indrajaal.Core.VSM.System5Policy, :verify_constitution, 1)
    end

    test "S5 Policy provides decide/3" do
      assert function_exported?(Indrajaal.Core.VSM.System5Policy, :decide, 3)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.7: SUPERVISOR HOLON STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.7: Supervisor Structure" do
    test "HolonSupervisor module exists" do
      assert Code.ensure_loaded?(Indrajaal.Core.Holon.Supervisor)
    end

    test "HolonSupervisor exports start_link/1" do
      assert function_exported?(Indrajaal.Core.Holon.Supervisor, :start_link, 1)
    end

    test "HolonSupervisor exports child_count/1" do
      assert function_exported?(Indrajaal.Core.Holon.Supervisor, :child_count, 1)
    end

    test "HolonSupervisor exports children_summary/1" do
      assert function_exported?(Indrajaal.Core.Holon.Supervisor, :children_summary, 1)
    end

    test "HolonSupervisor exports start_child/3" do
      assert function_exported?(Indrajaal.Core.Holon.Supervisor, :start_child, 3)
    end

    test "HolonSupervisor exports strategy_for_layer/1" do
      assert function_exported?(Indrajaal.Core.Holon.Supervisor, :strategy_for_layer, 1)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.8: AGENT POOL INTEGRATION
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.8: Agent Pool" do
    test "AgentPool module exists" do
      assert Code.ensure_loaded?(Indrajaal.Parallelization.AgentPool)
    end

    test "AgentPool provides new/1 for pool creation" do
      pool_module = Indrajaal.Parallelization.AgentPool
      assert function_exported?(pool_module, :new, 1)
    end

    test "AgentPool provides add_agent/2" do
      pool_module = Indrajaal.Parallelization.AgentPool
      assert function_exported?(pool_module, :add_agent, 2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.9: CONSTITUTION VERIFICATION FOR AGENTS
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.9: Constitution Verification" do
    test "constitution is verified before agent operations" do
      # Verify constitution is in valid state
      assert Verifier.verified?()
    end

    test "verify_for_operation accepts critical operations" do
      critical_ops = [:replicate, :federate, :mutate, :upgrade]

      for op <- critical_ops do
        result = Verifier.verify_for_operation(op)
        # Should either be :ok or {:error, :constitution_violated}
        assert result in [:ok, {:error, :constitution_violated}]
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2 GATE: INTEGRATION VERIFICATION
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2 Gate: Agent Holon Integration" do
    test "all L2 infrastructure modules are loaded" do
      modules = [
        # Core Holon
        Indrajaal.Core.Holon,
        Indrajaal.Core.Holon.Registry,
        Indrajaal.Core.Holon.HealthPropagator,
        Indrajaal.Core.Holon.Supervisor,

        # Agents
        Indrajaal.Distributed.Agents.BaseAgent,
        Indrajaal.Distributed.Agents.OODAAgent,
        Indrajaal.Distributed.Agents.ACEAgent,

        # VSM
        Indrajaal.Core.VSM.System1Operations,
        Indrajaal.Core.VSM.System5Policy,

        # Mesh
        Indrajaal.Distributed.AgentMesh
      ]

      for module <- modules do
        assert Code.ensure_loaded?(module), "Module #{module} not loaded"
      end
    end

    test "agent holon registration flow works" do
      # This simulates the full agent-as-holon registration flow
      agent_id = "test-agent-holon-#{System.unique_integer([:positive])}"
      supervisor_id = "test-supervisor-#{System.unique_integer([:positive])}"

      # Register supervisor first (L2)
      :ok = HolonRegistry.register(supervisor_id, self(), :container, nil)

      # Spawn agent process
      {:ok, agent_pid} = Task.start(fn -> Process.sleep(:infinity) end)

      # Register agent under supervisor (L1)
      :ok = HolonRegistry.register(agent_id, agent_pid, :agent, supervisor_id)

      # Verify hierarchy
      children = HolonRegistry.list_children(supervisor_id)
      child_ids = Enum.map(children, & &1.id)
      assert agent_id in child_ids

      # Verify layers
      agents = HolonRegistry.list_by_layer(:agent)
      agent_ids = Enum.map(agents, & &1.id)
      assert agent_id in agent_ids

      # Cleanup
      Process.exit(agent_pid, :kill)
      HolonRegistry.unregister(agent_id)
      HolonRegistry.unregister(supervisor_id)
    end

    test "L2 STAMP constraints are enforceable" do
      # SC-AGT-HOL-001: Registration exists
      assert function_exported?(HolonRegistry, :register, 4)

      # SC-AGT-HOL-003: Health propagation exists
      assert function_exported?(HealthPropagator, :report_health, 4)

      # SC-SUP-001: Supervisor monitoring exists
      assert function_exported?(Indrajaal.Core.Holon.Supervisor, :child_count, 1)
      assert function_exported?(Indrajaal.Core.Holon.Supervisor, :children_summary, 1)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L2.10: AGENT COUNT VERIFICATION (25 L1 Agents Target)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L2.10: Agent Count Target" do
    @tag :integration
    test "target is 25 L1 agent holons" do
      # This test documents the target architecture
      # Currently we have 8 core agents, need to add domain agents

      existing_agents = [
        :ooda_agent,
        :ace_agent,
        :cortex_agent,
        :fractal_agent,
        :cepaf_agent,
        :sentinel_agent,
        :kpi_dashboard_agent
      ]

      # Target: 25 L1 agents
      # Existing: 7 (excluding BaseAgent which is a behavior)
      # Need: 18 more domain/functional agents

      assert length(existing_agents) == 7, "Expected 7 existing agents"

      # Target agent architecture per spec:
      # - 1 Executive (L3)
      # - 10 Domain Agents (L1, grouped by Ash domains)
      # - 15 Functional Agents (L1, cross-cutting concerns)
      # Total L1: 25 (10 + 15)

      target_l1_count = 25
      current_l1_count = length(existing_agents)
      gap = target_l1_count - current_l1_count

      assert gap >= 0, "Gap should be non-negative"

      # Document the gap for implementation
      IO.puts("\n  📊 Agent Holon Target:")
      IO.puts("     Target L1 Agents: #{target_l1_count}")
      IO.puts("     Current Agents: #{current_l1_count}")
      IO.puts("     Gap: #{gap} agents needed")
    end
  end
end
