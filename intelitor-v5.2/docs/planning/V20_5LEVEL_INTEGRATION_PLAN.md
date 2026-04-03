# Indrajaal v20: 5-Level Cybernetic Organism Integration Plan

**Version**: 20.1.0
**Date**: 2025-12-30
**Status**: DEFINITIVE INTEGRATION BLUEPRINT
**Classification**: ARCHITECTURAL EXECUTION PLAN

---

## Executive Summary

This document provides the detailed 5-level integration plan to fully realize the **Cybernetic Organism** vision from `INDRAJAAL_V20_MASTER_PLAN.md`. Each level corresponds to a biological/fractal layer of the organism, with specific integration tasks, verification gates, and STAMP constraints.

### Current State Assessment

| Component | Status | Lines | Tests |
|-----------|--------|-------|-------|
| AU-01 OpenRouter Adapter | SKELETON | 1,084 | 3 files |
| AU-15 Zenoh Nervous System | SKELETON | 1,113 | 3 files |
| AU-02 Gravity Routing | SKELETON | 679 | 2 files |
| AU-07 Pre-Roll Buffer | SKELETON | 629 | 3 files |
| AU-14 Video Artery | SKELETON | 852 | 3 files |
| Core Holon (VSM) | COMPLETE | 237 | L2-L5 tests |
| Membrane | COMPLETE | 658 | - |
| Guardian | COMPLETE | 440 | L3 tests |
| FastOODA | COMPLETE | 400+ | L3 tests |

**Gap Analysis**: The AU modules exist as skeleton implementations but are NOT wired to the core organism. Integration is required to make them functional components of the living system.

---

## L1: FOUNDATION - The Cellular Substrate

### L1.1: Constitution Verification System

The Constitution is the DNA of the organism - immutable axioms that every Holon must verify on startup.

**Current Gap**: `Indrajaal.Core.Constitution.Verifier` is referenced but may not be fully implemented.

**Integration Tasks**:
```
L1.1.1: Verify Constitution.Verifier exists and works
        └─ File: lib/indrajaal/core/constitution/verifier.ex
        └─ Test: Holon startup blocked if constitution violated (SC-HOL-002)

L1.1.2: Implement Constitution Hash Verification
        └─ Hash of 4 Axioms (Fractal, Simplex, Gravity, Sovereignty)
        └─ Every Holon.init/1 calls Verifier.verify()
        └─ Telemetry: constitution_verified | constitution_violated

L1.1.3: Create Constitution Snapshot Storage
        └─ Store verified constitution in :persistent_term
        └─ Accessible via Indrajaal.Core.Constitution.axioms/0
```

**Verification Gate G1.1**:
```elixir
test "holon startup blocked on constitution violation" do
  # Temporarily corrupt constitution
  assert {:error, {:constitution_violated, _}} = TestHolon.start_link([])
end
```

**STAMP Constraints**:
- SC-CONST-001: Constitution MUST be verified before any Holon starts
- SC-CONST-002: Constitution hash MUST match known good value
- SC-CONST-003: Constitution violations MUST halt startup

---

### L1.2: Holon Registry & Lifecycle

**Current Gap**: Holons exist but no global registry tracks them across the fractal hierarchy.

**Integration Tasks**:
```
L1.2.1: Create HolonRegistry (ETS-based)
        └─ File: lib/indrajaal/core/holon/registry.ex
        └─ Tracks: {holon_id, pid, layer, parent, children, health}
        └─ Pub/sub for health changes

L1.2.2: Implement Health Propagation (SC-HOL-004)
        └─ File: lib/indrajaal/core/holon/health_propagator.ex [EXISTS]
        └─ Wire: Parent receives child health updates within 100ms
        └─ Pattern: Bottom-up health aggregation

L1.2.3: VSM System Wiring
        └─ S1 (Operations) → Domain business logic
        └─ S2 (Coordination) → Gossip protocol (AU-15 dependency)
        └─ S3 (Control) → ResourcePool integration
        └─ S4 (Intelligence) → FastOODA/AI integration
        └─ S5 (Policy) → Constitution verification
```

**Verification Gate G1.2**:
```elixir
test "holon registry tracks 7-layer hierarchy" do
  assert HolonRegistry.count_by_layer(:agent) >= 50
  assert HolonRegistry.parent_of(agent_id) == container_id
end
```

---

### L1.3: Membrane Universal Protection

**Current Gap**: Membrane exists in Prajna namespace but should wrap ALL domain APIs.

