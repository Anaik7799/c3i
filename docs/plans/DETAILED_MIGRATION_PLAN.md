# Detailed Master Plan: F# to Rust Operational Migration (v1.0.0)

## 1. Objective
Systematically map, port, and verify all F# operational logic into the Rust `ignition` daemon. This plan follows an **Organic Evolutionary Approach**, maintaining system homeostasis while gradually shifting the authoritative substrate from F# to Rust.

## 2. Multi-Dimensional Mapping & Criticality Matrix

| F# Command | Rust Target | Criticality | Operational Utility | FMEA Risk (RPN) | Evolution Phase |
|:---|:---|:---:|:---|:---:|:---:|
| `sa-plan` | `ignition plan` | **SIL-6** | High (Task Authority) | 225 (State Loss) | 1 (Foundation) |
| `sa-down` | `ignition down` | **SIL-4** | High (Graceful Stop) | 180 (Orphan Nodes) | 2 (Lifecycle) |
| `sa-scour` | `ignition scour` | Med | Med (Clean Substrate) | 120 (Disk Full) | 2 (Lifecycle) |
| `sa-listen` | `ignition listen` | Med | High (Debug Signal) | 90 (Visibility Gap) | 3 (Debug) |
| `sa-logs` | `ignition logs` | Med | High (Observability) | 80 (Data Loss) | 3 (Debug) |
| `sa-emergency`| `ignition emergency`| **SIL-6** | Critical (Apoptosis) | 252 (Panic Path) | 4 (Safety) |
| `sa-genotype` | `ignition genotype` | Med | High (Config Synth) | 140 (Drift) | 5 (Genetic) |
| `sa-verify-f` | `ignition verify --deep`| **SIL-4** | High (Deep Audit) | 160 (False Pos) | 6 (Verify) |

## 3. Organic Evolutionary Approach (Homeostasis-First)

### Wave 1: The Planning Bridge (Non-Destructive Integration)
- **Action**: Implement `ignition plan` reading from the existing `Planning.db`.
- **Safety**: Do not decommission F# `sa-plan` yet. Both binaries can interoperate on the same SQLite database.
- **Verification**: Run `diff <(sa-plan list) <(ignition plan list)`. Zero delta required.

### Wave 2: Lifecycle Takeover (The Passive-to-Active Transition)
- **Action**: Implement `ignition down` and `ignition scour`.
- **Safety**: Use `podman` CLI wrappers with high-fidelity error propagation. 
- **Evolution**: Replace the `./sa-down` bash script to point to Rust. Operator experience remains identical.

### Wave 3: Cognitive Convergence (The "Truth" Shift)
- **Action**: Port the `LethalMutationGate` logic (Shannon Entropy $H(S)$) into the Rust OODA loop.
- **Safety**: Dual-run the gate in "Shadow Mode" (log but don't block) until precision hits 99.9%.
- **Verification**: Confirm Rust correctly blocks mutations that F# would have rejected.

## 4. FMEA & Mitigation Strategy

| Failure Mode | Impact | Mitigation |
|:---|:---|:---|
| **SQLite Lock Contention** | `sa-plan` and `ignition plan` collide. | Implement `rusqlite` with `BUSY_TIMEOUT` and WAL mode. |
| **Orphaned Containers** | `ignition down` fails to stop a node. | Implement parallel `wait` with a 5s force-kill fallback. |
| **Zenoh Signal Overload** | `ignition listen` floods the terminal. | Implement client-side filtering and rate-limiting. |
| **Apoptosis Deadlock** | Emergency stop fails due to Podman hang. | Implement asynchronous apoptosis with watchdog timeout. |

## 5. Baseline Implementation Mandate
- **Ignition-as-Baseline**: All new features MUST be implemented as subcommands of the `ignition` binary to leverage the existing OODA loop, TUI, and Zenoh telemetry infrastructure.
- **MSTS Consistency**: All new Rust code MUST follow the Mathematical and Semantic Module Contract (SC-GLM-MSTS).
- **Muda Enforcement**: Zero warnings gate (SC-CMP-025) is mandatory for every commit.

## 6. Verification Protocol
1.  **Bit-for-Bit Parity**: Operational outputs must match F# legacy counterparts.
2.  **OODA Calibration**: All new commands must emit an OTel span via Zenoh within 10ms of execution.
3.  **Fractal Compliance**: New logic must be assigned a clear Layer (L0-L7) and documented in Allium.
