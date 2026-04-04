# Detailed Master Plan: F# to Rust Operational Migration (v3.0.0)

## 1. Objective
Achieve 100% operational independence from F# by migrating all remaining `sa-*` CLI tools into native Rust daemons. This plan implements a **Bifurcated Daemon Architecture**, segregating task authority from mesh execution to minimize failure blast radius.

## 2. Multi-Dimensional Migration Matrix

| F# Command | Rust Target | Layer | Criticality | Operational Utility | FMEA Risk (RPN) | Evolution Phase |
|:---|:---|:---:|:---:|:---|:---:|:---:|
| **`sa-plan`** | **`planning_daemon`** | L5 | **SIL-6** | High (Task Authority) | 225 (State Loss) | 1 (Foundation) |
| `sa-down` | `ignition down` | L4 | **SIL-4** | High (Graceful Stop) | 180 (Orphan Nodes) | 2 (Lifecycle) |
| `sa-scour` | `ignition scour` | L4 | Med | Med (Clean Substrate) | 120 (Disk Full) | 2 (Lifecycle) |
| `sa-listen` | `ignition listen` | L4 | Med | High (Raw Zenoh) | 90 (Visibility Gap) | 3 (Debug) |
| `sa-logs` | `ignition logs` | L4 | Med | High (Observability) | 80 (Data Loss) | 3 (Debug) |
| `sa-emergency`| `ignition emergency`| L0 | **SIL-6** | Critical (Apoptosis) | 252 (Panic Path) | 4 (Safety) |
| `sa-genotype` | `ignition genotype` | L5 | Med | High (Config Synth) | 140 (Drift) | 5 (Genetic) |
| `sa-verify-f` | `ignition verify --deep`| L2 | **SIL-4** | High (Fractal Audit) | 160 (False Pos) | 6 (Verify) |

## 3. FEMA (Failure Mode and Effects Analysis) & Mitigation

| Failure Mode | Impact | Severity (1-10) | Mitigation Strategy |
|:---|:---|:---:|:---|
| **Database Corruption** | Planning state loss during migration. | 9 | Atomic SQLite transactions; automated daily backups to `PROJECT_TODOLIST.md`. |
| **Shutdown Deadlock** | `ignition down` hangs on Podman. | 7 | Implement 5s async timeout per container with mandatory `SIGKILL` fallback. |
| **Zenoh Saturation** | `ignition listen` overwhelms terminal. | 4 | client-side message batching and regex-based topic filtering. |
| **Entropy Failure** | `LethalMutationGate` fails to block. | 8 | Dual-run gate in "Shadow Mode" with 100% telemetry comparison against F# golden samples. |

## 4. Organic Evolutionary Approach (Homeostasis-First)

### Phase 1: Planning Foundation (`planning_daemon`)
*   **Action**: Implement `sa-plan-daemon` using `ignition` as the baseline.
*   **Authority**: Become the unique gateway to `data/smriti/planning.db`.
*   **Verification**: Ensure Rust-generated `PROJECT_TODOLIST.md` is bit-for-bit identical to F# output.

### Phase 2: Lifecycle Takeover (`ignition` Expansion)
*   **Action**: Merge `sa-down` and `sa-scour` into `ignition`.
*   **Safety**: Use the `SubstrateGuard` (Axiom 0.1) to verify disk state before and after pruning.
*   **Evolution**: Bash wrappers forward to Rust; operator workflow remains unchanged.

### Phase 3: Cognitive & Safety Calibration
*   **Action**: Integrate `LethalMutationGate` into the OODA `Decide` phase.
*   **Action**: Implement `sa-listen` for real-time mesh introspection.

## 5. Implementation Mandate: Baseline Continuity
*   **`planning_daemon`** MUST retain the `tui`, `zenoh_telemetry`, and `errors` structures from `ignition` to ensure telemetry consistency (SC-ZMOF-001).
*   **`ignition`** serves as the authoritative host for all container-related logic, while `planning_daemon` serves as the authoritative host for all intent-related logic.

## 6. Verification Protocol
1.  **MSTS Compliance**: All new functions must have Allium behavioral specs.
2.  **Jidoka Gate**: Zero compilation warnings (SC-CMP-025).
3.  **Traceability**: Every operation must emit an OTel span to `indrajaal/otel/span/...` over Zenoh.
