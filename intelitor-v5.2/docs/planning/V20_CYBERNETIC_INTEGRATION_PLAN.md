# Indrajaal v20: Cybernetic Integration - 5-Level Implementation Plan

**Version**: 1.0.0
**Date**: 2025-12-30
**Status**: READY FOR EXECUTION
**Scope**: Full integration of Master Plan with existing v20 codebase

---

## Executive Summary

All 9 core architectural components are **IMPLEMENTED**. This plan focuses on **INTEGRATION** and **HARDENING** to transform the collection of components into a true Unified Cybernetic Organism.

| Component | Status | Integration Level |
|-----------|--------|-------------------|
| Holon (VSM) | ✅ Implemented | L1 - Wire to containers |
| UnifiedBus | ✅ Implemented | L2 - Wire all control loops |
| Sensors | ✅ Implemented | L2 - Wire to FastOODA |
| FastOODA | ✅ Implemented | L2 - Wire to Bus + TrainingGym |
| GDE | ✅ Implemented | L3 - Wire to Synapse + Guardian |
| TrainingGym | ✅ Implemented | L3 - Wire to Zenoh ML pipelines |
| Guardian | ✅ Implemented | L3 - Wire all AI paths |
| Cortex/Synapse | ✅ Implemented | L3 - Wire bicameral loop |
| Prajna Cockpit | ✅ Implemented | L4 - Wire full observability |

---

## Level 1: FOUNDATION (Axiomatic Verification)

**Goal**: Verify biological laws are enforced across all existing components.

### L1.1: Constitution Enforcement

**Task**: Ensure every agent/service implements the Holon interface.

```
Priority: CRITICAL
STAMP: SC-HOL-001, SC-HOL-002
Dependencies: None
```

**Actions**:
1. Create `mix holon.verify` task to scan all modules
2. Verify all 50 agents implement `use Indrajaal.Core.Holon`
3. Add compilation hook to reject non-compliant modules
4. Generate Holon compliance report

**Files to Create**:
```
lib/mix/tasks/holon.verify.ex
test/indrajaal/core/holon_compliance_test.exs
```

**Success Criteria**:
- [ ] All agents pass Holon compliance check
- [ ] Constitution verified at startup (SC-HOL-002)
- [ ] Non-compliant modules fail compilation

---

### L1.2: Fractal Layer Wiring

**Task**: Wire container-level holons to node-level holons.

```
Priority: HIGH
STAMP: SC-HOL-003, SC-HOL-004
Dependencies: L1.1
```

**Actions**:
1. Implement `Indrajaal.Core.Holon.Registry` - track parent/child relationships
2. Wire containers (App/DB/Obs) as holons under node holon
3. Implement health propagation from children to parents (100ms)
4. Add Prajna visualization for Holon hierarchy

**Files to Create/Modify**:
```
lib/indrajaal/core/holon/registry.ex
lib/indrajaal/core/holon/health_propagator.ex
test/indrajaal/core/holon/registry_test.exs
```

**Success Criteria**:
- [ ] Holon hierarchy visible in Prajna
- [ ] Health propagates within 100ms
- [ ] Container restart triggers parent health update

---

### L1.3: STAMP Constraint Registry

**Task**: Create runtime STAMP constraint validation.

```
Priority: HIGH
STAMP: All 277 constraints
Dependencies: None
```

**Actions**:
1. Parse all SC-XXX-NNN constraints from CLAUDE.md/GEMINI.md
2. Create `Indrajaal.Safety.STAMPRegistry` with runtime checks
3. Wire to Guardian for proposal validation
4. Add Prajna STAMP dashboard

**Files to Create**:
```
lib/indrajaal/safety/stamp_registry.ex
lib/indrajaal/safety/stamp_parser.ex
test/indrajaal/safety/stamp_registry_test.exs
```

**Success Criteria**:
- [ ] All 277 constraints loadable at runtime
- [ ] Guardian uses STAMP registry for validation
- [ ] Prajna shows STAMP compliance status

---

## Level 2: NEURAL INTEGRATION (Control Loop Wiring)

**Goal**: Wire all control loops to UnifiedBus for coordinated operation.

### L2.1: FastOODA ↔ UnifiedBus Integration

**Task**: Complete bidirectional wiring between FastOODA and UnifiedBus.

```
Priority: CRITICAL
STAMP: SC-OODA-001, SC-BUS-001
Dependencies: L1
```

