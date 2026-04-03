# INDRAJAAL 9-LEVEL FRACTAL ARCHITECTURE SPECIFICATION
**Version**: 2.0.0
**Status**: APPROVED (SIL-6 Biomorphic)
**Date**: 2026-01-12
**Reference**: GEMINI.md Section 96.0

---

## 1.0 Architectural Philosophy
The Indrajaal system is designed as a **Biomorphic Fractal Mesh**. It is not a monolith, nor microservices; it is a Holarchy. Each level of the system mirrors the structure of the whole, ensuring that Safety (STAMP), Intelligence (OODA), and Observability (Zenoh) are preserved from the atomic line of code up to the global universe of interaction.

### The 9 Levels of Indrajaal
1.  **L1: Atomic** (Functions, Types, Predicates)
2.  **L2: Component** (GenServers, Supervisors, Modules)
3.  **L3: Holon** (Autonomous Agents, Domains)
4.  **L4: Container** (Runtime Isolation, Podman, NixOS)
5.  **L5: Node** (Host OS, Hardware, Startup Scripts)
6.  **L6: Mesh** (Cluster, Zenoh, Tailscale)
7.  **L7: Federation** (Global Knowledge, Evolution, Governance)
8.  **L8: Ecosystem** (External APIs, Webhooks, User Data, Community)
9.  **L9: Universe** (History, Entropy, Long-term Archival, Legacy)

---

## 2.0 Detailed Level Specifications

### Level 1: ATOMIC (The Cell)
**Scope**: Pure functions, Data Structures, Type Specifications.
**Objective**: Mathematical correctness and contract enforcement.

*   **Implementation**:
    *   **Language**: Elixir Types, Ash Resources, Structs.
    *   **Files**: `lib/indrajaal/core/types.ex`, `lib/indrajaal/schema/*.ex`.
    *   **Validation**: Dialyzer, Credo, PropCheck (Property-Based Testing).
*   **Safety Invariant (STAMP)**:
    *   *Inputs must strictly match Type Specs.*
    *   *No side effects in pure reducers.*
*   **Observability**:
    *   `Logger.debug` for trace-level execution flow.
    *   Telemetry spans for function execution time.

### Level 2: COMPONENT (The Organ)
**Scope**: State management, Concurrency, Supervision.
**Objective**: Fault tolerance and self-healing (OTP).

*   **Implementation**:
    *   **Pattern**: GenServer, Task, Agent, Supervisor.
    *   **Core Module**: `Indrajaal.Observability.ZenohCoordinator` (The heart).
    *   **Files**: `lib/indrajaal/application.ex` (Supervision Tree).