**Integration Tasks**:
```
L1.3.1: Promote Membrane to Core
        └─ Move: lib/indrajaal/core/bio/membrane.ex
        └─ Or: Alias Indrajaal.Bio.Membrane → Prajna.Bio.Membrane

L1.3.2: Wrap All 10 Ash Domains with Membranes
        └─ Accounts, Sites, Devices, Alarms, Video...
        └─ Pattern: Domain.get_user(id) → Membrane.cross(:accounts, {:get_user, id})
        └─ Auto-wrap via Membrane.protect_module/2

L1.3.3: Membrane Telemetry → Fractal Logging
        └─ All crossing events emit to Zenoh
        └─ Circuit breaker state changes visible in Prajna
```

**Files to Modify**:
- `lib/indrajaal/accounts/accounts.ex` - Add membrane wrapper
- `lib/indrajaal_web/live/prajna/gardener_live.ex` - Display membrane health

---

## L2: NEURAL - The Nervous System

### L2.1: Zenoh Control Bus Completion

**Current State**: Skeleton exists with 1,113 lines. Not wired to core.

**Integration Tasks**:
```
L2.1.1: Wire RouteDiscovery to Cluster Startup
        └─ File: lib/indrajaal/cluster/zenoh/route_discovery.ex [EXISTS]
        └─ Integration: Start in Application.start/2 after ZenohMesh
        └─ Verify: Topology learned within 5s (SC-ZENOH-DISC-001)

L2.1.2: Wire TracePropagator to OTEL
        └─ File: lib/indrajaal/cluster/zenoh/trace_propagator.ex [EXISTS]
        └─ Integration: Inject trace context in ZenohMesh.publish/3
        └─ Verify: Traces visible in SigNoz across nodes

L2.1.3: Wire Backpressure to UnifiedControlBus
        └─ File: lib/indrajaal/cluster/zenoh/backpressure.ex [EXISTS]
        └─ Integration: Wrap all bus.publish calls with backpressure check
        └─ Verify: Circuit breaks at 1000 events/sec (SC-BUS-003)
```

**Key File Modifications**:
```elixir
# lib/indrajaal/cluster/zenoh_mesh.ex
def publish(topic, payload, opts \\ []) do
  # NEW: Add trace context
  payload_with_trace = TracePropagator.inject(payload)

  # NEW: Check backpressure
  case Backpressure.check(topic) do
    :ok -> do_publish(topic, payload_with_trace, opts)
    {:circuit_open, _} -> {:error, :backpressure}
  end
end
```

---

### L2.2: FastOODA → OpenRouter AI Orientation

**Current State**: FastOODA has stub AI orientation with 20ms timeout. OpenRouter adapter exists but not connected.

**Integration Tasks**:
```
L2.2.1: Connect FastOODA to OpenRouter Adapter
        └─ File: lib/indrajaal/cortex/fast_ooda.ex:orient_phase/1
        └─ Call: OpenRouter.Adapter.quick_orient/2 with 20ms timeout
        └─ Fallback: Local heuristics if timeout (SC-OODA-006)

L2.2.2: Implement Quick Orient Endpoint
        └─ File: lib/indrajaal/ai/openrouter/adapter.ex
        └─ Function: quick_orient(observations, timeout_ms \\ 20)
        └─ Model: Use smallest/fastest model (e.g., haiku-instant)

L2.2.3: Connect Streaming to Simplex
        └─ File: lib/indrajaal/ai/openrouter/stream_handler.ex
        └─ Integration: Stream through Guardian validation
        └─ Pattern: Each chunk validated before accumulation
```

**Verification Gate G2.2**:
```elixir
test "FastOODA completes cycle in <100ms with AI assist" do
  Tracer.with_span "ooda_cycle" do
    {:ok, result} = FastOODA.run_cycle(observations)
    assert result.latency_ms < 100
  end
end
```

---

### L2.3: Health Telemetry Pipeline

**Integration Tasks**:
```
L2.3.1: Wire Container Sensors to Zenoh
        └─ PodmanHealthSensor → zenoh://indrajaal/sensors/container/*
        └─ SystemSensor → zenoh://indrajaal/sensors/system/*
        └─ BeamSensor → zenoh://indrajaal/sensors/beam/*

L2.3.2: Create Sensor Mesh Coordinator
        └─ File: lib/indrajaal/cortex/sensors/sensor_mesh.ex [EXISTS]
        └─ Role: Aggregate sensor readings, fan-out to observers
        └─ Integration: FastOODA subscribes to sensor mesh

L2.3.3: Prajna Dashboard Integration
        └─ WebSocket: Push sensor data to LiveView
        └─ Visualization: Real-time health heatmap
```

---

## L3: COGNITIVE - The Brain