**Actions**:
1. Verify FastOODA auto-registers with UnifiedBus at startup
2. Wire all FastOODA decisions to `UnifiedBus.execute/1`
3. Ensure FastOODA receives `:control_event` from other loops
4. Add metrics for cross-loop latency

**Files to Modify**:
```
lib/indrajaal/cortex/fast_ooda.ex    # Verify registration
lib/indrajaal/control/unified_bus.ex # Verify routing
```

**Current State Check**:
```elixir
# FastOODA should call:
UnifiedBus.register(:fast_ooda, self())  # On init
UnifiedBus.execute(decision)              # On act
UnifiedBus.broadcast(observation)         # On observe (optional)
```

**Success Criteria**:
- [ ] FastOODA appears in `UnifiedBus.registered_loops()`
- [ ] Decisions routed to ACE/Homeostasis
- [ ] Cross-loop latency <10ms

---

### L2.2: Sensor Mesh → FastOODA Wiring

**Task**: Wire all sensors to FastOODA observation buffer.

```
Priority: HIGH
STAMP: SC-SENS-001, SC-OODA-003
Dependencies: L2.1
```

**Actions**:
1. Create `Indrajaal.Cortex.SensorMesh` coordinator
2. Wire SystemSensor, ContainerHealthSensor, FLAMESensor, MLSensor
3. Implement async batch collection (10ms window)
4. Add sensor staleness detection (>100ms = stale)

**Files to Create/Modify**:
```
lib/indrajaal/cortex/sensor_mesh.ex     # New coordinator
lib/indrajaal/cortex/fast_ooda.ex       # Consume sensor mesh
test/indrajaal/cortex/sensor_mesh_test.exs
```

**Architecture**:
```
┌─────────────────────────────────────────────┐
│              SensorMesh                      │
│  ┌────────┐ ┌─────────┐ ┌──────┐ ┌────────┐ │
│  │ System │ │Container│ │FLAME │ │   ML   │ │
│  │ Sensor │ │ Health  │ │Sensor│ │ Sensor │ │
│  └───┬────┘ └────┬────┘ └──┬───┘ └───┬────┘ │
│      └───────────┴─────────┴─────────┘      │
│                    │                         │
│           ┌────────▼────────┐               │
│           │  Batch Buffer   │               │
│           │  (10ms window)  │               │
│           └────────┬────────┘               │
└────────────────────┼────────────────────────┘
                     │
                     ▼
              FastOODA.observe()
```

**Success Criteria**:
- [ ] All 4 sensors feeding SensorMesh
- [ ] Batch latency <10ms
- [ ] Stale data flagged with quality penalty

---

### L2.3: Zenoh Neural Stream Integration

**Task**: Wire Zenoh pub/sub to control loop telemetry.

```
Priority: HIGH
STAMP: SC-ZENOH-TRACE-001
Dependencies: L2.1, L2.2
```

**Actions**:
1. Wire `Indrajaal.Cortex.ZenohNeuralStream` to FastOODA
2. Publish all OODA cycles to Zenoh topic: `indrajaal/v1/cortex/ooda/{node}`
3. Inject OTEL trace context (using TracePropagator from AU-15)
4. Subscribe Prajna dashboard to neural stream

**Files to Modify**:
```
lib/indrajaal/cortex/fast_ooda.ex              # Publish cycles
lib/indrajaal/cortex/zenoh_neural_stream.ex    # Verify pub/sub
lib/indrajaal_web/live/prajna/ooda_live.ex     # Subscribe
```

**Zenoh Key Expression**:
```
indrajaal/v1/cortex/ooda/{node_id}/cycles    # OODA cycle metrics
indrajaal/v1/cortex/ooda/{node_id}/decisions # Decisions made
indrajaal/v1/cortex/ooda/{node_id}/stress    # System stress
```

**Success Criteria**:
- [ ] OODA cycles visible in Zenoh explorer
- [ ] Trace context propagates across nodes
- [ ] Prajna shows real-time OODA visualization

---

### L2.4: Backpressure Integration

**Task**: Wire Zenoh Backpressure to UnifiedBus circuit breaker.

```
Priority: MEDIUM
STAMP: SC-BUS-003
Dependencies: L2.3
```

**Actions**:
1. Create unified circuit breaker coordination
2. When Zenoh backpressure trips → notify UnifiedBus
3. When UnifiedBus circuit trips → pause Zenoh publishing
4. Add circuit breaker dashboard to Prajna

