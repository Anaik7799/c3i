# Detailed Master Plan: F# to Rust Operational Migration (v2.0.0)

## 1. Objective
Systematically map, port, and verify all F# operational logic into native Rust daemons. This plan follows an **Organic Evolutionary Approach**, maintaining system homeostasis while gradually shifting the authoritative substrate from F# to Rust. A key architectural decision in v2.0.0 is to decouple the Planning Authority (`sa-plan`) into its own dedicated Rust daemon, using the `ignition` daemon as its foundational baseline.

## 2. Multi-Dimensional Mapping & Criticality Matrix

| F# Command | Rust Target | Criticality | Operational Utility | FMEA Risk (RPN) | Evolution Phase |
|:---|:---|:---:|:---|:---:|:---:|
| `sa-plan` | **`planning_daemon`** | **SIL-6** | High (Task Authority) | 225 (State Loss) | 1 (Foundation) |
| `sa-down` | `ignition down` | **SIL-4** | High (Graceful Stop) | 180 (Orphan Nodes) | 2 (Lifecycle) |
| `sa-scour` | `ignition scour` | Med | Med (Clean Substrate) | 120 (Disk Full) | 2 (Lifecycle) |
| `sa-listen` | `ignition listen` | Med | High (Debug Signal) | 90 (Visibility Gap) | 3 (Debug) |
| `sa-logs` | `ignition logs` | Med | High (Observability) | 80 (Data Loss) | 3 (Debug) |
| `sa-emergency`| `ignition emergency`| **SIL-6** | Critical (Apoptosis) | 252 (Panic Path) | 4 (Safety) |
| `sa-genotype` | `ignition genotype` | Med | High (Config Synth) | 140 (Drift) | 5 (Genetic) |
| `sa-verify-f` | `ignition verify --deep`| **SIL-4** | High (Deep Audit) | 160 (False Pos) | 6 (Verify) |

## 3. Organic Evolutionary Approach (Homeostasis-First)

### Wave 1: The Planning Bridge (Separate Daemon)
- **Action**: Clone the `ignition_daemon` structure to create a new `planning_daemon` in Rust.
- **Why Separate?**: Segregates lifecycle execution (Ignition) from cognitive intent tracking (Planning), ensuring failure in one domain does not crash the other.
- **Logic**: Implement SQLite-backed task management reading from `data/smriti/planning.db`, generating `PROJECT_TODOLIST.md`, and emitting Zenoh MCP events.
- **Safety**: Dual-run F# `sa-plan` and Rust `planning_daemon` via a shadowing proxy script before full cutover.

### Wave 2: Lifecycle Takeover (Ignition Expansion)
- **Action**: Implement `down` and `scour` subcommands in the existing `ignition` daemon.
- **Safety**: Leverage the existing robust Podman CLI wrappers in `ignition` to ensure high-fidelity error propagation.
- **Evolution**: Replace the legacy `./sa-down` bash script to point to the Rust binary.

### Wave 3: Cognitive Convergence (Safety & Debugging)
- **Action**: Port the `LethalMutationGate` logic (Shannon Entropy $H(S)$) into the Rust OODA loop.
- **Action**: Implement `listen` and `logs` subcommands in `ignition` for raw Zenoh introspection and multiplexed container tailing.
- **Verification**: Confirm Rust correctly blocks mutations that F# would have rejected.

## 4. FMEA & Mitigation Strategy

| Failure Mode | Impact | Mitigation |
|:---|:---|:---|
| **SQLite Lock Contention** | Rust and F# daemons collide. | Implement `rusqlite` with `BUSY_TIMEOUT`, WAL mode, and transactional retries. |
| **Orphaned Containers** | `ignition down` fails. | Implement parallel `wait` with a 5s force-kill fallback (`SIGKILL`). |
| **Zenoh Signal Overload** | `ignition listen` floods. | Implement client-side filtering (by topic) and rate-limiting via Tokio. |
| **Daemon Desync** | Planning daemon state lags Ignition state. | Force strict OoZ (OTel-over-Zenoh) state publication for immediate consistency. |

## 5. Baseline Implementation Mandate
- **Ignition-as-Baseline**: The `planning_daemon` MUST be created by copying the scaffolding of `ignition_daemon`. It will strip out Podman/Launch logic and retain the TUI logger, Clap CLI, Zenoh FFI/Telemetry bridge, and OODA supervisor structures.
- **MSTS Consistency**: All new Rust code MUST follow the Mathematical and Semantic Module Contract (SC-GLM-MSTS).
- **Muda Enforcement**: Zero warnings gate (SC-CMP-025) is mandatory.

## 6. Implementation Steps: `planning_daemon`
1.  **Clone**: `cp -r sub-projects/intelitor-v5.2/native/ignition_daemon sub-projects/intelitor-v5.2/native/planning_daemon`
2.  **Prune (Muda)**: Remove `launch.rs`, `podman.rs`, `preflight.rs`, `verify.rs`, etc.
3.  **Adapt**: Modify `Cargo.toml` (name="planning_daemon", add `rusqlite`, `pulldown-cmark`).
4.  **Implement**: Create `db.rs` (SQLite), `markdown.rs` (Artifact sync), and `cli.rs` (Commands: list, add, update, status).
5.  **Workspace**: Add `native/planning_daemon` to the root `Cargo.toml` workspace members.
