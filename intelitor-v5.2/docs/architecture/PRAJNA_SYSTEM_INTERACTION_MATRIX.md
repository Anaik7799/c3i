# PRAJNA SYSTEM INTERACTION MATRIX (7x7)
**Classification**: ARCHITECTURAL ANALYSIS
**Status**: APPROVED
**Version**: 1.0.0
**Target**: Phase 2 Integration & Beyond

---

## 1.0 ABSTRACT
This document performs a deep-dive "Cross-Product Analysis" of the Prajna/Indrajaal system. It maps the **7 Core Features** against the **7 Levels of System Interaction**, identifying implications, constraints, and verification targets for every intersection. This ensures that features are not just "implemented" but are "systemically coherent" from the electron level to the human cognitive level.

## 2.0 THE AXES

### Y-AXIS: Core Features (Capabilities)
1.  **F1: Zero-Copy Telemetry** (High-speed sensor data ingestion)
2.  **F2: Safety-Critical Control** (Two-Key Turn, ARM/FIRE)
3.  **F3: State Synchronization** (KMS/Holon Digital Twin)
4.  **F4: Cognitive OODA Loop** (Observe-Orient-Decide-Act)
5.  **F5: Immune System** (Guardian, Anomaly Detection)
6.  **F6: Dark Cockpit UX** (TUI, Attention Management)
7.  **F7: Neuro-Symbolic AI** (LLM Integration, Copilot)

### X-AXIS: Interaction Levels (Implications)
1.  **L1: Atomic/Physical** (Memory, CPU, Threads, Bytes)
2.  **L2: Component/Module** (Functions, Types, Interfaces)
3.  **L3: Holon/Agent** (State, Behavior, Lifecycle)
4.  **L4: Container/Runtime** (Process, OS, Resources)
5.  **L5: Network/Mesh** (Protocol, Latency, Bandwidth)
6.  **L6: System/Federation** (Consensus, Truth, Consistency)
7.  **L7: Human/Cognitive** (Semantics, Ethics, Attention)

---

## 3.0 MATRIX ANALYSIS

### 3.1 FEATURE F1: ZERO-COPY TELEMETRY

| Level | Implication / Constraint | Verification Target |
| :--- | :--- | :--- |
| **L1** | **Memory Pressure**: High throughput (10k/sec) risks GC pauses. **Implication**: Must use `Struct` types and `Span<T>` buffers to avoid allocation churn. | `GC.CollectionCount` < 1 per min under load. |
| **L2** | **Type Safety**: Raw bytes must map to `Domain.SmartMetric` without exception. **Implication**: Strict serialization schema (MessagePack/Zenoh-CDR). | Fuzz testing deserializer. |
| **L3** | **Mailbox Saturation**: `SmartMetrics` agent mailbox could overflow. **Implication**: Implement "Drop-Oldest" or "Backpressure" policy (Bounded Mailbox). | Mailbox size monitoring. |
| **L4** | **Socket Contention**: F# and Elixir sharing net stack. **Implication**: Ephemeral port exhaustion risks. Reuse Zenoh sessions. | `netstat` port tracking. |
| **L5** | **Bandwidth Flood**: "Firehose" mode can saturate 1Gbps. **Implication**: Zenoh traffic shaping / downsampling at source (Elixir). | Zenoh throughput limits. |
| **L6** | **Event Ordering**: UDP delivery is unordered. **Implication**: Metrics must carry source timestamp; processing must handle out-of-order arrival. | Timestamp linearity check. |
| **L7** | **Information Overload**: Human cannot process 10k events/sec. **Implication**: UI must aggregate/smooth data (Sparklines, Moving Averages). | UX refresh rate (max 60fps). |

### 3.2 FEATURE F2: SAFETY-CRITICAL CONTROL (COMMAND)