### L3.1: Simplex Architecture Completion

**Current State**: Guardian (440 lines) and Envelope exist. Need full wiring.

**Integration Tasks**:
```
L3.1.1: Wire Guardian to ALL AI Outputs
        └─ OpenRouter responses → Guardian.validate_proposal/1
        └─ GDE proposals → Guardian.validate_proposal/1
        └─ Autonomous actions → Guardian.validate_proposal/1

L3.1.2: Wire DeadMansSwitch to FastOODA
        └─ FastOODA sends heartbeat every 50ms
        └─ DMS triggers failsafe if 3 heartbeats missed
        └─ Failsafe: Stop all autonomous actions

L3.1.3: Create Veto UI in Prajna
        └─ War Room mode: Show AI proposal before Act phase
        └─ Physical "VETO" button (keyboard shortcut)
        └─ Operator can block any AI action
```

---

### L3.2: Goal-Directed Evolution Pipeline

**Current State**: GDE modules exist but evolution disabled.

**Integration Tasks**:
```
L3.2.1: Wire GDE to OpenRouter for Proposal Generation
        └─ File: lib/indrajaal/cortex/gde/ai_integration.ex [EXISTS]
        └─ Call: OpenRouter.Adapter.generate_proposal/2
        └─ Model: Use reasoning model (opus/sonnet)

L3.2.2: Enable Shadow Mode Testing
        └─ File: lib/indrajaal/cortex/evolution/shadow_mode.ex [EXISTS]
        └─ Integration: All GDE proposals run in shadow first
        └─ Duration: 24 hours shadow before promotion

L3.2.3: Wire Training Gym for Learning
        └─ File: lib/indrajaal/cortex/evolution/training_gym.ex [EXISTS]
        └─ Record: All decisions (good and vetoed)
        └─ Feedback: Train local models on accumulated data
```

---

### L3.3: OpenRouter Model Fallback Chain

**Current State**: model_fallback.ex exists (294 lines) but not integrated.

**Integration Tasks**:
```
L3.3.1: Define Intent → Model Mapping
        └─ :quick_orient → [haiku-instant, haiku, sonnet] (20ms budget)
        └─ :analysis → [sonnet, opus, gemini-pro] (5s budget)
        └─ :code_gen → [opus, sonnet, gpt-4] (30s budget)

L3.3.2: Wire Retry Strategy
        └─ File: lib/indrajaal/ai/openrouter/retry_strategy.ex [EXISTS]
        └─ Integration: Wrap all OpenRouter calls
        └─ Pattern: Exponential backoff with jitter

L3.3.3: Emit Fallback Telemetry
        └─ Track: Which models fail, which succeed
        └─ Zenoh: indrajaal/ai/fallback_events
```

---

## L4: METABOLIC - The Body

### L4.1: Data Locality & Gravity Routing

**Current State**: gravity_router.ex and locality_registry.ex exist (679 lines).

**Integration Tasks**:
```
L4.1.1: Wire LocalityRegistry to ZenohMesh Publish
        └─ Every publish registers data location
        └─ Pattern: locality_registry.register(topic, node(), size_bytes)

L4.1.2: Wire GravityRouter to Task Dispatch
        └─ When spawning FLAME tasks, consult gravity
        └─ Decision: Run locally if data > 1GB exists locally
        └─ Log: All routing decisions for audit (SC-GRAV-004)

L4.1.3: Create Gravity Visualizer
        └─ Prajna: Show data gravity wells on cluster map
        └─ Color: Hotter = more data gravity
```

**Key File Modifications**:
```elixir
# lib/indrajaal/analytics/flame_runner.ex
def spawn_task(function, args, opts) do
  # NEW: Consult gravity router
  target_node = GravityRouter.route(opts[:data_key])

  if target_node == Node.self() do
    # Run locally
    function.(args)
  else
    # Move compute to data
    :erpc.call(target_node, function, args)
  end
end
```

---

### L4.2: Pre-Roll Ring Buffer Integration

**Current State**: ring_buffer.ex, buffer_manager.ex, event_trigger.ex exist (629 lines).

**Integration Tasks**:
```
L4.2.1: Wire BufferManager to Video Stream Resource
        └─ Every active stream gets a ring buffer
        └─ Configurable: 30-60 second lookback (SC-PREROLL-002)

L4.2.2: Wire EventTrigger to Alarms Domain
        └─ On Alarm.create → Freeze relevant buffers
        └─ Pattern: Alarm zone → Camera mapping
        └─ Output: Pre-roll segment written to storage

L4.2.3: Wire to Zenoh for Distributed Coordination
        └─ Publish: zenoh://indrajaal/video/preroll/frozen
        └─ Other nodes know to preserve their pre-roll
```