**Files to Create/Modify**:
```
lib/indrajaal/cluster/zenoh/backpressure.ex        # Add bus notification
lib/indrajaal/control/unified_bus.ex               # Accept backpressure signal
lib/indrajaal/control/circuit_coordinator.ex       # New coordinator
```

**Success Criteria**:
- [ ] Backpressure propagates across components
- [ ] Graceful degradation under load
- [ ] Prajna shows circuit breaker status

---

## Level 3: COGNITIVE INTEGRATION (AI + Safety Wiring)

**Goal**: Wire AI systems with Guardian safety layer.

### L3.1: Guardian ↔ GDE Integration

**Task**: Ensure all GDE proposals pass Guardian validation.

```
Priority: CRITICAL
STAMP: SC-GDE-001, SC-GUARD-001
Dependencies: L2
```

**Actions**:
1. Verify `GDE.Generator` calls `Guardian.validate/1` before apply
2. Wire Guardian veto to TrainingGym `record_near_miss/3`
3. Add GDE proposal audit log with Guardian decisions
4. Create Prajna "AI Proposals" view

**Files to Modify**:
```
lib/indrajaal/cortex/gde/generator.ex    # Verify Guardian call
lib/indrajaal/safety/guardian.ex         # Verify TrainingGym call
```

**Flow Verification**:
```
GDE.Generator → Guardian.validate() → {:ok, proposal} → Apply
                                    → {:veto, reason} → TrainingGym.record_near_miss()
```

**Success Criteria**:
- [ ] No GDE proposal bypasses Guardian
- [ ] All vetoes recorded to TrainingGym
- [ ] Audit log shows proposal→decision trace

---

### L3.2: Synapse Bicameral Loop Wiring

**Task**: Wire Synapse's Gemini+Claude bicameral loop.

```
Priority: HIGH
STAMP: SC-GVF-007
Dependencies: L3.1
```

**Actions**:
1. Verify Synapse uses `GeminiInterface` for analysis
2. Verify Synapse uses `ClaudeInterface` for synthesis
3. Wire output to Guardian before execution
4. Add ZenohTimeTravel checkpoint at each step

**Files to Modify**:
```
lib/indrajaal/cortex/synapse.ex              # Verify bicameral flow
lib/indrajaal/cortex/zenoh_time_travel.ex    # Verify checkpoints
```

**Bicameral Flow**:
```
OBSERVE (Context)
    ↓
GEMINI (Analyze)     ← OpenRouter API
    ↓
CLAUDE (Synthesize)  ← OpenRouter API
    ↓
GUARDIAN (Validate)  ← Simplex Architecture
    ↓
EXECUTE or VETO
```

**Success Criteria**:
- [ ] Both AI models invoked in sequence
- [ ] Guardian validates before execution
- [ ] Checkpoints allow backtracking

---

### L3.3: TrainingGym → Zenoh ML Pipeline

**Task**: Wire TrainingGym episodes to Zenoh for downstream ML.

```
Priority: MEDIUM
STAMP: SC-TRAIN-003
Dependencies: L3.1, L3.2
```

**Actions**:
1. Configure TrainingGym auto-flush to Zenoh
2. Define Zenoh topic: `indrajaal/v1/ml/training/{episode_type}`
3. Create ML pipeline consumer [Updated Sprint 51] (implemented)
4. Add episode statistics to Prajna

**Files to Modify**:
```
lib/indrajaal/cortex/evolution/training_gym.ex  # Verify Zenoh pub
lib/indrajaal/cluster/zenoh_mesh.ex             # Add ML topics
```

**Episode Types Published**:
- `SUCCESS` → Reinforcement signal (+1.0)
- `NEAR_MISS` → Negative signal (-1.0)
- `SHADOW_DIVERGE` → Model drift signal (-0.5)
- `SHADOW_AGREE` → Confirmation signal (+0.5)

**Success Criteria**:
- [ ] Episodes visible in Zenoh
- [ ] Auto-flush every 60s or 10,000 episodes
- [ ] Prajna shows learning metrics

---

### L3.4: AI Orientation → FastOODA

**Task**: Wire AI-assisted orientation to FastOODA with timeout.

```
Priority: MEDIUM
STAMP: SC-OODA-006
Dependencies: L3.2
```

**Actions**:
1. Implement async AI orientation call in FastOODA.orient()
2. Use 20ms timeout with local heuristic fallback
3. Route through OpenRouter adapter (AU-01)
4. Record AI assist vs fallback ratio

**Files to Modify**:
```
lib/indrajaal/cortex/fast_ooda.ex           # Add AI orientation
lib/indrajaal/ai/openrouter/adapter.ex       # Verify timeout handling
```