| Level | Implication / Constraint | Verification Target |
| :--- | :--- | :--- |
| **L1** | **Bit-Flip Errors**: Command payloads corrupted in memory. **Implication**: Checksums on critical structures. | CRC32 check. |
| **L2** | **State Transition**: Invalid command state (Idle -> Firing). **Implication**: F# Type System (DU) makes invalid states unrepresentable. | Compiler check + Unit tests. |
| **L3** | **Guardian Interception**: Command bypass. **Implication**: `Orchestrator` CANNOT emit without `Guardian` signature. | Property-based test (Adversarial). |
| **L4** | **Privilege Escalation**: Container root access. **Implication**: Commands execute as non-root user (Podman). | Capability drop check. |
| **L5** | **Replay Attacks**: Network snoopers re-sending "FIRE". **Implication**: Nonces and timestamps in command packets (Ed25519 signed). | Signature verification failure. |
| **L6** | **Split-Brain**: Two controllers issuing commands. **Implication**: Global lock / Lease required for Actuators. | 2oo3 Voting logic. |
| **L7** | **Mode Confusion**: User thinks system is DISARMED when ARMED. **Implication**: Clear, blinking, high-contrast TUI indicators. | UX visual regression test. |

### 3.3 FEATURE F3: STATE SYNCHRONIZATION (KMS)

| Level | Implication / Constraint | Verification Target |
| :--- | :--- | :--- |
| **L1** | **Race Conditions**: Concurrent updates to `CockpitState`. **Implication**: Immutable data structures + STM or Actor isolation. | Thread-safety stress test. |
| **L2** | **Schema Drift**: F# vs Elixir type mismatch. **Implication**: Shared schema definition (Protobuf/CDR) or "Tolerant Reader" pattern. | Contract integration tests. |
| **L3** | **Digital Twin Lag**: Holon state desync. **Implication**: "Staleness" property on all state; auto-invalidate after $N$ ms. | `isStale` predicate checks. |
| **L4** | **Persistence**: Crash recovery. **Implication**: SQLite WAL mode for durability of last known state. | Restart recovery test. |
| **L5** | **Partition Tolerance**: Network cut. **Implication**: Local cache valid for read-only; Writes rejected. | Partition simulation. |
| **L6** | **Eventual Consistency**: Convergent state. **Implication**: Vector Clocks or CRDTs for mergeable state. | Convergence property test. |
| **L7** | **Trust**: User trusting stale data. **Implication**: "Grey-out" UI elements immediately upon sync loss. | Stale data visual cues. |

### 3.4 FEATURE F4: COGNITIVE OODA LOOP

| Level | Implication / Constraint | Verification Target |
| :--- | :--- | :--- |
| **L1** | **Compute Latency**: Loop calculation taking too long. **Implication**: Optimized math libraries (`System.Numerics.Vectors`). | Benchmark (<1ms compute). |
| **L2** | **Decision Logic**: Heuristics vs Deterministic. **Implication**: Policy engine pattern; separation of rule sets. | Rule coverage analysis. |
| **L3** | **Agent Starvation**: OODA agent blocking on IO. **Implication**: Async/Await everywhere; distinct thread pool for IO. | Thread pool starvation monitor. |
| **L4** | **Resource Contention**: OODA eating CPU needed for safety. **Implication**: Priority scheduling / Nice values. | Process priority check. |
| **L5** | **Sensor Lag**: "Observing" old news. **Implication**: Discard metric frames older than Cycle Time. | Freshness gate. |
| **L6** | **Feedback Loop Stability**: Oscillating decisions (Flapping). **Implication**: Hysteresis and damping functions in `Decide` phase. | Stability analysis. |
| **L7** | **Explainability**: "Why did it do that?" **Implication**: OODA Loop Visualizer in UI showing active phase/decision. | "Why" log inspection. |

### 3.5 FEATURE F5: IMMUNE SYSTEM (SAFETY)

| Level | Implication / Constraint | Verification Target |
| :--- | :--- | :--- |
| **L1** | **Detection Speed**: Catching anomalies. **Implication**: SIMD instructions for outlier detection on data streams. | Detection latency (<100us). |
| **L2** | **Isolation**: Failing component taking down system. **Implication**: Bulkheads / Circuit Breakers. | Circuit breaker trip test. |
| **L3** | **Self-Defense**: Killing rogue agents. **Implication**: Supervisor hierarchy with kill authority. | Supervision restart test. |
| **L4** | **Containment**: Breach escape. **Implication**: seccomp profiles, read-only filesystems. | Penetration test. |
| **L5** | **Quarantine**: Network threat. **Implication**: Dynamic firewalling / topic blocking via Zenoh ACLs. | Access Control test. |
| **L6** | **Systemic Risk**: Cascading failure. **Implication**: Load shedding / Brownout protocol. | Load shed simulation. |
| **L7** | **Panic**: Operator alarm fatigue. **Implication**: Alarm prioritization (NUREG-0700); Smart silence. | Alarm rate analysis. |