---

### L4.3: Video Artery (WebRTC P2P)

**Current State**: split_plane.ex, webrtc_signaling.ex, jellyfish_adapter.ex exist (852 lines).

**Integration Tasks**:
```
L4.3.1: Wire SplitPlane to Tailscale for Signaling
        └─ Control messages over Tailscale mesh
        └─ ICE candidates exchanged via Zenoh
        └─ Verify: Signaling encrypted (SC-ARTERY-001)

L4.3.2: Wire WebRTC Signaling to Prajna
        └─ War Room mode: Initiate P2P video calls
        └─ LiveView: Embed WebRTC player component
        └─ Fallback: If P2P fails, use Jellyfish SFU

L4.3.3: Implement Jellyfish Adapter
        └─ Connect to Jellyfish SFU server
        └─ Use only when P2P fails (symmetric NAT)
        └─ Pattern: Try P2P 3 times, then fallback
```

---

## L5: FEDERATION - The Colony

### L5.1: Distributed Mesh Supervisor

**Current State**: DistributedMesh, AgentMesh, WorkerMesh exist.

**Integration Tasks**:
```
L5.1.1: Wire DistributedMesh to Application Supervisor
        └─ Start after: Database, ZenohMesh, Constitution
        └─ Children: AgentMesh, WorkerMesh, Dashboard

L5.1.2: Wire AgentMesh to 50 Agents
        └─ Register: All 50 agents on startup
        └─ Monitor: Health via HolonRegistry
        └─ Redistribute: On node failure

L5.1.3: Wire WorkerMesh to FLAME Pool
        └─ Dynamic workers spawn via FLAME
        └─ Coordinate: Via Gossip protocol
        └─ Gravity: Route to data-local nodes
```

---

### L5.2: FQUN System Completion

**Current State**: FQUN module exists with generate/parse/to_zenoh_key.

**Integration Tasks**:
```
L5.2.1: Assign FQUN to Every Holon on Start
        └─ Pattern: indrajaal/<layer>/<type>/<ns>/<name>@<node>#<instance>
        └─ Store: In HolonRegistry

L5.2.2: Wire FQUN to Zenoh Key Expressions
        └─ Every publish uses FQUN as topic prefix
        └─ Enables: Wildcard subscriptions by layer

L5.2.3: Create FQUN Resolver
        └─ Function: FQUN.resolve(fqun) → pid()
        └─ Cross-node: Use Zenoh to find remote holons
```

---

### L5.3: Peer Discovery & Gossip

**Current State**: Discovery and Gossip modules exist.

**Integration Tasks**:
```
L5.3.1: Wire Discovery to Cluster Formation
        └─ On startup: Discover peers via DNS/multicast
        └─ Join: libcluster integration
        └─ Timeout: 30s (SC-DIS-001)

L5.3.2: Wire Gossip to S2 (Coordination)
        └─ Every Holon's system2_coordination uses gossip
        └─ State dissemination: O(log N) rounds
        └─ Fan-out: 3-5 peers (SC-GOS-003)

L5.3.3: Implement Failure Detection (SWIM)
        └─ Ping-Ack-Suspect-Dead protocol
        └─ Propagate: Node failures via gossip
        └─ Action: Redistribute holons on failure
```

---

## Integration Sequence Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     INTEGRATION EXECUTION ORDER                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  WEEK 1: L1 Foundation                                                       │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ L1.1 Constitution → L1.2 HolonRegistry → L1.3 Membrane Promotion      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                         │
│                                    ▼                                         │
│  WEEK 2: L2 Neural                                                           │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ L2.1 Zenoh Wiring → L2.2 FastOODA+AI → L2.3 Sensor Pipeline           │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                         │
│                                    ▼                                         │
│  WEEK 3: L3 Cognitive                                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ L3.1 Simplex Complete → L3.2 GDE Pipeline → L3.3 Model Fallback       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                         │
│                                    ▼                                         │
│  WEEK 4: L4 Metabolic                                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ L4.1 Gravity Routing → L4.2 Pre-Roll Buffers → L4.3 Video Artery      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                         │
│                                    ▼                                         │
│  WEEK 5: L5 Federation                                                       │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ L5.1 Mesh Supervisor → L5.2 FQUN System → L5.3 Discovery+Gossip       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Verification Matrix

