# Master Specification: SIL6 Deterministic Mesh Orchestration

**Version**: 1.0.0-GA  
**Status**: OPERATIONAL | BIOMORPHIC  
**Framework**: CEPAF (F# Category-Theory Core)  
**SLA**: 10s Startup | 5s Shutdown  

---

## 1. Ecosystem Overview (Level 1)
The SIL6 Mesh Orchestrator is a biomorphic fractal controller that manages the lifecycle of the Indrajaal mesh substrate. It treats the distributed cluster as a single deterministic computer, ensuring that the "Phenotype" (Runtime) always aligns with the "Genome" (Configuration).

### 1.1 Core Invariants
- **Atomic Transition**: No holon enters a `Ready` state without a cryptographically signed `ProofToken`.
- **Wave Purity**: Transitions happen in discrete, transactional waves (Persistence -> Obs -> Parallel Apps).
- **Substrate Awareness**: The supervisor has absolute visibility into kernel-level metabolic metrics (Context switches, Page faults).

---

## 2. Component Design & Config (Level 2)
### 2.1 The Bicameral Controller
- **The Cortex (F# OptimalMesh)**: The high-velocity actuator. Executes Kahn's Algorithm for DAG sorting and manages the OODA loop timing.
- **The Guardian (SIL6 Validator)**: The logic gate. Uses formal Quint models to verify that proposed waves cannot lead to deadlocks or race conditions.

### 2.2 Configuration Genotype
Genotypes are defined in `lib/cepaf/artifacts/podman-compose-prod-standalone.yml` (4-container prod-standalone) or `lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml` (15-container full mesh).
- **Audit**: Registry MUST be `localhost/`.
- **Isolation**: Containers MUST run in `rootless` mode with `userns` isolation.

---

## 3. Implementation Logic (Level 3)
### 3.1 Kahn’s Wave Algorithm
1. **Observe**: Map the YAML dependencies to a Directed Acyclic Graph (DAG).
2. **Sort**: Compute the topological order.
3. **Group**: Batch independent holons into "Parallel Waves."
4. **Jitter**: Apply 5-50ms random delay per container to prevent CPU thundering herds.

### 3.2 Transactional Rollback
- If any holon in a wave fails to return a `Healthy` heartbeat via the Podman REST API within the timeout window, the Cortex triggers an automatic `podman-compose down` for the entire wave transaction.

---

## 4. Usage & OODA Playbook (Level 4)
### 4.1 CLI Commands
- `cepa --sil4-startup`: Executes the verbose 3-wave startup.
- `cepa --sil4-shutdown`: Executes surgical lameduck shutdown.

### 4.2 TUI Dashboard ('v' key)
- **OODA Pulse**: Magenta flash during decision cycles.
- **Metabolic View**: Real-time display of RSS Memory, IO Wait, and Proof Tokens.

---

## 5. Testing & Verification (Level 5)
### 5.1 The 5-Level Fractal Test Suite
1. **TDG**: Property tests for Kahn's sort logic.
2. **FMEA**: Simulated DB failure during Wave 3 to verify rollback.
3. **Formal**: Quint model-checking of the wave state machine.
4. **Graph**: Path coverage verification of the Service Chain.
5. **BDD**: Gherkin scenarios for the 10s SLA requirement.

---

## 6. Safety & Governance

### 6.1 STAMP Constraints (Systemic Control)
- **SC-MESH-001**: System SHALL NOT actuate Wave N+1 until Wave N Proof Tokens achieve 100% quorum.
- **SC-MESH-002**: Lameduck draining SHALL persist for 2000ms minimum before SIGTERM.
- **SC-MESH-003**: Divergence Score > 0.05 SHALL trigger Jidoka (Automatic Halt).

### 6.2 FMEA Risk Analysis
| Failure Mode | Severity | Mitigation |
| :--- | :--- | :--- |
| **Thundering Herd** | High | Jittered Actuation (5-50ms) |
| **Substrate Drift** | Critical | SHA256 Image Digest verification every 10s |
| **Dropped Packets**| Medium | Google-style Lameduck draining state |

### 6.3 TDG Rules (Test-Driven)
- **TDG-MESH-001**: Every new holon genotype MUST have a corresponding F# `MockPhenotype` for shadow testing.
- **TDG-MESH-002**: Invariants MUST be verified via host-level socket probing *before* container startup.

### 6.4 AOR Rules (Agent Operation)
- **AOR-MESH-001**: Agent MUST run `uip_command_center` before any mesh-mutating command.
- **AOR-MESH-002**: Agent MUST NOT bypass the Guardian logic for container overrides.
