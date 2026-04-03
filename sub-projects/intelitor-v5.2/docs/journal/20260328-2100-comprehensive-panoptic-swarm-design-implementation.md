# Comprehensive Implementation & Design Approach: Panoptic Swarm Ignition

**Date**: 20260328-2100 CEST
**Status**: ACTIVE
**Author**: Gemini (Cybernetic Architect - Multilayer Swarm Supervisor)
**Classification**: SIL-6 BIOMORPHIC INFRASTRUCTURE - OMNIPRESENT

## 1. Executive Summary: The Multilayer Swarm Paradigm
The **Panoptic Swarm Ignition** represents the evolutionary leap from disparate configuration files and bash/Elixir setup scripts into a purely mathematical, strictly typed **F# Morphogenesis Engine**. 

Under this paradigm, the **Multilayer Swarm in Full Parallelization mode** becomes the default execution context. All containers (App, DB, Obs, Cortex, Zenoh Routers, ML Runners) are conceptually modeled as interdependent cells in a biological organism. The F# orchestrator (`cepaf`) acts as the genome sequencer, validating the mathematical consistency of the entire swarm before a single container is spawned.

This plan details the exhaustive fractal migration, the architectural checks, and the implementation strategy to establish this autonomic ecosystem.

---

## 2. Fractal Layer Migration & Mathematical Control Checks (L0-L7)

### L0: Runtime (Code & Genome)
*   **Current State**: Dockerfiles and container base layers reside in plain text in the repository root or `containers/` directory. They are subject to silent drift, manual edits, and untracked mutations.
*   **Target State**: Embedded F# literal strings (`Artifacts.fs`) serve as the immutable DNA of the system.
*   **Implementation & Check**: 
    - The F# engine implements `verifyArtifact()`, reading the physical `Dockerfile` on disk and performing a BLAKE3 cryptographic hash comparison against the embedded genome. 
    - **FEMA/Risk**: If a developer manually modifies a `Dockerfile`, the system enters "Genetic Drift" state. 
    - **Mitigation (SC-IGNITE-001)**: The engine triggers a "Re-Synthesis" phase, overwriting the drifted file with the mathematically verified canonical version before calling Podman build.

### L1: Function (Execution & Contracts)
*   **Current State**: Environment variables and startup constraints are managed via `.env` files and scattered `entrypoint.sh` scripts.
*   **Target State**: F# Algebraic Data Types (ADTs) in `EnvironmentConfig.fs` strictly define the expected environment.
*   **Implementation & Check**: 
    - Configuration is no longer parsed as raw strings; it is mapped into discriminated unions (e.g., `PortMapping`, `VolumeMount`).
    - **FEMA/Risk**: Type-mismatch in environment injection (e.g., passing a string where an integer port is expected) causes container crash loops.
    - **Mitigation**: The F# compiler mathematically guarantees that environment contracts are satisfied. Ports are checked for collision within the F# domain model before any Podman command is executed.

### L2: Component (Service Cohesion & DAGs)
*   **Current State**: `podman-compose.yml` uses simple `depends_on` clauses. If a service like TimescaleDB is up but not ready to accept connections, the Elixir app crashes on boot.
*   **Target State**: Directed Acyclic Graph (DAG) orchestration in `PanopticIgnition.fs`.
*   **Implementation & Check**: 
    - The F# engine constructs a mathematical DAG of all 14 swarm components.
    - **FEMA/Risk**: Deadlocks or cyclical dependencies in the boot sequence.
    - **Mitigation (SC-BOOT-009)**: A topological sort is performed on the DAG. If a cycle is detected, the F# program refuses to compile/run the ignition sequence. Startups are grouped into parallel "Waves" (Foundation -> Mesh -> Cognitive -> Application).

### L3: Holon (Data Sovereignty & Persistence)
*   **Current State**: Volume mounts are blindly mapped to `./data`.
*   **Target State**: `DatabasePath.fs` controls all state persistence, strictly isolating SQLite/DuckDB files per holon.
*   **Implementation & Check**: 
    - **FEMA/Risk**: Volume Shadowing (Axiom 0.2). An empty host directory mounted over a critical container path (e.g., `/etc/nginx`) will wipe the container's configuration.
    - **Mitigation (Axiom 0.2 Check)**: The F# orchestrator inspects the host file system. If a volume source is designated but unseeded, and it targets a known critical path, the orchestrator triggers Jidoka and halts ignition.

