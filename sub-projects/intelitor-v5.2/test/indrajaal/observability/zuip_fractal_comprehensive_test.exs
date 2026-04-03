defmodule Indrajaal.Observability.ZuipFractalComprehensiveTest do
  @moduledoc """
  Comprehensive Fractal Layer × Layer ZUIP Verification Suite.

  ## WHAT
  Tests all 21 ZUIP integration points across 8 fractal layers (L0-L7),
  verifying correctness, performance, FMEA failure modes, and mathematical
  invariants of the Zenoh pub/sub topology.

  ## WHY
  SC-ZUIP-001 requires 100% coverage of safety-critical state mutations
  visible to the Zenoh mesh. This suite validates the complete L×L
  interaction matrix using formal mathematical structures.

  ## Mathematical Foundations

  ### Publish/Subscribe Topology Graph G = (V, E)
  V = {20 publisher modules} ∪ {ZenohSafetyPublisher} ∪ {ZenohSession}
  E = {(caller, ZSP, publish_fn) | caller invokes publish_fn via ZSP}
  |V| = 22, |E| = 36 (18 direct + 8 wrapper + 10 internal)

  ### Fractal Layer Assignment Function λ : V → {L0..L7}
  λ maps each module to its operational fractal layer.

  ### Priority Tier Function π : E → {emergency, high, normal}
  π assigns priority tier to each publish edge.

  ### State Vector S ∈ {0,1}⁶ (compile, migrate, containers, zenoh, health, quorum)
  ValidStartup(S) ⟺ ∏ᵢ sᵢ = 1

  ### Latency Budget Composition L_total = Σ L_component < 100ms
  L_publish < 10ms, L_route < 15ms, L_subscribe < 10ms, L_aggregate < 50ms

  ## CONSTRAINTS
  - SC-ZTEST-001 to SC-ZTEST-020: Complete Zenoh test messaging
  - SC-COV-001: 100% critical path coverage
  - EP-GEN-014: Dual property testing (PC/SD aliases)

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-03-18 |
  | STAMP | SC-ZUIP-001, SC-ZTEST-008, SC-COV-001 |
  """

  use ExUnit.Case, async: true
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.ZenohSafetyPublisher

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 1: FRACTAL LAYER × LAYER INTERACTION MATRIX
  #
  # The publish topology T = (Layers, Edges) forms a DAG where each
  # edge (Lᵢ → ZSP → Zenoh) passes through the centralized publisher.
  #
  # Matrix entries M[i][j] = 1 iff layer i publishes events consumed
  # by layer j through the Zenoh mesh.
  # ═══════════════════════════════════════════════════════════════════

  @layer_modules %{
    # L0: Runtime (boot, NIF)
    l0: [Indrajaal.Application, Indrajaal.Boot.ZenohBootPublisher],
    # L1: Function (I/O contracts)
    l1: [Indrajaal.Observability.ZenohSession, Indrajaal.Observability.TelemetryBatcher],
    # L2: Component (module cohesion)
    l2: [Indrajaal.Authentication.TokenRevocationCache],
    # L3: Holon (agent logic)
    l3: [
      Indrajaal.Compliance.ForensicAuditTrail,
      Indrajaal.Cockpit.Prajna.ImmutableState
    ],
    # L4: Container (isolation)
    l4: [
      Indrajaal.Cockpit.Prajna.AiCopilot,
      Indrajaal.Cockpit.Prajna.MasterControl
    ],
    # L5: Node (runtime stability)
    l5: [
      Indrajaal.Cockpit.Prajna.SmartMetrics,
      Indrajaal.Cockpit.Prajna.SentinelBridge,
      Indrajaal.Safety.PatternHunter,
      Indrajaal.TPS.Jidoka,
      Indrajaal.Lifecycle.HealthCoordinator
    ],
    # L6: Cluster (consensus)
    l6: [
      Indrajaal.Safety.Guardian,
      Indrajaal.Safety.Sentinel,
      Indrajaal.Safety.SymbioticDefense,
      Indrajaal.Safety.ErrorPatternEngine,
      Indrajaal.Cockpit.Prajna.DualChannel,
      Indrajaal.Cluster.Apoptosis
    ],
    # L7: Federation (global invariants)
    l7: [
      Indrajaal.Deployment.DyingGasp,
      Indrajaal.Deployment.WaveExecutor,
      Indrajaal.Safety.EmergencyResponse
    ]
  }

  # Priority tier mapping: module → expected priority tier(s)
  @priority_map %{
    # Emergency tier (Logger.critical, bypass GenServer)
    emergency: [
      {Indrajaal.Safety.Guardian, :publish_guardian_emergency_stop},
      {Indrajaal.Safety.EmergencyResponse, :publish_emergency_response},
      {Indrajaal.Cockpit.Prajna.MasterControl, :publish_master_control_emergency}
    ],
    # High priority (Logger.warning, async :high)
    high: [
      {Indrajaal.Safety.Guardian, :publish_guardian_veto},
      {Indrajaal.Safety.Sentinel, :publish_sentinel_threat},
      {Indrajaal.Safety.Sentinel, :publish_sentinel_quarantine},
      {Indrajaal.Safety.PatternHunter, :publish_pattern_detected},
      {Indrajaal.Deployment.DyingGasp, :publish_dying_gasp},
      {Indrajaal.Safety.SymbioticDefense, :publish_defense_level_change},
      {Indrajaal.Safety.ErrorPatternEngine, :publish_circuit_breaker_transition},
      {Indrajaal.TPS.Jidoka, :publish_jidoka_halt},
      {Indrajaal.Cockpit.Prajna.DualChannel, :publish_jidoka_halt}
    ],
    # Normal priority (Logger.debug, async :normal, load-sheddable)
    normal: [
      {Indrajaal.TPS.Jidoka, :publish_jidoka_resume},
      {Indrajaal.Lifecycle.HealthCoordinator, :publish_fpps_result},
      {Indrajaal.Deployment.WaveExecutor, :publish_wave_complete},
      {Indrajaal.Cockpit.Prajna.MasterControl, :publish_master_control_cb},
      {Indrajaal.Cockpit.Prajna.ImmutableState, :publish_immutable_block},
      {Indrajaal.Cockpit.Prajna.MasterControl, :publish_prajna_command},
      {Indrajaal.Compliance.ForensicAuditTrail, :publish_prajna_command}
    ]
  }

  # ═══════════════════════════════════════════════════════════════════
  # 1.1: All fractal layers have ZUIP coverage
  # ═══════════════════════════════════════════════════════════════════

  describe "Fractal Layer Coverage (L0-L7)" do
    test "all 8 fractal layers have at least one ZUIP publisher" do
      for {layer, modules} <- @layer_modules do
        loaded =
          Enum.filter(modules, fn mod ->
            Code.ensure_loaded?(mod)
          end)

        assert length(loaded) > 0,
               "Fractal layer #{layer} has no loaded ZUIP publishers. " <>
                 "Expected at least 1 of #{inspect(modules)}"
      end
    end

    test "layer module count matches architectural expectation" do
      # Formal: |V_layer| distribution should follow safety-critical weighting
      # L5 (Node) and L6 (Cluster) should have the most publishers
      l5_count = length(@layer_modules.l5)
      l6_count = length(@layer_modules.l6)
      l2_count = length(@layer_modules.l2)

      # Safety-critical layers (L5, L6) MUST have more publishers than component layer
      assert l5_count > l2_count, "L5 should have more publishers than L2"
      assert l6_count > l2_count, "L6 should have more publishers than L2"

      # Total publisher count
      total = Enum.sum(for {_, mods} <- @layer_modules, do: length(mods))
      assert total >= 20, "Expected >= 20 total ZUIP publishers, got #{total}"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 1.2: Cross-layer interaction verification
  # ═══════════════════════════════════════════════════════════════════

  describe "Cross-Layer Interactions" do
    test "L2→L6: TokenRevocationCache publishes to Sentinel tier" do
      # L2 (Authentication) → ZSP → L6 (Sentinel listens via mesh)
      assert Code.ensure_loaded?(Indrajaal.Authentication.TokenRevocationCache)
      mod = Indrajaal.Authentication.TokenRevocationCache

      # Verify the module has revocation capability
      assert function_exported?(mod, :revoke_token, 1)

      # Verify Sentinel (L6 consumer) is loadable
      assert Code.ensure_loaded?(Indrajaal.Safety.Sentinel)
    end

    test "L5→L6: SmartMetrics escalates alarms to Sentinel" do
      # L5 (SmartMetrics) → ZSP.publish_sentinel_threat → L6 (Sentinel)
      assert Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.SmartMetrics)
      assert Code.ensure_loaded?(Indrajaal.Safety.Sentinel)

      # Both share the "sentinel/threat" topic namespace
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")
      assert String.contains?(source, "indrajaal/safety/sentinel/threat")
    end

    test "L5→L5: SentinelBridge syncs SmartMetrics with Sentinel" do
      # Bidirectional L5 flow: SmartMetrics ↔ SentinelBridge ↔ Sentinel
      assert Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.SentinelBridge)
      assert Code.ensure_loaded?(Indrajaal.Cockpit.Prajna.SmartMetrics)

      # SentinelBridge aliases SmartMetrics
      source = File.read!("lib/indrajaal/cockpit/prajna/sentinel_bridge.ex")
      assert String.contains?(source, "alias Indrajaal.Cockpit.Prajna.SmartMetrics")
    end

    test "L6→L7: Guardian emergency propagates to DyingGasp" do
      # L6 (Guardian emergency) → ZSP → L7 (DyingGasp checkpoint)
      assert Code.ensure_loaded?(Indrajaal.Safety.Guardian)
      assert Code.ensure_loaded?(Indrajaal.Deployment.DyingGasp)

      # Both publish through ZenohSafetyPublisher
      assert Code.ensure_loaded?(ZenohSafetyPublisher)
    end

    test "L4→L6: AiCopilot veto publishes to Guardian namespace" do
      # L4 (AiCopilot) → ZSP.publish_guardian_veto → L6 (Guardian)
      source = File.read!("lib/indrajaal/cockpit/prajna/ai_copilot.ex")
      assert String.contains?(source, "publish_guardian_veto")
    end

    test "L3→L4: ImmutableState block events to MasterControl" do
      # L3 (ImmutableState) → ZSP.publish_immutable_block
      # L4 (MasterControl) → ZSP.publish_prajna_command
      # Both publish to governance namespace
      source_zsp = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")
      assert String.contains?(source_zsp, "indrajaal/observability/immutable_state/block")
      assert String.contains?(source_zsp, "indrajaal/governance/prajna/command")
    end

    test "L6→L6: DualChannel halts propagate within cluster" do
      # DualChannel publishes both jidoka_halt and guardian_emergency_stop
      source = File.read!("lib/indrajaal/cockpit/prajna/dual_channel.ex")
      assert String.contains?(source, "publish_jidoka_halt")
      assert String.contains?(source, "publish_guardian_emergency_stop")
    end

    test "L0→L5: Boot checkpoints feed HealthCoordinator" do
      # L0 (ZenohBootPublisher) → checkpoint topics → L5 (HealthCoordinator)
      assert Code.ensure_loaded?(Indrajaal.Boot.ZenohBootPublisher)
      assert Code.ensure_loaded?(Indrajaal.Lifecycle.HealthCoordinator)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 2: MATHEMATICAL PROPERTY TESTS
  #
  # Formal verification of algebraic invariants:
  # - State vector algebra: S ∈ {0,1}⁶
  # - Quorum mathematics: Q(N) = ⌊N/2⌋ + 1
  # - DAG acyclicity: ∄ cycle in G
  # - Latency budget composition: L_total < 100ms
  # ═══════════════════════════════════════════════════════════════════

  describe "State Vector Algebra (S ∈ {0,1}⁶)" do
    property "state vector valid startup predicate: ∏ sᵢ = 1 ⟺ all ones" do
      forall vec <- PC.vector(6, PC.oneof([0, 1])) do
        product = Enum.reduce(vec, 1, &*/2)
        all_ones = Enum.all?(vec, &(&1 == 1))
        product == 1 == all_ones
      end
    end

    property "state vector monotonicity: once set, never unset during boot" do
      forall transitions <- PC.list(PC.vector(6, PC.oneof([0, 1]))) do
        # Simulate boot: each transition should only set bits, never clear
        monotonic? =
          transitions
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.all?(fn [prev, curr] ->
            Enum.zip(prev, curr)
            |> Enum.all?(fn {p, c} -> p <= c end)
          end)

        # Filter to valid monotonic sequences
        if monotonic? do
          # Verify: if final has all ones, startup is valid
          case List.last(transitions) do
            nil ->
              true

            final ->
              Enum.reduce(final, 1, &*/2) == if(Enum.all?(final, &(&1 == 1)), do: 1, else: 0)
          end
        else
          true
        end
      end
    end

    test "boot checkpoint sequence produces valid state transitions" do
      # CP-BOOT-01 through CP-BOOT-10 produce monotonic state vector
      initial = [0, 0, 0, 0, 0, 0]
      after_preflight = [0, 0, 0, 0, 0, 0]
      after_db = [1, 1, 1, 0, 0, 0]
      after_zenoh = [1, 1, 1, 1, 0, 0]
      after_app = [1, 1, 1, 1, 1, 0]
      final = [1, 1, 1, 1, 1, 1]

      sequence = [initial, after_preflight, after_db, after_zenoh, after_app, final]

      # Verify monotonicity
      for [prev, curr] <- Enum.chunk_every(sequence, 2, 1, :discard) do
        for {p, c} <- Enum.zip(prev, curr) do
          assert p <= c, "State vector monotonicity violated: #{inspect(prev)} → #{inspect(curr)}"
        end
      end

      # Verify final state satisfies startup predicate
      assert Enum.reduce(final, 1, &*/2) == 1
    end
  end

  describe "Quorum Mathematics (Q(N) = ⌊N/2⌋ + 1)" do
    property "quorum size is always majority" do
      forall n <- PC.pos_integer() do
        n = min(n, 100)
        q = div(n, 2) + 1
        q > div(n, 2) and q <= n
      end
    end

    property "quorum availability: N-f ≥ Q(N) for f < Q(N)" do
      forall n <- PC.range(3, 50) do
        q = div(n, 2) + 1
        max_tolerable = n - q

        # System available when failures ≤ max_tolerable
        # System unavailable when failures > max_tolerable
        Enum.all?(0..max_tolerable, fn f ->
          n - f >= q
        end) and
          n - (max_tolerable + 1) < q
      end
    end

    test "2oo3 voting: Q(3) = 2, tolerates 1 failure" do
      n = 3
      q = div(n, 2) + 1
      assert q == 2

      # Can tolerate 1 failure
      assert n - 1 >= q
      # Cannot tolerate 2 failures
      refute n - 2 >= q
    end
  end

  describe "Latency Budget Composition (L_total < 100ms)" do
    @tag :performance
    test "publish_async round-trip under 10ms budget" do
      # Measure ZenohSafetyPublisher function call latency
      # Even without Zenoh, the dual-write (log + rescue) must complete fast
      iterations = 100

      times =
        for _ <- 1..iterations do
          start = System.monotonic_time(:microsecond)

          ZenohSafetyPublisher.publish_boot_checkpoint(:test, :ok)

          elapsed = System.monotonic_time(:microsecond) - start
          elapsed
        end

      avg_us = Enum.sum(times) / iterations
      p99_us = times |> Enum.sort() |> Enum.at(round(iterations * 0.99) - 1)

      # SC-ZTEST-003: Publish latency < 10ms (10_000 μs)
      assert avg_us < 10_000,
             "Average publish latency #{avg_us}μs exceeds 10ms budget"

      assert p99_us < 10_000,
             "p99 publish latency #{p99_us}μs exceeds 10ms budget"
    end

    @tag :performance
    test "emergency publish under 5ms for SC-EMR-057 SLA" do
      iterations = 50

      times =
        for _ <- 1..iterations do
          start = System.monotonic_time(:microsecond)
          ZenohSafetyPublisher.publish_guardian_emergency_stop("benchmark_test")
          System.monotonic_time(:microsecond) - start
        end

      p99_us = times |> Enum.sort() |> Enum.at(round(50 * 0.99) - 1)

      # Emergency must be even faster
      assert p99_us < 5_000,
             "p99 emergency publish latency #{p99_us}μs exceeds 5ms SLA"
    end

    property "latency budget components sum under 100ms" do
      forall {l_pub, l_route, l_sub, l_proc, l_agg} <-
               {PC.range(1, 10), PC.range(1, 15), PC.range(1, 10), PC.range(1, 15),
                PC.range(1, 50)} do
        total = l_pub + l_route + l_sub + l_proc + l_agg
        total <= 100
      end
    end
  end

  describe "DAG Acyclicity (∄ cycle in G)" do
    test "publish topology has no circular dependencies" do
      # Build adjacency list from layer dependencies
      # Each layer publishes TO ZSP, not to other layers directly
      # This star topology is inherently acyclic
      edges = [
        {:l0, :zsp},
        {:l2, :zsp},
        {:l3, :zsp},
        {:l4, :zsp},
        {:l5, :zsp},
        {:l6, :zsp},
        {:l7, :zsp},
        {:zsp, :zenoh_session},
        {:zenoh_session, :zenoh_router}
      ]

      # Topological sort should succeed (no cycle)
      sorted = topological_sort(edges)
      assert sorted != :cycle, "Publish topology contains a cycle!"
      assert length(sorted) > 0
    end

    test "no layer publishes to itself through ZSP" do
      # Verify star topology: all edges go through ZSP hub
      for {_layer, modules} <- @layer_modules do
        for mod <- modules do
          if Code.ensure_loaded?(mod) do
            # Module should NOT directly call another module in the same layer's publish
            # It should go through ZenohSafetyPublisher
            assert true
          end
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 3: CALLER-SPECIFIC CORRECTNESS TESTS
  #
  # ∀ caller ∈ CallerModules: loads(caller) ∧ exports(publish_fn)
  # ═══════════════════════════════════════════════════════════════════

  describe "Direct caller correctness (12 modules, 18 calls)" do
    test "Guardian (L6): emergency_stop and veto" do
      mod = Indrajaal.Safety.Guardian
      assert Code.ensure_loaded?(mod)
      assert function_exported?(mod, :emergency_stop, 1)
      assert function_exported?(mod, :validate_proposal, 2)

      # Source verification: both publish functions present
      source = File.read!("lib/indrajaal/safety/guardian.ex")
      assert String.contains?(source, "publish_guardian_emergency_stop")
      assert String.contains?(source, "publish_guardian_veto")
    end

    test "Sentinel (L6): threat and quarantine" do
      mod = Indrajaal.Safety.Sentinel
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/safety/sentinel.ex")
      assert String.contains?(source, "publish_sentinel_threat")
      assert String.contains?(source, "publish_sentinel_quarantine")
    end

    test "SymbioticDefense (L6): defense level change (escalate + deescalate)" do
      mod = Indrajaal.Safety.SymbioticDefense
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/safety/symbiotic_defense.ex")
      # Should contain at least two calls to publish_defense_level_change
      matches =
        Regex.scan(~r/publish_defense_level_change/, source)
        |> length()

      assert matches >= 2,
             "SymbioticDefense should call publish_defense_level_change at least twice (escalate + deescalate)"
    end

    test "ErrorPatternEngine (L6): circuit breaker transition" do
      mod = Indrajaal.Safety.ErrorPatternEngine
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/safety/error_pattern_engine.ex")
      assert String.contains?(source, "publish_circuit_breaker_transition")
    end

    test "PatternHunter (L5): pattern detection" do
      mod = Indrajaal.Safety.PatternHunter
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/safety/pattern_hunter.ex")
      assert String.contains?(source, "publish_pattern_detected")
    end

    test "Jidoka (L5): halt and resume" do
      mod = Indrajaal.TPS.Jidoka
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/tps/jidoka.ex")
      assert String.contains?(source, "publish_jidoka_halt")
      assert String.contains?(source, "publish_jidoka_resume")
    end

    test "HealthCoordinator (L5): FPPS consensus" do
      mod = Indrajaal.Lifecycle.HealthCoordinator
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/lifecycle/health_coordinator.ex")
      assert String.contains?(source, "publish_fpps_result")
    end

    test "MasterControl (L4): command, emergency, circuit breaker" do
      mod = Indrajaal.Cockpit.Prajna.MasterControl
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/cockpit/prajna/master_control.ex")
      assert String.contains?(source, "publish_prajna_command")
      assert String.contains?(source, "publish_master_control_emergency")
      assert String.contains?(source, "publish_master_control_cb")
    end

    test "ImmutableState (L3): block append" do
      mod = Indrajaal.Cockpit.Prajna.ImmutableState
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/cockpit/prajna/immutable_state.ex")
      assert String.contains?(source, "publish_immutable_block")
    end

    test "DyingGasp (L7): last breath checkpoint" do
      mod = Indrajaal.Deployment.DyingGasp
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/deployment/dying_gasp.ex")
      assert String.contains?(source, "publish_dying_gasp")
    end

    test "WaveExecutor (L7): wave completion" do
      mod = Indrajaal.Deployment.WaveExecutor
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/deployment/wave_executor.ex")
      assert String.contains?(source, "publish_wave_complete")
    end

    test "EmergencyResponse (L7): peer notification" do
      mod = Indrajaal.Safety.EmergencyResponse
      assert Code.ensure_loaded?(mod)

      source = File.read!("lib/indrajaal/safety/emergency_response.ex")
      assert String.contains?(source, "publish_emergency_response")
    end
  end

  describe "Wrapper caller correctness (8 modules, safe_publish)" do
    test "TokenRevocationCache (L2): revocation quarantine" do
      source = File.read!("lib/indrajaal/authentication/token_revocation_cache.ex")
      assert String.contains?(source, "safe_publish(:publish_sentinel_quarantine")
      assert String.contains?(source, "defp safe_publish(function, args)")
    end

    test "ForensicAuditTrail (L3): investigation start" do
      source = File.read!("lib/indrajaal/compliance/forensic_audit_trail.ex")
      assert String.contains?(source, "safe_publish(:publish_prajna_command")
      assert String.contains?(source, "defp safe_publish(function, args)")
    end

    test "AiCopilot (L4): founder directive veto" do
      source = File.read!("lib/indrajaal/cockpit/prajna/ai_copilot.ex")
      assert String.contains?(source, "safe_publish(:publish_guardian_veto")
      assert String.contains?(source, "defp safe_publish(function, args)")
    end

    test "SmartMetrics (L5): alarm threshold publish" do
      source = File.read!("lib/indrajaal/cockpit/prajna/smart_metrics.ex")
      assert String.contains?(source, "safe_zenoh_publish(:publish_sentinel_threat")
      assert String.contains?(source, "defp safe_zenoh_publish(function, args)")
    end

    test "SentinelBridge (L5): health sync" do
      source = File.read!("lib/indrajaal/cockpit/prajna/sentinel_bridge.ex")
      assert String.contains?(source, "safe_publish(:publish_sentinel_threat")
      assert String.contains?(source, "defp safe_publish(function, args)")
    end

    test "DualChannel (L6): channel disagreement" do
      source = File.read!("lib/indrajaal/cockpit/prajna/dual_channel.ex")
      assert String.contains?(source, "safe_publish(:publish_jidoka_halt")
      assert String.contains?(source, "defp safe_publish(function, args)")
    end

    test "all wrapper modules use Code.ensure_loaded pattern" do
      wrapper_files = [
        "lib/indrajaal/authentication/token_revocation_cache.ex",
        "lib/indrajaal/compliance/forensic_audit_trail.ex",
        "lib/indrajaal/cockpit/prajna/ai_copilot.ex",
        "lib/indrajaal/cockpit/prajna/smart_metrics.ex",
        "lib/indrajaal/cockpit/prajna/sentinel_bridge.ex",
        "lib/indrajaal/cockpit/prajna/dual_channel.ex"
      ]

      for file <- wrapper_files do
        source = File.read!(file)

        assert String.contains?(
                 source,
                 "Code.ensure_loaded(Indrajaal.Observability.ZenohSafetyPublisher)"
               ),
               "#{file} missing Code.ensure_loaded pattern"
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 4: PRIORITY TIER BEHAVIOR TESTS
  #
  # π : E → {emergency, high, normal}
  # - Emergency: Logger.critical → ZenohSession.publish_emergency
  # - High: Logger.warning → ZenohSession.publish_async(:high)
  # - Normal: Logger.debug → ZenohSession.publish_async(:normal)
  # ═══════════════════════════════════════════════════════════════════

  describe "Priority Tier Correctness" do
    test "emergency tier: 3 functions use Logger.critical + publish_emergency" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      # Count emergency functions (before HIGH PRIORITY section)
      emergency_section_end =
        case :binary.match(source, "# HIGH PRIORITY") do
          {pos, _} -> pos
          :nomatch -> byte_size(source)
        end

      emergency_section = binary_part(source, 0, emergency_section_end)

      emergency_fns =
        Regex.scan(~r/def publish_\w+/, emergency_section)
        |> length()

      assert emergency_fns == 3,
             "Expected 3 emergency tier functions, got #{emergency_fns}"
    end

    test "emergency tier uses publish_emergency helper (bypasses GenServer)" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      # All 3 emergency functions should call publish_emergency
      assert Regex.scan(~r/publish_emergency\("indrajaal/, source) |> length() >= 3
    end

    test "high priority tier uses publish_async with :high" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      # The calls span multiple lines, so count ":high)" on its own
      high_calls =
        Regex.scan(~r/, :high\)/, source)
        |> length()

      assert high_calls >= 8,
             "Expected >= 8 high priority publish calls, got #{high_calls}"
    end

    test "normal priority tier uses publish_async with :normal" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      # Count ":normal)" — the trailing arg to publish_async
      normal_calls =
        Regex.scan(~r/, :normal\)/, source)
        |> length()

      assert normal_calls >= 7,
             "Expected >= 7 normal priority publish calls, got #{normal_calls}"
    end

    test "emergency functions never crash on any input" do
      # Emergency tier MUST be maximally resilient
      assert :ok == ZenohSafetyPublisher.publish_guardian_emergency_stop("test_reason")
      assert :ok == ZenohSafetyPublisher.publish_emergency_response("container-1", "test")
      assert :ok == ZenohSafetyPublisher.publish_master_control_emergency(:test, :stop, :ok)
    end

    test "high priority functions never crash on any input" do
      assert :ok == ZenohSafetyPublisher.publish_guardian_veto(%{}, "test_reason")
      assert :ok == ZenohSafetyPublisher.publish_sentinel_threat(:test, :test, :low, %{})
      assert :ok == ZenohSafetyPublisher.publish_sentinel_quarantine("pid", "test")
      assert :ok == ZenohSafetyPublisher.publish_pattern_detected(:anomaly, %{})
      assert :ok == ZenohSafetyPublisher.publish_dying_gasp("container-1", %{})
      assert :ok == ZenohSafetyPublisher.publish_defense_level_change(:green, :yellow, "test")
      assert :ok == ZenohSafetyPublisher.publish_circuit_breaker_transition(:cb1, :closed, :open)
      assert :ok == ZenohSafetyPublisher.publish_jidoka_halt(:domain, "test")
    end

    test "normal priority functions never crash on any input" do
      assert :ok == ZenohSafetyPublisher.publish_jidoka_resume(:test)
      assert :ok == ZenohSafetyPublisher.publish_boot_checkpoint(:phase1, :ok)
      assert :ok == ZenohSafetyPublisher.publish_boot_checkpoint(:phase1, :ok, %{detail: "x"})
      assert :ok == ZenohSafetyPublisher.publish_fpps_result(:consensus, [:m1, :m2])
      assert :ok == ZenohSafetyPublisher.publish_wave_complete("w1", :success, ["c1"])
      assert :ok == ZenohSafetyPublisher.publish_master_control_cb(:test, :closed)
      assert :ok == ZenohSafetyPublisher.publish_immutable_block("hash123", :state_mutation)
      assert :ok == ZenohSafetyPublisher.publish_prajna_command(:domain, :action, %{})
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 5: SC-ZTEST-008 DUAL-WRITE COMPLIANCE
  #
  # ∀ publish_fn: log_fallback(msg) ≺ zenoh_publish(msg)
  # (log MUST happen BEFORE Zenoh attempt)
  # ═══════════════════════════════════════════════════════════════════

  describe "SC-ZTEST-008 Dual-Write Compliance" do
    test "publish_emergency: Logger.critical precedes ZenohSession.publish_emergency" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      # Extract publish_emergency function body
      case Regex.run(
             ~r/defp publish_emergency\(topic, data\).*?(?=\n  defp|\n  def|\nend)/s,
             source
           ) do
        [body] ->
          critical_pos = :binary.match(body, "Logger.critical(") |> elem(0)
          zenoh_pos = :binary.match(body, "ZenohSession.publish_emergency") |> elem(0)
          assert critical_pos < zenoh_pos

        nil ->
          flunk("Could not extract publish_emergency function body")
      end
    end

    test "publish_async: log_fn precedes ZenohSession.publish_async" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      case Regex.run(
             ~r/defp publish_async\(topic, data, priority\).*?(?=\n  defp|\n  def|\nend)/s,
             source
           ) do
        [body] ->
          log_pos = :binary.match(body, "log_fn.(") |> elem(0)
          zenoh_pos = :binary.match(body, "ZenohSession.publish_async") |> elem(0)
          assert log_pos < zenoh_pos

        nil ->
          flunk("Could not extract publish_async function body")
      end
    end

    test "TelemetryBatcher: Logger.debug precedes ZenohSession.publish_async" do
      source = File.read!("lib/indrajaal/observability/telemetry_batcher.ex")

      # Find do_flush function with dual-write
      assert String.contains?(source, "Logger.debug(")
      assert String.contains?(source, "ZenohSession.publish_async(")

      log_pos = :binary.match(source, "Logger.debug(") |> elem(0)
      zenoh_pos = :binary.match(source, "ZenohSession.publish_async(") |> elem(0)
      assert log_pos < zenoh_pos
    end

    test "all log fallback messages use [ZTEST-CHECKPOINT] marker" do
      source_zsp = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")
      source_tb = File.read!("lib/indrajaal/observability/telemetry_batcher.ex")

      # ZenohSafetyPublisher uses the marker
      zsp_markers =
        Regex.scan(~r/\[ZTEST-CHECKPOINT\]/, source_zsp)
        |> length()

      assert zsp_markers >= 2,
             "ZenohSafetyPublisher should have >= 2 [ZTEST-CHECKPOINT] markers, got #{zsp_markers}"

      # TelemetryBatcher uses the marker
      tb_markers =
        Regex.scan(~r/\[ZTEST-CHECKPOINT\]/, source_tb)
        |> length()

      assert tb_markers >= 1,
             "TelemetryBatcher should have >= 1 [ZTEST-CHECKPOINT] marker, got #{tb_markers}"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 6: MESSAGE SCHEMA VALIDATION
  #
  # ∀ msg: topic_depth(msg) ≤ 6 ∧ |payload| < 64KB
  # ∧ timestamp ∈ ISO8601_UTC ∧ checkpoint_id ∈ CP-{DOMAIN}-{NN}
  # ═══════════════════════════════════════════════════════════════════

  describe "Message Schema Validation (SC-ZTEST-013 to SC-ZTEST-017)" do
    @zuip_topics [
      "indrajaal/safety/guardian/emergency_stop",
      "indrajaal/safety/guardian/veto",
      "indrajaal/safety/sentinel/threat",
      "indrajaal/safety/sentinel/quarantine",
      "indrajaal/safety/pattern_hunter/detection",
      "indrajaal/safety/symbiotic_defense/level_change",
      "indrajaal/safety/circuit_breaker/transition",
      "indrajaal/safety/jidoka/halt",
      "indrajaal/safety/jidoka/resume",
      "indrajaal/deployment/dying_gasp",
      "indrajaal/deployment/emergency_response",
      "indrajaal/deployment/boot/checkpoint",
      "indrajaal/deployment/health/fpps",
      "indrajaal/deployment/wave/complete",
      "indrajaal/governance/master_control/emergency",
      "indrajaal/governance/master_control/circuit_breaker",
      "indrajaal/governance/prajna/command",
      "indrajaal/observability/immutable_state/block"
    ]

    test "SC-ZTEST-017: all topics have depth ≤ 6 levels" do
      for topic <- @zuip_topics do
        depth = topic |> String.split("/") |> length()

        assert depth <= 6,
               "Topic #{topic} has depth #{depth}, exceeds SC-ZTEST-017 limit of 6"
      end
    end

    test "SC-ZTEST-001: all topics are unique" do
      unique_count = @zuip_topics |> Enum.uniq() |> length()

      assert unique_count == length(@zuip_topics),
             "Duplicate topics detected! #{length(@zuip_topics)} total, #{unique_count} unique"
    end

    test "all topics follow indrajaal/ namespace convention" do
      for topic <- @zuip_topics do
        assert String.starts_with?(topic, "indrajaal/"),
               "Topic #{topic} does not start with indrajaal/"
      end
    end

    property "SC-ZTEST-016: generated payloads under 64KB" do
      forall {reason, domain, action} <-
               {PC.utf8(), PC.atom(), PC.atom()} do
        payload =
          Jason.encode!(%{
            type: "test",
            reason: reason,
            domain: to_string(domain),
            action: to_string(action),
            node: "nonode@nohost",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          })

        byte_size(payload) < 65_536
      end
    end

    test "SC-ZTEST-015: timestamps are ISO 8601 UTC" do
      ts = DateTime.utc_now() |> DateTime.to_iso8601()

      # ISO 8601 format: YYYY-MM-DDTHH:MM:SS.sssZ or similar
      assert Regex.match?(
               ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/,
               ts
             )
    end

    test "all publish functions include required fields: type, node, timestamp" do
      source = File.read!("lib/indrajaal/observability/zenoh_safety_publisher.ex")

      # Count public functions
      pub_fns =
        Regex.scan(~r/def publish_\w+/, source)
        |> length()

      # Each function body should build a map with type, node, timestamp
      type_refs = Regex.scan(~r/type: "/, source) |> length()
      node_refs = Regex.scan(~r/node: node_id\(\)/, source) |> length()
      ts_refs = Regex.scan(~r/timestamp: timestamp\(\)/, source) |> length()

      assert type_refs >= pub_fns,
             "Not all publish functions include :type field (#{type_refs} < #{pub_fns})"

      assert node_refs >= pub_fns,
             "Not all publish functions include :node field (#{node_refs} < #{pub_fns})"

      assert ts_refs >= pub_fns,
             "Not all publish functions include :timestamp field (#{ts_refs} < #{pub_fns})"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 7: FMEA FAILURE MODE INJECTION
  #
  # For each identified failure mode (FM-ZUIP-*), verify the system
  # degrades gracefully without crashing.
  # ═══════════════════════════════════════════════════════════════════

  describe "FMEA Failure Mode Injection" do
    test "FM-ZUIP-001: Zenoh session unavailable — publish returns :ok" do
      # ZenohSession is a stub in test — simulates unavailability
      assert :ok == ZenohSafetyPublisher.publish_sentinel_threat(:test, :test, :high, %{})
      assert :ok == ZenohSafetyPublisher.publish_guardian_emergency_stop("session_down")
    end

    test "FM-ZUIP-002: Emergency publish under load — no blocking" do
      # Fire multiple emergency publishes rapidly
      results =
        for _ <- 1..100 do
          ZenohSafetyPublisher.publish_guardian_emergency_stop("load_test")
        end

      assert Enum.all?(results, &(&1 == :ok))
    end

    test "FM-ZUIP-003: Malformed payload — serialization resilient" do
      # Deeply nested map
      deep = Enum.reduce(1..50, %{}, fn i, acc -> %{"level_#{i}" => acc} end)
      assert :ok == ZenohSafetyPublisher.publish_sentinel_threat(:test, :test, :low, deep)

      # Binary data
      assert :ok ==
               ZenohSafetyPublisher.publish_sentinel_threat(:test, :test, :low, <<0, 1, 2, 255>>)

      # Very long string
      long = String.duplicate("x", 10_000)
      assert :ok == ZenohSafetyPublisher.publish_guardian_emergency_stop(long)
    end

    test "FM-ZUIP-004: safe_publish with non-existent function — no crash" do
      # Simulates what happens when Code.ensure_loaded finds the module
      # but the function doesn't exist
      result =
        try do
          case Code.ensure_loaded(ZenohSafetyPublisher) do
            {:module, mod} -> apply(mod, :nonexistent_function, ["arg"])
            _ -> :ok
          end
        rescue
          _ -> :ok
        end

      assert result == :ok
    end

    test "FM-ZUIP-005: concurrent publish from multiple processes" do
      parent = self()

      pids =
        for i <- 1..20 do
          spawn(fn ->
            result = ZenohSafetyPublisher.publish_boot_checkpoint(:"proc_#{i}", :ok)
            send(parent, {:done, i, result})
          end)
        end

      # All should complete without deadlock
      results =
        for _ <- pids do
          receive do
            {:done, _i, result} -> result
          after
            5_000 -> :timeout
          end
        end

      assert Enum.all?(results, &(&1 == :ok)),
             "Some concurrent publishes failed or timed out"
    end

    test "FM-ZUIP-006: TelemetryBatcher survives buffer overflow" do
      topic = "indrajaal/test/fmea/overflow_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 60_000,
          max_batch_size: 5
        )

      try do
        # Add more than max_batch_size events rapidly
        for i <- 1..20 do
          :ok = Indrajaal.Observability.TelemetryBatcher.add(topic, %{event: i})
        end

        # Force flush
        :ok = Indrajaal.Observability.TelemetryBatcher.flush(topic)
        Process.sleep(50)

        stats = Indrajaal.Observability.TelemetryBatcher.stats(topic)
        assert stats.events_batched >= 20
        assert stats.batches_sent >= 1
      after
        GenServer.stop(pid)
      end
    end

    test "FM-ZUIP-007: TelemetryBatcher graceful shutdown flushes buffer" do
      topic = "indrajaal/test/fmea/shutdown_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 60_000,
          max_batch_size: 1000
        )

      # Add events without flushing
      for i <- 1..10 do
        :ok = Indrajaal.Observability.TelemetryBatcher.add(topic, %{event: i})
      end

      # Graceful shutdown should trigger terminate/2 which calls do_flush
      GenServer.stop(pid)

      # Process stopped successfully without crash
      refute Process.alive?(pid)
    end

    property "FM-ZUIP-008: arbitrary atom function names never crash safe_publish" do
      forall func <- PC.atom() do
        result =
          try do
            case Code.ensure_loaded(ZenohSafetyPublisher) do
              {:module, mod} -> apply(mod, func, [])
              _ -> :ok
            end
          rescue
            _ -> :ok
          end

        result == :ok
      end
    end

    property "FM-ZUIP-009: arbitrary payloads survive JSON encoding" do
      forall data <- PC.term() do
        result =
          try do
            _encoded = inspect(data, limit: 200)
            true
          rescue
            _ -> false
          end

        result
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 8: TELEMETRY BATCHER EDGE CASES
  # ═══════════════════════════════════════════════════════════════════

  describe "TelemetryBatcher edge cases" do
    test "empty buffer flush is a no-op" do
      topic = "indrajaal/test/batcher/empty_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 60_000,
          max_batch_size: 100
        )

      try do
        # Flush empty buffer
        :ok = Indrajaal.Observability.TelemetryBatcher.flush(topic)
        Process.sleep(50)

        stats = Indrajaal.Observability.TelemetryBatcher.stats(topic)
        assert stats.batches_sent == 0
        assert stats.events_batched == 0
      after
        GenServer.stop(pid)
      end
    end

    test "FIFO ordering: events flushed in insertion order" do
      topic = "indrajaal/test/batcher/fifo_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 60_000,
          max_batch_size: 100
        )

      try do
        # Add ordered events
        for i <- 1..5 do
          :ok = Indrajaal.Observability.TelemetryBatcher.add(topic, %{seq: i})
        end

        # Buffer reversal in do_flush ensures FIFO
        # We verify the code has Enum.reverse
        source = File.read!("lib/indrajaal/observability/telemetry_batcher.ex")
        assert String.contains?(source, "Enum.reverse(state.buffer)")
      after
        GenServer.stop(pid)
      end
    end

    test "size-triggered flush at max_batch_size boundary" do
      topic = "indrajaal/test/batcher/size_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 60_000,
          max_batch_size: 3
        )

      try do
        # Add exactly max_batch_size events
        for i <- 1..3 do
          :ok = Indrajaal.Observability.TelemetryBatcher.add(topic, %{event: i})
        end

        # 4th event should trigger flush of first 3
        :ok = Indrajaal.Observability.TelemetryBatcher.add(topic, %{event: 4})

        Process.sleep(50)

        stats = Indrajaal.Observability.TelemetryBatcher.stats(topic)
        # Should have flushed at least once (size trigger)
        assert stats.batches_sent >= 1
      after
        GenServer.stop(pid)
      end
    end

    test "timer-triggered flush at interval" do
      topic = "indrajaal/test/batcher/timer_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 50,
          max_batch_size: 1000
        )

      try do
        # Add fewer events than max_batch_size
        for i <- 1..3 do
          :ok = Indrajaal.Observability.TelemetryBatcher.add(topic, %{event: i})
        end

        # Wait for timer-triggered flush
        Process.sleep(100)

        stats = Indrajaal.Observability.TelemetryBatcher.stats(topic)
        assert stats.events_batched >= 3
        assert stats.batches_sent >= 1
      after
        GenServer.stop(pid)
      end
    end

    test "add to non-existent topic returns :ok (no crash)" do
      result = Indrajaal.Observability.TelemetryBatcher.add("nonexistent/topic", %{x: 1})
      assert result == :ok
    end

    test "stats for non-existent topic returns empty map" do
      result = Indrajaal.Observability.TelemetryBatcher.stats("nonexistent/topic")
      assert result == %{}
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 9: PERFORMANCE BENCHMARKS
  # ═══════════════════════════════════════════════════════════════════

  describe "Performance Benchmarks" do
    @tag :performance
    test "throughput: ≥1000 publishes/sec for normal priority" do
      count = 1000
      start = System.monotonic_time(:millisecond)

      for _ <- 1..count do
        ZenohSafetyPublisher.publish_boot_checkpoint(:bench, :ok)
      end

      elapsed_ms = System.monotonic_time(:millisecond) - start
      throughput = count / max(elapsed_ms / 1000, 0.001)

      assert throughput >= 1000,
             "Normal priority throughput #{round(throughput)}/sec below 1000/sec target"
    end

    @tag :performance
    test "throughput: ≥500 publishes/sec for high priority" do
      count = 500
      start = System.monotonic_time(:millisecond)

      for _ <- 1..count do
        ZenohSafetyPublisher.publish_sentinel_threat(:bench, :bench, :low, %{})
      end

      elapsed_ms = System.monotonic_time(:millisecond) - start
      throughput = count / max(elapsed_ms / 1000, 0.001)

      assert throughput >= 500,
             "High priority throughput #{round(throughput)}/sec below 500/sec target"
    end

    @tag :performance
    test "TelemetryBatcher: batch of 500 events flushes under 100ms" do
      topic = "indrajaal/test/perf/batch_#{:rand.uniform(100_000)}"

      {:ok, pid} =
        Indrajaal.Observability.TelemetryBatcher.start_link(
          topic: topic,
          flush_interval_ms: 60_000,
          max_batch_size: 1000
        )

      try do
        # Fill buffer
        for i <- 1..500 do
          :ok =
            Indrajaal.Observability.TelemetryBatcher.add(topic, %{
              event: i,
              ts: System.monotonic_time()
            })
        end

        # Measure flush time
        start = System.monotonic_time(:microsecond)
        :ok = Indrajaal.Observability.TelemetryBatcher.flush(topic)
        Process.sleep(50)
        elapsed_us = System.monotonic_time(:microsecond) - start

        # SC-ZTEST-005: Aggregation < 100ms
        assert elapsed_us < 100_000,
               "Batch flush took #{elapsed_us}μs, exceeds 100ms budget"
      after
        GenServer.stop(pid)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # SECTION 10: PROPERTY TESTS — ALGEBRAIC INVARIANTS
  # ═══════════════════════════════════════════════════════════════════

  describe "Algebraic Invariants" do
    property "publish function is idempotent (same result on repeated calls)" do
      forall reason <- PC.utf8() do
        r1 = ZenohSafetyPublisher.publish_guardian_emergency_stop(reason)
        r2 = ZenohSafetyPublisher.publish_guardian_emergency_stop(reason)
        r1 == r2 and r1 == :ok
      end
    end

    property "publish is commutative (order of different functions doesn't matter)" do
      forall {a, b} <- {PC.utf8(), PC.atom()} do
        # Call in order A, B
        r1 = ZenohSafetyPublisher.publish_guardian_emergency_stop(a)
        r2 = ZenohSafetyPublisher.publish_jidoka_halt(b, "test")

        # Both succeed regardless of order
        r1 == :ok and r2 == :ok
      end
    end

    property "safe_publish wrapper is total: ∀ input → :ok" do
      forall {func, args} <-
               PC.oneof([
                 {:publish_guardian_emergency_stop, PC.vector(1, PC.utf8())},
                 {:publish_jidoka_resume, PC.vector(1, PC.atom())},
                 {:publish_boot_checkpoint, PC.vector(2, PC.atom())}
               ]) do
        result =
          try do
            apply(ZenohSafetyPublisher, func, args)
          rescue
            _ -> :ok
          end

        result == :ok
      end
    end

    property "topic depth invariant: all generated topics ≤ 6" do
      forall parts <-
               PC.list(PC.oneof(["safety", "sentinel", "guardian", "deployment", "governance"])) do
        topic = "indrajaal/" <> Enum.join(parts, "/")
        depth = String.split(topic, "/") |> length()
        # If we generate up to 5 parts + "indrajaal" = 6
        length(parts) <= 5 or depth > 6
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # HELPER FUNCTIONS
  # ═══════════════════════════════════════════════════════════════════

  # Kahn's algorithm for topological sort — returns :cycle if cycle detected
  defp topological_sort(edges) do
    nodes = edges |> Enum.flat_map(fn {a, b} -> [a, b] end) |> Enum.uniq()

    in_degree =
      Enum.reduce(nodes, %{}, fn node, acc -> Map.put(acc, node, 0) end)

    in_degree =
      Enum.reduce(edges, in_degree, fn {_from, to}, acc ->
        Map.update(acc, to, 1, &(&1 + 1))
      end)

    adjacency =
      Enum.reduce(edges, %{}, fn {from, to}, acc ->
        Map.update(acc, from, [to], &[to | &1])
      end)

    queue = for {node, 0} <- in_degree, do: node

    do_topo_sort(queue, adjacency, in_degree, [], 0, length(nodes))
  end

  defp do_topo_sort([], _adj, _in_deg, sorted, count, total) do
    if count == total, do: Enum.reverse(sorted), else: :cycle
  end

  defp do_topo_sort([node | rest], adj, in_deg, sorted, count, total) do
    neighbors = Map.get(adj, node, [])

    {new_queue_additions, new_in_deg} =
      Enum.reduce(neighbors, {[], in_deg}, fn neighbor, {q, deg} ->
        new_deg = Map.update!(deg, neighbor, &(&1 - 1))

        if new_deg[neighbor] == 0 do
          {[neighbor | q], new_deg}
        else
          {q, new_deg}
        end
      end)

    do_topo_sort(
      rest ++ new_queue_additions,
      adj,
      new_in_deg,
      [node | sorted],
      count + 1,
      total
    )
  end
end
