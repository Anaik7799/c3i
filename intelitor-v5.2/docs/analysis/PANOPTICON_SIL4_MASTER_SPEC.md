# Panopticon SIL6 Infrastructure: Grand Unification Master Spec
**Version**: 6.0.0-ULTIMATE
**Classification**: IMMUTABLE SYSTEM AXIOMS
**Compliance**: IEC 61508 SIL6 / HFT=2 / SFF > 99.99%

---

## Level 1: Strategic Strategy (The "Why")
*Goal: Total Observability and fail-safe Evolution.*

### 1.1 The Directed Telescope Vision
The Panopticon is a **Parallel Control Plane** that transforms the system under test into a directed telescope. It routes real-world traffic into bit-perfect shadow sandboxes to prove correctness *before* actuation.

### 1.2 SIL6 Compliance Matrix
*   **Fail-Safe**: Any discrepancy in 2oo3 voting triggers immediate **JIDOKA** (Automatic Halt).
*   **Determinism**: Time-triggered execution ensures worst-case execution time (WCET) is respected.
*   **Independence**: The Observer (Test Manager) is logically and physically separated from the Observed (Logic).

---

## Level 2: Topological Design (The "Where")
*Goal: Redundant fail-safe Isolation.*

### 2.1 The 2oo3 Voting Substrate
The system operates 3 parallel holon types within the **Panopticon Network** (`172.31.0.0/16`):
1.  **Primary (Live)**: The production actor.
2.  **Shadow (WASM)**: A high-fidelity replica in a restricted sandbox.
3.  **Model (TLA+)**: A mathematical formalization of the expected state.

### 2.2 Substrate Isolation
*   **Network**: Shadow nodes cannot communicate with external actuators.
*   **Memory**: WASM isolation ensures shadow buffer overflows cannot crash the primary BEAM.
*   **Observability**: eBPF probes monitor every syscall at the Tissue layer.

---

## Level 3: Behavioral Logic (The "How")
*Goal: Transactional Integrity & OODA Homeostasis.*

### 3.1 5-Stage Transactional Boot (The "Ignition")
1.  **PREFLIGHT**: Verify genotype hashes against `twin_config_schema.json`.
2.  **DATA-IGNITION**: Parallel spawn of DB1/DB2 with synchronous WAL commit.
3.  **LENS-ALIGNMENT**: Launch Shadow Holons + F# 2oo3 Judge.
4.  **MESH-CONVERGENCE**: Distributed quorum achieved via Zenoh discovery.
5.  **STEADY-STATE**: Heartbeat pulse initialized; Ingress opened.

### 3.2 5-Stage Transactional Shutdown (The "Apoptosis")
1.  **DRAIN**: Redirect traffic to 'Safe Sink'.
2.  **CHECKPOINT**: Trigger DB `CHECKPOINT` and OBS `flush` via Embedded Watchdogs.
3.  **SNAPSHOT**: Serialize Digital Twin state to DuckDB columnar store.
4.  **SIGNAL**: Send `SIGTERM` to all processes; wait for Watchdog ACK.
5.  **RELEASE**: Destroy ephemeral network and release port substrate.

---

## Level 4: Component Functional Detail (The "What")
*Goal: High-Fidelity Instrumentation & Analytics.*

### 4.1 The Judge (2oo3 Voter)
*   **Logic**: Receives payloads from L/S/M. Wait for Quorum or 10ms.
*   **Verdict**: Emit `0xMATCH` if identical. Trigger `0xFAULT` on mismatch.
*   **Telemetry**: Logs latency, payload hash, and voting ID.

### 4.2 The directed Telescope (F# Cockpit)
*   **Optics**: recursive zoom logic switched via TUI keys `[1-5]`.
*   **Metabolism**: Real-time visualization of container CPU/Mem/Heartbeat.
*   **Forensics**: Unified view joining SQLite (Control) and DuckDB (Data).

---

## Level 5: Implementation Logic (The "Cellular")
*Goal: Mathematical Proof & Cellular Safety.*

### 5.1 Formal Verification & Proofs
*   **TLA+**: `consensus.tla` defines the state machine for 2oo3 voting.
*   **Agda**: Formal proof of `FQUN-Uniqueness` ensuring deterministic node identification.
*   **HLC**: Hybrid Logical Clocks provide causality-preserving timestamps across the mesh.

### 5.2 Deterministic Chaos Vectors
*   **Byzantine Faults**: Simulating nodes that send conflicting or malformed data.
*   **Clock Drift**: Injecting +/- 500ms skew to verify HLC resilience.
*   **Network Flap**: Simulating partition events to verify quorum re-election.

### 5.3 Compliance-as-Code (SRS Mapping)
Every requirement in the SRS is mapped via `@Req-ID` metadata:
*   `@Req-SIL6-12.1` -> `scripts/verification/verify_transactions.exs`
*   `@Req-SIL6-05.4` -> `lib/cepaf/src/Cepaf/Mesh/PanopticonOrchestrator.fs`

---

## 6.0 Tooling & Resource Registry
| Tier | Tool | Purpose |
| :--- | :--- | :--- |
| **Orchestrator** | Podman + CEPAF | fail-safe container lifecycle. |
| **Service Mesh** | Envoy + Istio | Traffic shadowing and mirroring. |
| **Telemetry** | Zenoh + DuckDB | High-velocity state capture. |
| **Verification** | TLA+ + Agda | Formal logic assurance. |
| **HMI** | Cockpitf (F#) | Directed Telescope visualization. |
