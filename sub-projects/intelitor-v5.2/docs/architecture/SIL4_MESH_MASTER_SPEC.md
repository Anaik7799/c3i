# SIL6 Mesh Lifecycle: Master Analysis & Implementation Specification

**Version**: 5.0.0-Absolute  
**Compliance**: SIL-6 Biomorphic (IEC 61508) | SC-SIL6-001  
**SLA Targets**: Startup < 10s | Shutdown < 5s  
**Framework**: CEPAF Cybernetic Orchestrator (F# Core)

## 1. Executive Summary
Indrajaal v26.0.0 implements a **Biomorphic Fractal Holon** orchestration layer. This system eliminates non-determinism by moving from "Command-and-Forget" to a "Verified-Transition" model. Every actuation wave is a transaction, every holon is a Digital Twin, and every log is a telemetry pulse on the Zenoh control plane.

## 2. AS-IS vs. TO-BE Architecture
| Dimension | AS-IS (Legacy) | TO-BE (Biomorphic SIL6) |
| :--- | :--- | :--- |
| **Control Logic** | Sequential Shell Scripts | Kahn's Algorithm + OODA Decision Matrix |
| **Observation** | Exit Codes (0/1) | REST API Metabolic Probing (JSON Stats) |
| **Stability** | Retries | Transactional Waves with Atomic Rollback |
| **Network** | Dynamic Discovery Storms | Signed Static Topology Snapshots |
| **HMI** | Flat Text Logs | Dark Cockpit Dashboard with DC Scoring |

## 3. Data Flow & Control Flow (Level 5)
### 3.1 Startup Control Loop
1.  **Observing**: The `MeshCortex` probes host sockets. If `5433` is blocked, OODA enters `ABORT`.
2.  **Orienting**: Map the `HolonGenotype` (Genome) to the `PodmanREST` response.
3.  **Deciding**: Solve the SLA Jitter equation via `math-oracle` to determine wave delay.
4.  **Acting**: Issue cryptographically signed `up -d` commands.
5.  **Verifying**: Confirm the `ImageDigest` matches the signed genotype.

### 3.2 Transactional Wave Semantics
- **Wave 1 (Persistence)**: `db-primary`. MUST achieve `READY` in 3s.
- **Wave 2 (Control)**: `indrajaal-obs` + `zenoh-bridge`. Parallel boot.
- **Wave 3 (Mesh)**: App holons. Booted with 10ms jitter.
- **Rollback**: If Wave 2 fails, Wave 1 enters `Lameduck` and shuts down to prevent state corruption.

## 4. Hyper-Fidelity Twin Architecture
Every artifact detail is tracked in the `meshRegistry`:
- **L5 Atomic**: Proof Certificates, Heartbeat Jitter, IO Read/Write Bytes.
- **L4 Organelle**: Port Bindings (Host:Cont), Volume Hash, Env Var Purity.
- **L3 Phenotype**: Actual IP, PID, Page Faults, Context Switches.
- **L2 Genome**: Artifact Identity (Commit, BuildID), Security Posture (Cap-Drop).
- **L1 Ecosystem**: Global Entropy Score, Mesh Quorum status.

## 5. Container-Specific Transaction Behaviors
- **Database (db-primary)**: Synchronous boot. Verification via `pg_isready` REST probe.
- **Observability (indrajaal-obs)**: Buffer flush verification before `READY`.
- **Apps (app-*)**: Lameduck draining window required during shutdown to ensure zero packet loss.

## 6. Telemetry: Zenoh Neural Stream
- **Zenoh** handles the control plane messages (`c3i/mesh/twin/**`).
- **Telemetry setup**:
    1.  F# Actuator emits binary events.
    2.  `elixir-intelligence` bridge subscribes and injects into the Phoenix LiveView.
    3.  `Gemini Console` displays the Magenta OODA pulse during active cycles.
