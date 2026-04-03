# Plan: Indrajaal v20.0.0 Evolution Phase 2 & 3 - Cognitive, Immune & Autonomic Activation

**Created**: 20251231-1500 CEST
**Last Updated**: 20251231-1510 CEST
**Status**: DRAFT
**Framework**: SOPv5.11 + TPS (Jidoka + 5-Level RCA) + VSM + Biomorphic

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20251231-1500 CEST | CREATED | Initial plan for Phase 2 evolutions | Gemini (Cybernetic Architect) |
| 20251231-1510 CEST | UPDATED | Added Phase 3: Autonomic Maturation | Gemini (Cybernetic Architect) |

## Executive Summary
This plan outlines the activation of the Indrajaal cognitive, immune, and autonomic systems. Phase 2 focuses on closing the OODA loop and threat hunting. Phase 3 focuses on epigenetic evolution, resource symbiosis, and ethical arbitration.

## 5-Level Detailed Plan

### 1.0 - Infrastructure Nervous System (Neural Bridge) (Priority: P0)
#### 1.1 - Rustler-based Zenoh NIF Integration
##### 1.1.1 - Zenoh NIF Porting
###### 1.1.1.1 - Define native Zenoh session management
- 1.1.1.1.1 - Implement `zenoh_open` in Rustler NIF
- 1.1.1.1.2 - Implement `zenoh_close` for graceful shutdown
###### 1.1.1.2 - High-throughput Publisher
- 1.1.1.2.1 - Optimize binary payload serialization in Rust
- 1.1.1.2.2 - Implement async publishing to `indrajaal/infra/**`
##### 1.1.2 - CEPAF-Zenoh Real-time Feedback
###### 1.1.2.1 - Container Event Tap
- 1.1.2.1.1 - Hook into CEPAF container lifecycle events
- 1.1.2.1.2 - Map CEPAF events to Zenoh hierarchical keys
###### 1.1.2.2 - Telemetry Bridge Validation
- 1.1.2.2.1 - Measure latency between CEPAF event and Zenoh arrival
- 1.1.2.2.2 - Verify zero-copy integrity of telemetry packets

### 2.0 - Cognitive Bootstrapping (Cortex Activation) (Priority: P1)
#### 2.1 - Active Inference Engine Integration
##### 2.1.1 - Cortex GenServer Realization
###### 2.1.1.1 - Stream Subscription
- 2.1.1.1.1 - Subscribe Cortex to `indrajaal/neural/stream`
- 2.1.1.1.2 - Implement windowed buffering for belief updating
###### 2.1.1.2 - Surprise Calculation
- 2.1.1.2.1 - Implement variational free energy calculation
- 2.1.1.2.2 - Map signal deviations to "Surprise" scores
##### 2.2 - Autonomic Proposal Generation
###### 2.2.1 - Guardian Handshake
- 2.2.1.1.1 - Implement proposal submission to `Guardian.validate_proposal/1`
- 2.2.1.1.2 - Handle `{:veto, reason, fallback}` responses from Guardian
###### 2.2.2 - Action Selection Logic
- 2.2.2.1.1 - Implement epistemic vs pragmatic value balancing
- 2.2.2.1.2 - Select actions that minimize future expected free energy

### 3.0 - Deep Immune Intelligence (Sentinel Enrichment) (Priority: P1)
#### 3.1 - Pattern-Based Threat Hunting
##### 3.1.1 - PatternDatabase Integration
###### 3.1.1.1 - Signature Loading
- 3.1.1.1.1 - Import complex signatures from `PatternDatabase`
- 3.1.1.1.2 - Configure Sentinel to refresh signatures every 60s
###### 3.1.1.2 - Multi-stage Attack Detection
- 3.1.1.2.1 - Implement stateful correlation of signals
- 3.1.1.2.2 - Match "Low & Slow" attack patterns
##### 3.2 - Proactive Immunization
###### 3.2.1 - Guardian Near-Miss Learning
- 3.2.1.1.1 - Subscribe Sentinel to `indrajaal/safety/violations`
- 3.2.1.1.2 - Auto-generate immune signatures from Guardian vetoes
###### 3.2.2 - Failsafe Verification
- 3.2.2.1.1 - Stress test surgical suspension on non-critical pids
- 3.2.2.1.2 - Verify SC-IMMUNE-002 (Kernel protection) during mass quarantine

### 4.0 - FAME Metadata Automation (Priority: P2)
#### 4.1 - FAME.Generator Pipeline
##### 4.1.1 - Metadata Ingestion
###### 4.1.1.1 - Source Scanning
- 4.1.1.1.1 - Scan lib/ for missing @meta and @impact blocks
- 4.1.1.1.2 - Extract dependency graphs for @impact population
###### 4.1.1.2 - Automated Block Generation
- 4.1.1.2.1 - Utilize AI to generate @evolution and @agent_context blocks
- 4.1.1.2.2 - Validate generated blocks against `FAME.Schema`
##### 4.2 - Continuous Validation
###### 4.2.1 - FAME Quality Gate
- 4.2.1.1.1 - Integrate FAME validation into `mix compile`
- 4.2.1.1.2 - Fail build if P0 artifacts lack metadata