### L4: Container (Isolation & Runtime)
*   **Current State**: Podman is executed via raw shell commands or compose wrappers without strict rootless verification.
*   **Target State**: The `Cepaf.Podman.Api.Containers` module wraps the Podman REST API/CLI, mathematically enforcing security boundaries.
*   **Implementation & Check**: 
    - **FEMA/Risk**: Glibc/Musl NIF conflicts caused by host-compiled `_build` and `deps` directories leaking into the container.
    - **Mitigation (Axiom 0.1 Check)**: Before spawning the Elixir App container, the F# orchestrator actively scans for `_build` and `deps` on the host. If found, it executes `rm -rf _build deps` automatically to guarantee substrate integrity. All images MUST use the `localhost/` prefix.

### L5: Node (Hardware Metabolism & Homeostasis)
*   **Current State**: CPU and RAM limits are hardcoded, leading to either starvation or OOM kills depending on the host machine.
*   **Target State**: `MetabolicTools.fs` dynamically interrogates host hardware to size the swarm.
*   **Implementation & Check**: 
    - **FEMA/Risk**: Exhaustion of system resources leading to cascading kernel panics.
    - **Mitigation**: The F# orchestrator detects available cores. It dynamically injects `ELIXIR_ERL_OPTIONS="+S <Cores>"` and sets `MIX_OS_DEPS_COMPILE_PARTITION_COUNT` to guarantee 100% hardware utilization without thrashing. It allocates 200% virtual target load to ensure saturation.

### L6: Cluster (Consensus & Quorum)
*   **Current State**: Independent nodes attempt to cluster via simple EPMD without strong mesh verification.
*   **Target State**: Zenoh-backed 2oo3 Voting Quorum established before application boot.
*   **Implementation & Check**: 
    - **FEMA/Risk**: Split-brain scenarios where nodes boot isolated from the mesh control plane.
    - **Mitigation (SC-SIL6-006)**: Ignition Phase 3 (Mesh) boots 3 Zenoh routers. The orchestrator physically waits for a 2-out-of-3 quorum consensus signal over the Zenoh FFI before proceeding to boot the Application (Phase 5). 

### L7: Federation (Existential Ark & Alignment)
*   **Current State**: Telemetry and alignment checks are scattered across Elixir apps.
*   **Target State**: The Supreme Directive (Ω₀ - Founder's Covenant) is enforced by the F# `Guardian.fs` interface during ignition.
*   **Implementation & Check**: 
    - **FEMA/Risk**: Evolution drift away from the system's core alignment.
    - **Mitigation**: The Orchestrator requires a SHA256 `ProofToken` from the `PrometheusGate` confirming that the generated configuration maintains 100% STAMP compliance. Without this mathematical proof, the Swarm refuses to ignite.

---

## 3. High-Fidelity Dashboard & Observability
The Panoptic Ignition provides unparalleled visual feedback into the "Mind of the Machine".

1.  **Agent Thinking (`logThinking`)**: F# outputs real-time internal cognition states:
    - *[THINK] Analyzing genome for indrajaal-db-prod...*
    - *[THINK] Waking zenoh-router-1...*
2.  **Zenoh Telemetry**: These thinking states are published to `indrajaal/ignition/thinking`. 
3.  **MCP Integration**: The supervisor agent connects via `.mcp.json` to the F# daemon, querying the precise ignition state and proposing solutions if a node fails the `HealthProbe`.
4.  **OTel Spans**: Every container lifecycle event is wrapped in an OpenTelemetry span, sent to the SigNoz instance.

---

## 4. Execution Plan: Full Autonomous Mode
This plan will be executed strictly using the **Hierarchical Numbering** format and tracked exclusively via the **F# Planning CLI (`sa-plan`)**.

*   **1.0 Documentation & State Synchronization**
    *   1.1 Sync `CLAUDE.md`, `GEMINI.md`, and `.claude/rules/` with the new Panoptic Ignition and F#-only planning rules.
    *   1.2 Create `multilayer-swarm` agent skill to enforce full parallelization.
*   **2.0 F# Core Enhancement**
    *   2.1 Migrate YAML definitions into `ComposeTypes.fs` ADTs.
    *   2.2 Implement Volume Shadowing (Axiom 0.2) and Substrate Integrity (Axiom 0.1) checks in F#.
    *   2.3 Implement OTel, Zenoh, and MCP hooks in the `cepaf` daemon.
*   **3.0 Panoptic Swarm Boot Sequence**
    *   3.1 Execute `sa-up` using the new F# engine.
    *   3.2 Run the 5-Wave parallel boot sequence.
    *   3.3 Verify 14-container Homeostasis.
*   **4.0 Fractal RCA & Supervisor Agent**
    *   4.1 Instantiate the Supervisor Agent via MCP.
    *   4.2 If issues occur during boot, automatically trigger the 7-Level Fractal RCA, dump to journal, and self-heal.