*   **Zenoh Primacy (Axiom 8)**:
    *   **Constraint**: Zenoh components MUST be the *First Up* (Child #1) and *Last Down* in the supervision tree.
    *   **Verification**: `Application.start/2` logic checks child order.
*   **Safety Invariant (STAMP)**:
    *   *Let it Crash* (but log why).
    *   *Supervisors must have restart strategies (one_for_one).*

### Level 3: HOLON (The Organism)
**Scope**: Business Logic, OODA Loops, Decision Making.
**Objective**: Autonomy and Goal-Directed Behavior.

*   **Implementation**:
    *   **Architecture**: The 50-Agent Hierarchy (Executive, Domain Supervisors, Workers).
    *   **Brain**: `Indrajaal.Cortex` (Neuro-Symbolic AI).
    *   **Files**: `lib/indrajaal/cortex/synapse.ex`, `lib/indrajaal/agents/*.ex`.
*   **OODA Loop**:
    *   **Observe**: Ingest data from L2 components.
    *   **Orient**: Contextualize via IKE (Knowledge Engine).
    *   **Decide**: AI/Heuristic selection.
    *   **Act**: Dispatch commands to L2 actuators.
*   **Safety Invariant**:
    *   *Simplex Architecture*: AI proposals must pass the `Guardian` (deterministic safety check) before execution.

### Level 4: CONTAINER (The Habitat)
**Scope**: Runtime Environment, Isolation, Dependencies.
**Objective**: Reproducibility and Security.

*   **Implementation**:
    *   **Engine**: Podman (Rootless).
    *   **OS**: NixOS (Immutable).
    *   **Sync**: PHICS (Phoenix Hot-Reloading Integration Container System).
    *   **Files**: `Containerfile.nixos`, `podman-compose.yml`.
*   **Conditional Debugging (Axiom 7)**:
    *   If a specific Holon/Container fails, *only* that container switches to `DEBUG` log level via dynamic ENV injection.
*   **Safety Invariant**:
    *   *No Root Access*.
    *   *Read-Only Root Filesystem (in Prod)*.

### Level 5: NODE (The Host)
**Scope**: Boot Process, Hardware Resources, OS Integration.
**Objective**: Reliable Startup and Resource Management.

*   **Implementation**:
    *   **Script**: `sa-up`, `sa-down`.
    *   **Resources**: CPU, RAM, Network Interfaces.
*   **Tri-Stream Observability (Axiom 7)**:
    *   **Requirement**: ALL startup/shutdown logs must stream to:
        1.  **Console** (Human readable).
        2.  **File** (Audit trail: `data/logs/boot-*.log`).
        3.  **Zenoh** (Network stream to Federation).
*   **Safety Invariant**:
    *   *Boot Integrity*: If `sa-up` fails any health check, it must rollback.

### Level 6: MESH (The Colony)
**Scope**: Distributed Communication, Cluster State.
**Objective**: Consensus and Data Availability.

*   **Implementation**:
    *   **Transport**: Zenoh (Data Plane), Erlang Distribution (Control Plane).
    *   **Network**: Tailscale (Identity-based Routing).
    *   **Files**: `lib/indrajaal/mesh/*.ex`.
*   **Zenoh Primacy**:
    *   The Mesh is the *Central Nervous System*. It connects L5 Nodes.
    *   Telemetry flow: Node -> Zenoh -> Aggregator.
*   **Safety Invariant**:
    *   *Quorum*: 2-out-of-3 voting for critical state changes.
    *   *Partition Tolerance*: Graceful degradation if Tailscale splits.

### Level 7: FEDERATION (The Ecosystem)
**Scope**: Global Knowledge, Long-term Evolution, Governance.
**Objective**: Anti-Fragility and Infinite Game.

*   **Implementation**:
    *   **System**: IKE (Indrajaal Knowledge Engine).
    *   **Memory**: Vector Database (Embeddings), `GEMINI.md` (Constitution).
    *   **Evolution**: GDE (Goal-Directed Evolution) algorithms.
*   **Function**:
    *   Aggregates L6 Mesh data to update L1/L2 code (Self-Writing Code).
*   **Safety Invariant**:
    *   *Founder's Directive*: Core axioms cannot be rewritten by the AI.

### Level 8: ECOSYSTEM (The Market)
**Scope**: External APIs, Webhooks, User Interactions, Community.
**Objective**: Adaptation and Value Exchange.

*   **Implementation**:
    *   **System**: API Gateway, Webhooks, Community Forum integration.
    *   **Interactions**: External data ingestion, user feedback loops.
    *   **Revenue**: Pricing models, subscription management (via Stripe/external providers).
*   **Function**:
    *   Facilitates exchange of value and information with the external world.
    *   Adapts internal structures (L1-L7) based on external feedback (Market Fit).
*   **Safety Invariant**:
    *   *Trust Boundaries*: Strict validation of all external inputs.
    *   *Rate Limiting*: Protection against external floods.

### Level 9: UNIVERSE (The Timeline)
**Scope**: History, Entropy, Archival, Existential Risks.
**Objective**: Legacy and controlled Entropy management.

*   **Implementation**:
    *   **System**: Long-term archival storage (Cold Storage), Entropy monitors.
    *   **Process**: Apoptosis (Controlled shutdown/end-of-life protocols).
    *   **Ethics**: Long-term ethical alignment checks.
*   **Function**:
    *   Manages the lifecycle of the entire system over time.
    *   Ensures data preservation beyond the active life of the system.
*   **Safety Invariant**:
    *   *Heat Death Prevention*: Mechanisms to detect and mitigate system-wide entropy increase.
    *   *Graceful Exit*: Protocols for safe, data-preserving system shutdown (Apoptosis).

---

## 3.0 Cross-Cutting Implementations

### 3.1 Tri-Stream Observability (Implementation of Axiom 7)
**Applied at Levels**: L2, L3, L4, L5.

**Mechanism**:
All `Logger` calls and `IO.puts` in startup scripts are intercepted and multiplexed.
```elixir
# Conceptual Elixir Implementation
def log(msg, level) do
  # 1. Console
  IO.puts(format_console(msg))
  # 2. File
  File.write!("logs/current.log", format_file(msg), [:append])
  # 3. Zenoh
  Zenoh.publish("indrajaal/logs/#{level}", msg)
end
```

### 3.2 Zenoh Primacy (Implementation of Axiom 8)
**Applied at Levels**: L2 (Supervision), L6 (Mesh).

**Mechanism**:
In `lib/indrajaal/application.ex`, the `ZenohCoordinator` is the **head** of the list.
```elixir
def start(_type, _args) do
  children = [
    # FIRST UP
    Indrajaal.Observability.ZenohCoordinator,
    # ... business logic ...
  ]
  Supervisor.start_link(children, ...)
end
```

---

## 4.0 Verification Matrix (9x9 Check Integration)
This architecture supports the 9x9 Fractal Verification Matrix (L1-L9 x Capabilities).

**Compliance Check**:
- [x] L1 Atomic Types Checked
- [x] L2 Component Supervision Ordered (Zenoh First)
- [x] L3 Holon OODA Loops Active
- [x] L4 Container PHICS Enabled
- [x] L5 Node Tri-Stream Logging Active
- [x] L6 Mesh Zenoh Connected
- [x] L7 Federation Constitution Verified
- [x] L8 Ecosystem Interactions Validated
- [x] L9 Universe Entropy Monitored