### 5.0 - Prajna Holographic Cockpit (Priority: P2)
#### 5.1 - Biomorphic Visualization
##### 5.1.1 - LiveView Holography
###### 5.1.1.1 - Fractal Health Tree
- 5.1.1.1.1 - Render recursive holon health states in 3D/CSS
- 5.1.1.1.2 - Implement real-time pulsing for heartbeat visualization
###### 5.1.1.2 - Neuro Stream Overlay
- 5.1.1.2.1 - Overlay Active Inference free energy gradients
- 5.1.1.2.2 - Visualize Sentinel quarantine events in real-time

### 6.0 - Epigenetic Code Evolution (Self-Modification) (Priority: P1)
#### 6.1 - Genetic Payload Management
##### 6.1.1 - Artifact Genome Realization
###### 6.1.1.1 - Mapping Source AST to KMS Holons
- 6.1.1.1.1 - Implement persistent binary genome storage in KMS.
- 6.1.1.1.2 - Integrate epigenetic markers into FAME metadata blocks.
#### 6.2 - Autonomic Refactoring Engine
##### 6.2.1 - FEP-Driven Optimization
###### 6.2.1.1 - Entropy-Based Refactoring Triggers
- 6.2.1.1.1 - Identify high-variational free energy code paths via Cortex.
- 6.2.1.1.2 - Generate autonomic refactor proposals for Guardian review.

### 7.0 - Metabolic Computing (Resource Symbiosis) (Priority: P2)
#### 7.1 - Resource Autophagy (Self-Digestion)
##### 7.1.1 - FLAME Credit Reclamation
###### 7.1.1.1 - Apoptosis Triggers
- 7.1.1.1.1 - Implement idle node detection and credit recycling logic.
- 7.1.1.1.2 - Redistribute reclaimed "Energy" to System 3 Control budgets.
#### 7.2 - Stigmergic Load Migration
##### 7.2.1 - Heat-Gradient Following
###### 7.2.1.1 - Zenoh Thermal Signaling
- 7.2.1.1.1 - Broadcast node-level CPU/Thermal "Heat" signals via Zenoh.
- 7.2.1.1.2 - Enable holon teleportation toward low-heat/high-resource nodes.

### 8.0 - Stigmergic Coordination (Pheromone Mesh) (Priority: P2)
#### 8.1 - Pheromone Mesh Signaling
##### 8.1.1 - Signal Decay Management
###### 8.1.1.1 - Zenoh Key-Expression TTL
- 8.1.1.1.1 - Implement time-to-live logic for state pheromones.
- 8.1.1.1.2 - Map decay rates to signal reliability in the Inference Engine.
#### 8.2 - Swarm Intelligence Validation
##### 8.2.1 - Quorum Sensing
###### 8.2.1.1 - Emergent Pattern Verification
- 8.2.1.1.1 - Implement holon density detection protocols.
- 8.2.1.1.2 - Validate emergent load-balancing against SC-FRAC invariants.

### 9.0 - Ethical Arbitration (Constitutional Court) (Priority: P1)
#### 9.1 - VSM System 5 Activation
##### 9.1.1 - Constitutional Court Engine
###### 9.1.1.1 - Action-to-Axiom Mapping
- 9.1.1.1.1 - Correlate Guardian proposals with Jain Constitution axioms.
- 9.1.1.1.2 - Implement the Constitutional Veto for unethical autonomic actions.
#### 9.2 - Reversibility Enforcement
##### 9.2.1 - Temporal Undo Protocols
###### 9.2.1.1 - Mandatory State Checkpointing
- 9.2.1.1.1 - Implement pre-action serialization for all P0 operations.
- 9.2.1.1.2 - Execute StateTeleporter-based rollback on axiom violation.

## Success Criteria
- [ ] CEPAF events visible in Zenoh Neural Stream with <1ms latency.
- [ ] Cortex successfully proposes a scale-up action that Guardian approves.
- [ ] Sentinel neutralizes a mock threat signature within 50ms of detection.
- [ ] 100% FAME metadata coverage for core `lib/indrajaal/core/` files.
- [ ] Prajna dashboard displays the "Biomorphic Vital Signs" of the cluster.
- [ ] Constitutional Court successfully vetoes a mock action that violates "Ahimsa."

## Risk Assessment
- **High Complexity**: Rustler NIF stability may impact BEAM uptime. Mitigation: Run in Shadow Mode.
- **Latency**: Active Inference calculation may exceed 10ms. Mitigation: Offload to FLAME runners.
- **Auto-Immune**: Sentinel could quarantine a critical system process. Mitigation: Strict SC-IMMUNE-002 verification.
- **Ethical Drift**: AI models might find "Loopholes" in the constitution. Mitigation: Formal verification of axiom mapping.