| Level | Gate | Test Command | Success Criteria |
|-------|------|--------------|------------------|
| L1.1 | G1-CONST | `mix test test/indrajaal/core/constitution/` | Constitution verification passes |
| L1.2 | G1-REG | `mix test test/indrajaal/core/holon/` | Registry tracks all 50 agents |
| L1.3 | G1-MEM | `mix test test/indrajaal/core/bio/` | Membrane wraps all domains |
| L2.1 | G2-ZENOH | `mix test test/indrajaal/cluster/zenoh/` | Trace propagation works |
| L2.2 | G2-OODA | `mix test test/indrajaal/cortex/fast_ooda_test.exs` | <100ms with AI |
| L2.3 | G2-SENS | `mix test test/indrajaal/cortex/sensors/` | Sensor mesh aggregates |
| L3.1 | G3-GUARD | `mix test test/indrajaal/safety/` | All AI vetted by Guardian |
| L3.2 | G3-GDE | `mix test test/indrajaal/cortex/gde/` | Shadow mode works |
| L3.3 | G3-AI | `mix test test/indrajaal/ai/openrouter/` | Fallback chain works |
| L4.1 | G4-GRAV | `mix test test/indrajaal/distributed/gravity/` | Routing decisions logged |
| L4.2 | G4-ROLL | `mix test test/indrajaal/video/preroll/` | 60s pre-roll captured |
| L4.3 | G4-RTC | `mix test test/indrajaal/video/artery/` | P2P video works |
| L5.1 | G5-MESH | `mix test test/indrajaal/federation/` | Mesh supervises agents |
| L5.2 | G5-FQUN | `mix test test/indrajaal/distributed/fqun/` | All holons have FQUN |
| L5.3 | G5-DISC | `mix test test/indrajaal/distributed/mesh/` | Discovery <30s |

---

## STAMP Constraint Summary (New for Integration)

| ID | Constraint | Level | Verification |
|----|------------|-------|--------------|
| SC-INT-001 | All AU modules MUST be wired to core | All | mix compile 0 warnings |
| SC-INT-002 | Integration MUST not break existing tests | All | mix test 100% pass |
| SC-INT-003 | Each level MUST pass gate before next | All | Gate sequence |
| SC-INT-004 | OpenRouter MUST connect to FastOODA | L2-L3 | OODA latency test |
| SC-INT-005 | Guardian MUST veto all AI outputs | L3 | Guardian stats |
| SC-INT-006 | Gravity MUST log routing decisions | L4 | Audit log check |
| SC-INT-007 | Pre-roll MUST freeze on alarm | L4 | Event trigger test |
| SC-INT-008 | P2P MUST fallback to SFU | L4 | NAT simulation test |
| SC-INT-009 | Gossip MUST reach all nodes | L5 | Convergence test |
| SC-INT-010 | FQUN MUST be assigned to all holons | L5 | Registry audit |

---

## Success Criteria Checklist

### L1 Foundation Complete
- [ ] Constitution verifier blocks invalid holons
- [ ] HolonRegistry tracks all 50 agents + containers
- [ ] Membrane wraps all 10 Ash domains
- [ ] Health propagates bottom-up within 100ms

### L2 Neural Complete
- [ ] Zenoh route discovery < 5s
- [ ] Trace context in all cross-node messages
- [ ] Backpressure circuit breaks at 1000 events/sec
- [ ] FastOODA + AI orientation < 100ms

### L3 Cognitive Complete
- [ ] ALL AI outputs pass through Guardian
- [ ] DeadMansSwitch monitors FastOODA heartbeat
- [ ] GDE proposals run in shadow mode first
- [ ] Model fallback chain works (3 levels)

### L4 Metabolic Complete
- [ ] Gravity routing logs all decisions
- [ ] Data-local compute for datasets > 1GB
- [ ] 60-second pre-roll captured on alarm
- [ ] WebRTC P2P video streaming works
- [ ] Jellyfish SFU fallback tested

### L5 Federation Complete
- [ ] DistributedMesh supervises AgentMesh + WorkerMesh
- [ ] All holons have FQUN assigned
- [ ] Peer discovery < 30s timeout
- [ ] Gossip converges in O(log N) rounds
- [ ] Node failure redistributes holons

---

## Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2025-12-30 |
| Author | Cybernetic Architect (Claude Opus 4.5) |
| Status | READY FOR EXECUTION |
| Dependencies | INDRAJAAL_V20_MASTER_PLAN.md, v20.1-critical-upgrades-plan.md |

---

**Assertion**: This 5-Level Integration Plan provides the complete blueprint for transforming the existing skeleton AU modules into a living, breathing Cybernetic Organism. Each level builds on the previous, with explicit verification gates ensuring incremental progress toward the v20 vision.
