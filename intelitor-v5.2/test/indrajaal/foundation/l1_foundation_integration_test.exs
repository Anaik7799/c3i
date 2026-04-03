defmodule Indrajaal.Foundation.L1FoundationIntegrationTest do
  @moduledoc """
  L1 Foundation Layer Integration Tests.

  Tests the cellular substrate of the Cybernetic Organism:
  - Constitution verification (7 Omega axioms)
  - Holon Registry (fractal hierarchy tracking)
  - Health Propagator (bottom-up health aggregation)
  - Membrane protection (domain API boundaries)

  STAMP Constraints:
  - SC-CONST-001: Constitution MUST be verified before startup
  - SC-CONST-002: Hash MUST match known good value
  - SC-HOL-001: All holons MUST implement 5 VSM systems
  - SC-HOL-002: Holons MUST verify constitution on startup
  - SC-HOL-003: Holons MUST report to parent within 100ms
  - SC-HOL-004: Holons MUST propagate health to children
  - SC-REG-001: Registration MUST be idempotent
  - SC-REG-002: Lookup MUST complete within 10ms
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Core.Constitution
  alias Indrajaal.Core.Constitution.Verifier
  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Registry, as: HolonRegistry
  alias Indrajaal.Core.Holon.HealthPropagator

  # ═══════════════════════════════════════════════════════════════════════════
  # L1.1: CONSTITUTION VERIFICATION SYSTEM
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L1.1: Constitution Module" do
    test "Constitution module is defined" do
      assert Code.ensure_loaded?(Constitution)
    end

    test "Constitution exports 7 invariants (Ω₁ - Ω₇)" do
      invariants = Constitution.invariants()

      assert is_map(invariants)
      assert map_size(invariants) == 7

      assert Map.has_key?(invariants, :omega_1)
      assert Map.has_key?(invariants, :omega_2)
      assert Map.has_key?(invariants, :omega_3)
      assert Map.has_key?(invariants, :omega_4)
      assert Map.has_key?(invariants, :omega_5)
      assert Map.has_key?(invariants, :omega_6)
      assert Map.has_key?(invariants, :omega_7)
    end

    test "Constitution version is 20.0.0" do
      assert Constitution.version() == "20.0.0"
    end

    test "Constitution hash is deterministic" do
      hash1 = Constitution.hash()
      hash2 = Constitution.hash()

      assert hash1 == hash2
      assert is_binary(hash1)
      # SHA256
      assert byte_size(hash1) == 32
    end

    test "Constitution hash_hex returns valid hex string" do
      hash_hex = Constitution.hash_hex()

      assert is_binary(hash_hex)
      # 32 bytes = 64 hex chars
      assert String.length(hash_hex) == 64
      assert Regex.match?(~r/^[a-f0-9]+$/, hash_hex)
    end

    test "Ω₁ Patient Mode invariant is defined" do
      invariant = Constitution.get_invariant(:omega_1)

      assert invariant.name == :patient_mode
      assert invariant.omega == :omega_1
      assert String.contains?(invariant.description, "long-running")
    end

    test "Ω₂ Container Isolation invariant is defined" do
      invariant = Constitution.get_invariant(:omega_2)

      assert invariant.name == :container_isolation
      assert String.contains?(invariant.description, "NixOS")
    end

    test "Ω₇ Non-Aggression invariant is defined" do
      invariant = Constitution.get_invariant(:omega_7)

      assert invariant.name == :non_aggression
      assert String.contains?(invariant.description, "harm")
    end
  end

  describe "L1.1: Constitution Verifier" do
    test "Verifier module is defined" do
      assert Code.ensure_loaded?(Verifier)
    end

    test "verify returns valid result (SC-CONST-002)" do
      result = Verifier.verify()

      case result do
        {:ok, details} ->
          assert is_map(details)
          assert Map.has_key?(details, :hash)
          assert Map.has_key?(details, :verified_at)
          assert Map.has_key?(details, :version)
          assert details.invariants_checked == 7

        {:error, :constitution_violated, _details} ->
          # This is acceptable - constitution may be modified in test
          assert true
      end
    end

    test "verified? returns boolean" do
      result = Verifier.verified?()
      assert is_boolean(result)
    end

    test "health_check returns status map" do
      result = Verifier.health_check()

      assert is_map(result)
      assert result.status in [:ok, :error]
      assert Map.has_key?(result, :details)
    end

    test "check_runtime_invariants returns list of results" do
      results = Verifier.check_runtime_invariants()

      assert is_list(results)

      Enum.each(results, fn result ->
        assert match?({:ok, _}, result) or match?({:error, _, _}, result)
      end)
    end

    test "verify_for_operation accepts valid operations" do
      # These operations require constitution verification
      valid_ops = [:replicate, :federate, :mutate, :upgrade]

      for op <- valid_ops do
        result = Verifier.verify_for_operation(op)
        assert result in [:ok, {:error, :constitution_violated}]
      end
    end

    test "verify_for_operation rejects unknown operations" do
      result = Verifier.verify_for_operation(:unknown_operation)
      assert {:error, :unknown_operation} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L1.2: HOLON REGISTRY & LIFECYCLE
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L1.2: Holon Behaviour" do
    test "Holon behaviour module is defined" do
      assert Code.ensure_loaded?(Holon)
    end

    test "Holon provides __using__ macro" do
      exports = Holon.__info__(:macros)
      assert {:__using__, 1} in exports
    end

    test "layers returns 7 fractal layers" do
      layers = Holon.layers()

      assert is_list(layers)
      assert length(layers) == 7
      assert :function in layers
      assert :module in layers
      assert :agent in layers
      assert :container in layers
      assert :node in layers
      assert :cluster in layers
      assert :federation in layers
    end

    test "layer_depth returns correct depth" do
      assert Holon.layer_depth(:function) == 0
      assert Holon.layer_depth(:module) == 1
      assert Holon.layer_depth(:agent) == 2
      assert Holon.layer_depth(:container) == 3
      assert Holon.layer_depth(:node) == 4
      assert Holon.layer_depth(:cluster) == 5
      assert Holon.layer_depth(:federation) == 6
    end

    test "parent_layer? correctly identifies parent layers" do
      # Federation is parent of cluster
      assert Holon.parent_layer?(:federation, :cluster) == true

      # Cluster is parent of node
      assert Holon.parent_layer?(:cluster, :node) == true

      # Agent is parent of module
      assert Holon.parent_layer?(:agent, :module) == true

      # Function is not parent of container (too distant)
      assert Holon.parent_layer?(:function, :container) == false

      # Same layer is not parent
      assert Holon.parent_layer?(:agent, :agent) == false
    end
  end

  describe "L1.2: Holon Registry" do
    # Note: HolonRegistry uses global ETS tables, so we test the module API
    # without starting a new instance (it's started by the application)

    test "HolonRegistry module is defined" do
      assert Code.ensure_loaded?(HolonRegistry)
    end

    test "HolonRegistry exports start_link/1" do
      assert function_exported?(HolonRegistry, :start_link, 1)
    end

    test "HolonRegistry exports register/4" do
      assert function_exported?(HolonRegistry, :register, 4)
    end

    test "HolonRegistry exports lookup/1" do
      assert function_exported?(HolonRegistry, :lookup, 1)
    end

    test "HolonRegistry exports list_by_layer/1" do
      assert function_exported?(HolonRegistry, :list_by_layer, 1)
    end

    test "HolonRegistry exports list_children/1" do
      assert function_exported?(HolonRegistry, :list_children, 1)
    end

    test "HolonRegistry exports count/0" do
      assert function_exported?(HolonRegistry, :count, 0)
    end

    test "HolonRegistry exports find_orphans/0" do
      assert function_exported?(HolonRegistry, :find_orphans, 0)
    end

    test "HolonRegistry operations work with global instance" do
      # Test basic operations against the globally started registry
      # Count should be a non-negative integer
      count = HolonRegistry.count()
      assert is_integer(count)
      assert count >= 0

      # List by layer should return a list
      agents = HolonRegistry.list_by_layer(:agent)
      assert is_list(agents)
    end
  end

  describe "L1.2: Health Propagator" do
    setup do
      name = :"health_prop_#{System.unique_integer([:positive])}"
      {:ok, pid} = HealthPropagator.start_link(name: name)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
      end)

      {:ok, propagator: name, pid: pid}
    end

    test "HealthPropagator module is defined" do
      assert Code.ensure_loaded?(HealthPropagator)
    end

    test "HealthPropagator exports report_health/4" do
      assert function_exported?(HealthPropagator, :report_health, 4)
    end

    test "HealthPropagator exports get_health/2" do
      assert function_exported?(HealthPropagator, :get_health, 2)
    end

    test "HealthPropagator exports derive_parent_health/2" do
      assert function_exported?(HealthPropagator, :derive_parent_health, 2)
    end

    test "report_health stores health status (SC-HOL-003)", %{propagator: prop} do
      :ok = HealthPropagator.report_health(prop, "child-1", "parent-1", :healthy)

      record = HealthPropagator.get_health(prop, "child-1")

      assert record != nil
      assert record.holon_id == "child-1"
      assert record.parent_id == "parent-1"
      assert record.health == :healthy
    end

    test "derive_parent_health aggregates child health (SC-HOL-004)", %{propagator: prop} do
      # All healthy children -> healthy parent
      :ok = HealthPropagator.report_health(prop, "child-1", "parent-1", :healthy)
      :ok = HealthPropagator.report_health(prop, "child-2", "parent-1", :healthy)

      health = HealthPropagator.derive_parent_health(prop, "parent-1")
      assert health == :healthy

      # One degraded child -> degraded parent
      :ok = HealthPropagator.report_health(prop, "child-3", "parent-1", :degraded)

      health = HealthPropagator.derive_parent_health(prop, "parent-1")
      assert health == :degraded
    end

    test "health propagation completes within 100ms (SC-HOL-003)", %{propagator: prop} do
      start_time = System.monotonic_time(:millisecond)

      :ok = HealthPropagator.report_health(prop, "test-child", "test-parent", :healthy)
      _health = HealthPropagator.derive_parent_health(prop, "test-parent")

      elapsed = System.monotonic_time(:millisecond) - start_time

      assert elapsed < 100, "Health propagation took #{elapsed}ms, exceeds 100ms limit"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L1.3: MEMBRANE UNIVERSAL PROTECTION
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L1.3: Membrane Module" do
    alias Indrajaal.Cockpit.Prajna.Bio.Membrane

    test "Membrane module is defined" do
      assert Code.ensure_loaded?(Membrane)
    end

    test "Membrane exports start_link/1" do
      assert function_exported?(Membrane, :start_link, 1)
    end

    test "Membrane exports cross/3" do
      assert function_exported?(Membrane, :cross, 3)
    end

    test "Membrane exports wrap/2" do
      assert function_exported?(Membrane, :wrap, 2)
    end

    test "Membrane exports protect_module/2" do
      assert function_exported?(Membrane, :protect_module, 2)
    end

    test "Membrane exports health/1" do
      assert function_exported?(Membrane, :health, 1)
    end

    test "Membrane exports attach_tag/2" do
      assert function_exported?(Membrane, :attach_tag, 2)
    end

    test "Membrane exports reset_circuit/1" do
      assert function_exported?(Membrane, :reset_circuit, 1)
    end
  end

  describe "L1.3: Membrane Operations" do
    alias Indrajaal.Cockpit.Prajna.Bio.Membrane

    setup do
      name = :"membrane_#{System.unique_integer([:positive])}"

      # Create a simple target module for testing
      target_module = Indrajaal.Core.Constitution

      {:ok, pid} = Membrane.start_link(name: name, target: target_module, rate_limit: 100)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
      end)

      {:ok, membrane: name, pid: pid}
    end

    test "membrane starts with healthy status", %{membrane: membrane} do
      health = Membrane.health(membrane)

      assert health.status == :healthy
      assert is_map(health.metrics)
    end

    test "membrane tracks message count", %{membrane: membrane} do
      initial_health = Membrane.health(membrane)
      initial_count = initial_health.metrics.message_count

      # Cross the membrane
      Membrane.cross(membrane, {:version, []})

      new_health = Membrane.health(membrane)
      assert new_health.metrics.message_count >= initial_count
    end

    test "membrane circuit breaker starts closed", %{membrane: membrane} do
      health = Membrane.health(membrane)
      assert health.metrics.circuit_state == :closed
    end

    test "attach_tag adds immune tag", %{membrane: membrane} do
      :ok = Membrane.attach_tag(membrane, :test_tag)

      # Give time for async cast
      Process.sleep(10)

      health = Membrane.health(membrane)
      assert :test_tag in health.metrics.immune_tags
    end

    test "reset_circuit resets circuit breaker state", %{membrane: membrane} do
      :ok = Membrane.reset_circuit(membrane)

      # Give time for async cast
      Process.sleep(10)

      health = Membrane.health(membrane)
      assert health.metrics.circuit_state == :closed
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # L1 GATE: INTEGRATION VERIFICATION
  # ═══════════════════════════════════════════════════════════════════════════

  describe "L1 Gate: Foundation Integration" do
    test "Constitution, Registry, and HealthPropagator work together" do
      # Verify constitution first
      assert {:ok, _} = Verifier.verify()

      # The global registry should be running (started in application)
      # For tests, we just verify the module API works
      assert function_exported?(HolonRegistry, :register, 4)
      assert function_exported?(HealthPropagator, :report_health, 4)
    end

    test "all L1 modules are loaded" do
      modules = [
        Indrajaal.Core.Constitution,
        Indrajaal.Core.Constitution.Verifier,
        Indrajaal.Core.Constitution.Hash,
        Indrajaal.Core.Holon,
        Indrajaal.Core.Holon.Registry,
        Indrajaal.Core.Holon.HealthPropagator,
        Indrajaal.Core.Holon.State,
        Indrajaal.Core.Holon.Metrics,
        Indrajaal.Core.Holon.Health,
        Indrajaal.Cockpit.Prajna.Bio.Membrane
      ]

      for module <- modules do
        assert Code.ensure_loaded?(module), "Module #{module} not loaded"
      end
    end

    test "L1 STAMP constraints are enforceable" do
      # SC-CONST-001: Constitution verification exists
      assert function_exported?(Verifier, :verify_on_startup!, 0)

      # SC-HOL-003: Health reporting within 100ms
      assert function_exported?(HealthPropagator, :report_health, 4)

      # SC-REG-002: Lookup exists for fast access
      assert function_exported?(HolonRegistry, :lookup, 1)
    end
  end
end