### 3.6 FEATURE F6: DARK COCKPIT UX

| Level | Implication / Constraint | Verification Target |
| :--- | :--- | :--- |
| **L1** | **Render Cost**: TUI repaints burning CPU. **Implication**: Diff-based rendering (only update changed chars). | CPU usage during idle/load. |
| **L2** | **Component Reuse**: Inconsistent UI. **Implication**: Strict `AerospaceTheme` component library usage. | Visual consistency audit. |
| **L3** | **Responsiveness**: UI thread locking. **Implication**: Separate Render Thread vs Input Thread. | Input latency (<50ms). |
| **L4** | **Terminal Compatibility**: ANSI codes breaking. **Implication**: Capability detection (Terminfo); fallback to ASCII. | Cross-terminal verification. |
| **L5** | **Remote Access**: SSH latency. **Implication**: Low-bandwidth mode; client-side prediction not possible in TUI. | Bandwidth usage analysis. |
| **L6** | **Global View**: Summarizing 1000 nodes. **Implication**: Semantic zooming / Aggregation layers. | Aggregation logic check. |
| **L7** | **Cognitive Load**: Too much info. **Implication**: "Management by Exception" - hide nominal values. | Screen density metric. |

### 3.7 FEATURE F7: NEURO-SYMBOLIC AI

| Level | Implication / Constraint | Verification Target |
| :--- | :--- | :--- |
| **L1** | **Determinism**: LLM Output randomness. **Implication**: Seed fixing (where possible) + Parsing validation. | Output parsing success rate. |
| **L2** | **Hallucination**: Inventing facts. **Implication**: RAG (Retrieval Augmented Generation) grounded in KMS. | Fact check verification. |
| **L3** | **Latency**: LLM slow response. **Implication**: Async processing; UI shows "Thinking"; Fast path heuristics. | Response time tracking. |
| **L4** | **Data Privacy**: Sending secrets to cloud. **Implication**: PII Scrubbing / Redaction before API call. | DLP (Data Loss Prevention) test. |
| **L5** | **Cost**: Token usage $$. **Implication**: Token bucket rate limiting; Budget caps. | Cost tracking/limiting. |
| **L6** | **Alignment**: AI goals vs System goals. **Implication**: Constitutional AI prompt injection (Founder's Directive). | Alignment probe. |
| **L7** | **Trust Calibration**: Over-trusting AI. **Implication**: Confidence scores explicitly displayed; "Human in the loop" for actions. | Confidence UI check. |

---

## 4.0 SYNTHESIS & IMPLICATIONS FOR IMPLEMENTATION

### 4.1 Critical Path Interactions
The analysis reveals 3 critical intersections that require immediate architectural attention in Phase 2:

1.  **F1/L5 (Telemetry/Network)**: The "Firehose" problem. If Elixir pushes faster than F# consumes, buffers will bloat.
    *   *Decision*: Implement **Zenoh Flow Control** (dropping oldest) at the source or bridge level.
2.  **F2/L6 (Command/System)**: The "Split-Brain" risk.
    *   *Decision*: Commands MUST include a `lease_id` or `epoch` to ensure only the active leader's commands are obeyed.
3.  **F3/L7 (State/Human)**: The "Stale Data" trust issue.
    *   *Decision*: UI elements MUST visually decay (dim/gray out) within 500ms of signal loss.

### 4.2 Verified "Safe Harbor" Patterns
To navigate these risks, the following patterns are mandated:
*   **The Simplex Arch**: Complex AI/Heuristics (F7) are *always* wrapped by Simple Safety Checks (F5).
*   **The Immutable Ledger**: All state changes (F3) are append-only logs at L3/L4.
*   **The Bicameral Bridge**: F# and Elixir treat each other as "External Systems" requiring strict contract validation at L2/L5.

---

**Document Control:**
*   **Generated By**: Gemini (Cybernetic Architect)
*   **Date**: 2026-01-15
*   **Approval**: Automatic via AEE Protocol