**Orientation Logic**:
```elixir
def orient(observations, opts) do
  case try_ai_orientation(observations, timeout: 20) do
    {:ok, ai_insights} ->
      {:ai_assisted, merge_insights(observations, ai_insights)}

    {:timeout, _} ->
      {:fallback, local_heuristics(observations)}
  end
end
```

**Success Criteria**:
- [ ] AI orientation completes in <20ms or falls back
- [ ] Fallback maintains cycle time target
- [ ] Metrics show AI vs fallback ratio

---

## Level 4: METABOLIC INTEGRATION (Data + Storage)

**Goal**: Wire data gravity and storage systems.

### L4.1: Gravity Router → ZenohMesh

**Task**: Wire Data Locality Registry to Zenoh routing.

```
Priority: HIGH
STAMP: SC-GRAV-001
Dependencies: L3
```

**Actions**:
1. Wire `LocalityRegistry` to track data locations
2. Modify `GravityRouter` to inform Zenoh publish decisions
3. Implement "move compute to data" routing
4. Add data gravity dashboard to Prajna

**Files to Modify**:
```
lib/indrajaal/distributed/gravity/locality_registry.ex
lib/indrajaal/distributed/gravity/gravity_router.ex
lib/indrajaal/cluster/zenoh_mesh.ex             # Use gravity router
```

**Routing Logic**:
```elixir
def route_request(request, data_key, registry) do
  case LocalityRegistry.lookup(registry, data_key) do
    {:ok, %{node: remote_node, gravity: g}} when g > 0.3 ->
      # High gravity - move compute to data
      {:route_to_data, remote_node}

    {:ok, %{node: _remote_node}} ->
      # Low gravity - fetch data locally
      {:fetch_data, :local}

    {:error, :not_found} ->
      # Unknown location - broadcast query
      {:broadcast_query, data_key}
  end
end
```

**Success Criteria**:
- [ ] Data gravity decisions logged
- [ ] High-gravity data stays in place
- [ ] Prajna shows data locality map

---

### L4.2: Video Artery → Gravity Integration

**Task**: Wire video streaming to gravity nodes.

```
Priority: MEDIUM
STAMP: SC-ARTERY-001, Gravity Axiom
Dependencies: L4.1, AU-14
```

**Actions**:
1. Wire `SplitPlane` control plane to Tailscale mesh
2. Ensure video ingestion registers with LocalityRegistry
3. Implement "Gravity Well" pattern - process video on ingest node
4. Only publish metadata to federation

**Files to Modify**:
```
lib/indrajaal/video/artery/split_plane.ex       # Register locality
lib/indrajaal/distributed/gravity/locality_registry.ex # Video gravity
```

**Gravity Well Pattern**:
```
┌──────────────────────────────────────────┐
│           Gravity Well (Ingest Node)      │
│  ┌────────────┐   ┌─────────────────────┐│
│  │   Camera   │───│    Video Pipeline    ││
│  │   Stream   │   │ ├─ Decode            ││
│  └────────────┘   │ ├─ Analyze (YOLO)    ││
│                   │ ├─ Ring Buffer       ││
│                   │ └─ Pre-roll Storage  ││
│                   └─────────────────────┘│
│                           │              │
│                    Metadata Only         │
│                           ↓              │
└──────────────────────────┼───────────────┘
                           │
                  ┌────────▼────────┐
                  │   Federation    │
                  │ (Postgres/Zenoh)│
                  └─────────────────┘
```

**Success Criteria**:
- [ ] Video processing on ingest node
- [ ] Only metadata crosses network
- [ ] Pre-roll buffer functional

---

### L4.3: Pre-Roll → Alarm Integration

**Task**: Wire Pre-Roll Buffer to Alarm domain.

```
Priority: MEDIUM
STAMP: SC-PREROLL-001
Dependencies: L4.2, AU-07
```

**Actions**:
1. Wire `EventTrigger` to Alarms domain events
2. When alarm triggers → freeze camera buffers
3. Store frozen segments to configured storage
4. Generate evidence package for alarm

**Files to Modify**:
```
lib/indrajaal/video/preroll/event_trigger.ex    # Wire to alarms
lib/indrajaal/alarms/alarm_processor.ex         # Emit freeze event
```

**Alarm → Video Flow**:
```
Alarm Triggered
    ↓
PubSub: {:alarm_triggered, alarm_id, zone_id}
    ↓
EventTrigger receives event
    ↓
Lookup cameras for zone
    ↓
BufferManager.freeze_buffer(camera_id)
    ↓
SegmentWriter.write_frozen(frozen_data)
    ↓
Attach evidence to alarm
```

