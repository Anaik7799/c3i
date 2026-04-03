# SIL6 Deterministic Mesh Orchestration: Exhaustive Specification

**Version**: 5.0.0-GA  
**Compliance**: SIL-6 Biomorphic (IEC 61508) | SC-SIL6-001  
**SLA**: Startup < 10s | Shutdown < 5s  
**Framework**: CEPAF Cybernetic Executor (F#)

---

## 1. Ecosystem Overview (Level 1)
The SIL6 Mesh Orchestrator is a biomorphic fractal controller that manages the lifecycle of the Indrajaal substrate. It transforms a collection of distributed containers into a single deterministic computer.

### 1.1 Biomorphic Principles
- **Homeostasis**: The system automatically detects divergence between the "Genome" (F# Records) and the "Phenome" (Actual Podman State).
- **Self-Healing**: Automatic transaction rollback if a startup wave fails to stabilize.
- **Neural Speed**: Real-time telemetry via Zenoh control plane synchronization.

---

## 2. Component Design & Architecture (Level 2)
### 2.1 The Bicameral Controller
- **The Cortex (F# OptimalMesh)**: The actuator. Manages parallel waves, Jidoka halts, and Kahn's DAG sorting.
- **The Guardian (SIL6 Validator)**: The gatekeeper. No command is executed without a cryptographic Proof Token verifying safety invariants.

### 2.2 Data Plane vs. Control Plane
- **Data Plane**: Container-to-container communication via Podman bridge.
- **Control Plane**: F#-to-Container communication via REST API and Zenoh topics.

---

## 3. Implementation Logic & Algorithms (Level 3)
### 3.1 Wave Transaction Algorithm
1. **DAG Resolution**: Use Kahn's Algorithm to determine the topological order of holons.
2. **Substrate Scour**: Surgical termination of any processes holding required ports (5433, 8123, 4000).
3. **Wave Actuation**:
    - **Wave 1 (Persistence)**: Synchronous boot of `db-primary`.
    - **Wave 2 (Control)**: Parallel boot of observability and bridges.
    - **Wave 3 (Mesh)**: Staggered boot of app nodes with 10ms jitter.
4. **OODA Stabilization**: Millisecond-precision probe of `/stats` to confirm readiness.

### 3.2 Lameduck Shutdown Logic
1. **Signal**: Broadcast `LAMEDUCK` state.
2. **Drain**: Wait 2000ms for in-flight requests to complete.
3. **Teardown**: Sequential container removal in reverse dependency order.

---

## 4. Configuration & Usage Playbook (Level 4)
### 4.1 Genotype Configuration
Genotypes are defined in `lib/cepaf/artifacts/podman-compose-prod-standalone.yml` (4-container prod-standalone) or `lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml` (15-container full mesh).
- **Invariants**: `localhost/` registry ONLY, `readonly` root, `cap-drop: [ALL]`.

### 4.2 Manual Commands
- `cepa --sil4-startup`: Verbose OODA startup sequence.
- `cepa --sil4-shutdown`: Surgical shutdown sequence.
- `Cockpitf 'v' key`: Toggle the Hyper-Fidelity Twin Dashboard.

---

## 5. Testing & Verification (Level 5)
### 5.1 Verification Pyramid
- **Agda**: Prove eternal safety invariants (e.g., Unforgeable Proof Tokens).
- **Quint**: Model check the wave transaction state machine.
- **ExUnit**: Empirical verification of 10s SLA targets.
- **FMEA**: Simulated substrate failures to verify rollback logic.

---

## 6. Formal Governance Rules

### 6.1 STAMP Constraints (Systemic Control)
- **SC-MESH-001**: System SHALL NOT actuate Wave N+1 until Wave N Proof Tokens achieve 100% quorum.
- **SC-MESH-002**: Lameduck draining SHALL persist for 2000ms minimum before SIGTERM.
- **SC-MESH-003**: Divergence Score > 0.05 SHALL trigger an immediate Jidoka Halt.

### 6.2 FMEA Risk Analysis
| ID | Failure Mode | Severity | Mitigation |
| :--- | :--- | :--- | :--- |
| **FM-001** | Thundering Herd | High | Jittered Actuation (5-50ms) |
| **FM-002** | Stale Socket | Critical | Preflight Substrate Scour |
| **FM-003** | Ghost Container | Medium | Wave Transaction Rollback |

### 6.3 TDG Rules (Test-Driven Generation)
- **TDG-MESH-001**: Every new holon genotype MUST have a corresponding F# `MockPhenotype`.
- **TDG-MESH-002**: Invariants MUST be verified via host-level probing *before* container startup.

### 6.4 AOR Rules (Agent Operating Rules)
- **AOR-MESH-001**: Agent MUST run `uip_command_center` health check before any mesh-mutating command.
- **AOR-MESH-002**: Agent MUST NOT bypass the Guardian logic for container overrides.