**Success Criteria**:
- [ ] Alarm triggers buffer freeze
- [ ] 30-60 second pre-roll captured
- [ ] Evidence attached to alarm record

---

### L4.4: Prajna Full Observability

**Task**: Wire Prajna to all subsystems for complete visibility.

```
Priority: HIGH
STAMP: SC-OBS-069
Dependencies: L4.1, L4.2, L4.3
```

**Actions**:
1. Create unified Prajna dashboard
2. Wire all control loops to Prajna
3. Wire data gravity visualization
4. Wire video matrix to Prajna (WebRTC)

**Prajna Components**:
```
┌─────────────────────────────────────────────────────────────┐
│                    PRAJNA COCKPIT                           │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │   OODA       │  │  Holon Tree   │  │  Data Gravity    │ │
│  │  Visualizer  │  │  (VSM view)   │  │  Map             │ │
│  └──────────────┘  └───────────────┘  └──────────────────┘ │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │  Guardian    │  │  Training Gym │  │  Video Matrix    │ │
│  │  Veto Log    │  │  Episodes     │  │  (WebRTC P2P)    │ │
│  └──────────────┘  └───────────────┘  └──────────────────┘ │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │  STAMP       │  │  Zenoh Mesh   │  │  AI Copilot      │ │
│  │  Compliance  │  │  Topology     │  │  (Chat/Analysis) │ │
│  └──────────────┘  └───────────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Success Criteria**:
- [ ] All 9 components visible in Prajna
- [ ] Real-time updates via LiveView
- [ ] Dark Cockpit mode available

---

## Level 5: FEDERATION (Multi-Cluster Organism)

**Goal**: Enable multi-cluster operation as single organism.
**[Updated Sprint 51]**: Federation protocol and streaming are now implemented. Cluster live data uses real DistributedMesh + Node.list.

### L5.1: Cluster Holon Wiring

**Task**: Wire node-level holons to cluster-level holon.

```
Priority: MEDIUM
STAMP: SC-HOL-003
Dependencies: L4
```

**Actions**:
1. Implement `Indrajaal.Core.Holon.ClusterHolon`
2. Wire all node holons as children
3. Implement cross-node health propagation via Zenoh
4. Add cluster view to Prajna

**Files to Create**:
```
lib/indrajaal/core/holon/cluster_holon.ex
lib/indrajaal/core/holon/federation_holon.ex
test/indrajaal/core/holon/cluster_holon_test.exs
```

**Success Criteria**:
- [ ] Cluster health derived from node health
- [ ] Cross-node health within 200ms
- [ ] Prajna shows cluster topology

---

### L5.2: Federated UnifiedBus

**Task**: Extend UnifiedBus across clusters.

```
Priority: MEDIUM
STAMP: SC-BUS-001
Dependencies: L5.1
```

**Actions**:
1. Create `Indrajaal.Control.FederatedBus` - bridges clusters
2. Use Zenoh for cross-cluster events
3. Implement priority-based filtering (only HIGH/CRITICAL cross cluster)
4. Add federation dashboard to Prajna

**Files to Create**:
```
lib/indrajaal/control/federated_bus.ex
test/indrajaal/control/federated_bus_test.exs
```

**Architecture**:
```
┌───────────────────┐     ┌───────────────────┐
│    Cluster A      │     │    Cluster B      │
│  ┌─────────────┐  │     │  ┌─────────────┐  │
│  │ UnifiedBus  │  │     │  │ UnifiedBus  │  │
│  └──────┬──────┘  │     │  └──────┬──────┘  │
│         │         │     │         │         │
│  ┌──────▼──────┐  │     │  ┌──────▼──────┐  │
│  │FederatedBus │◄─┼─────┼─►│FederatedBus │  │
│  └─────────────┘  │Zenoh│  └─────────────┘  │
└───────────────────┘     └───────────────────┘
```

**Success Criteria**:
- [ ] Cross-cluster events delivered
- [ ] Latency < 100ms across clusters
- [ ] Priority filtering works

---

### L5.3: Federated TrainingGym

**Task**: Aggregate learning across federation.

```
Priority: LOW
STAMP: SC-TRAIN-003
Dependencies: L5.2
```

**Actions**:
1. Create federation-level TrainingGym aggregator
2. Collect episodes from all clusters via Zenoh
3. Implement federated learning signal
4. Add federation learning dashboard

**Files to Create**:
```
lib/indrajaal/cortex/evolution/federated_gym.ex
```

**Success Criteria**:
- [ ] Episodes aggregated from all clusters
- [ ] Federated learning signal available
- [ ] Dashboard shows cross-cluster learning

---

### L5.4: Federation Holon (Top Level)

**Task**: Implement the top-level Federation holon.

```
Priority: LOW
STAMP: SC-HOL-001
Dependencies: L5.1, L5.2, L5.3
```

**Actions**:
1. Implement `Indrajaal.Core.Holon.FederationHolon`
2. Wire all cluster holons as children
3. Implement global policy (S5)
4. Add federation health to Prajna

**Success Criteria**:
- [ ] Federation holon represents entire organism
- [ ] Global policy enforced
- [ ] Prajna shows complete organism

---

## Implementation Schedule

| Level | Focus | Estimated Scope |
|-------|-------|-----------------|
| L1 | Foundation | 4 tasks, ~400 lines |
| L2 | Neural | 4 tasks, ~600 lines |
| L3 | Cognitive | 4 tasks, ~500 lines |
| L4 | Metabolic | 4 tasks, ~600 lines |
| L5 | Federation | 4 tasks, ~700 lines |

**Total**: 20 tasks, ~2800 lines of integration code

---

## Verification Gates

### G1: Foundation Gate
- [ ] All 50 agents pass Holon compliance
- [ ] Constitution verified at startup
- [ ] STAMP registry operational

### G2: Neural Gate
- [ ] All control loops registered with UnifiedBus
- [ ] Sensor mesh feeding FastOODA
- [ ] Zenoh neural stream publishing

### G3: Cognitive Gate
- [ ] All AI paths pass Guardian
- [ ] TrainingGym recording episodes
- [ ] Synapse bicameral loop functional

### G4: Metabolic Gate
- [ ] Data gravity routing operational
- [ ] Video artery streaming
- [ ] Pre-roll integrated with alarms

### G5: Federation Gate [Updated Sprint 51]
- [x] Multi-cluster operation verified (federation protocol implemented)
- [x] Federated bus working (streaming implemented)
- [ ] Federation holon healthy

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Missing Holon compliance | HIGH | L1.1 verification task |
| Control loop not registered | HIGH | Auto-discovery in UnifiedBus |
| Guardian bypass | CRITICAL | L3.1 mandatory integration |
| Data gravity misconfiguration | MEDIUM | Audit logging |
| Cross-cluster latency | MEDIUM | Priority filtering |

---

## Appendix: Component Inventory

### Existing Files (No Changes Needed)
- `lib/indrajaal/core/holon/holon.ex` - Core Holon behaviour
- `lib/indrajaal/control/unified_bus.ex` - Control bus
- `lib/indrajaal/cortex/fast_ooda.ex` - Fast OODA loop
- `lib/indrajaal/safety/guardian.ex` - Safety layer
- `lib/indrajaal/cortex/gde/` - Goal-Directed Evolution
- `lib/indrajaal/cortex/evolution/training_gym.ex` - Learning
- `lib/indrajaal/cortex/synapse.ex` - Sensor fusion
- `lib/indrajaal/cockpit/prajna/` - Cockpit
- `lib/indrajaal/cortex/sensors/` - All sensors

### Files Created in v20.1
- `lib/indrajaal/ai/openrouter/` - OpenRouter adapter (AU-01)
- `lib/indrajaal/cluster/zenoh/` - Zenoh enhancements (AU-15)
- `lib/indrajaal/distributed/gravity/` - Gravity routing (AU-02)
- `lib/indrajaal/video/preroll/` - Pre-roll buffer (AU-07)
- `lib/indrajaal/video/artery/` - Video artery (AU-14)

### Files to Create in Integration
- `lib/indrajaal/core/holon/registry.ex`
- `lib/indrajaal/core/holon/health_propagator.ex`
- `lib/indrajaal/safety/stamp_registry.ex`
- `lib/indrajaal/cortex/sensor_mesh.ex`
- `lib/indrajaal/control/circuit_coordinator.ex`
- `lib/indrajaal/control/federated_bus.ex`
- `lib/indrajaal/core/holon/cluster_holon.ex`
- `lib/indrajaal/core/holon/federation_holon.ex`
- `lib/mix/tasks/holon.verify.ex`

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2025-12-30 |
| Author | Cybernetic Architect |
| Status | READY FOR EXECUTION |
