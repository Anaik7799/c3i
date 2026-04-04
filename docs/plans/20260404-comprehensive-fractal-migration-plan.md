# Comprehensive Master Plan: F# to Rust Operational Migration (Fractal Architecture)

## 1. Executive Summary
This document provides a detailed, comprehensive migration plan mapping all legacy F# operational functionality into native Rust. It adheres to an **Organic Evolutionary Approach**, utilizing a **Bifurcated Daemon Architecture**:
*   **`planning_daemon` (sa-plan)**: Dedicated Rust daemon managing the SQLite `planning.db` and cognitive task authority. Built from the `ignition` baseline to inherit telemetry and TUI capabilities while maintaining separation of concerns.
*   **`ignition` (sa-*)**: The core lifecycle daemon expanded to handle all execution operations (boot, teardown, cleaning, and real-time observability).

## 2. Fractal Mapping & Migration Matrix
The Indrajaal c3i mesh is composed of 8 fractal layers (L0-L7). Every legacy F# command is mapped to its target Rust implementation, layer, and criticality.

| Legacy F# Target | Rust Target | Layer | Component | Criticality | FMEA Risk / Impact | Evolutionary Phase |
|:---|:---|:---:|:---|:---:|:---|:---:|
| `sa-emergency.fsx` | `ignition emergency` | **L0** | Safety Kernel (Apoptosis) | **SIL-6** | 252 (Deadlock Panic) | 4 (Safety) |
| `sa-verify-fractal` | `ignition verify --deep`| **L1** | Atomic Validation | **SIL-6** | 160 (False Positive) | 6 (Verification) |
| `sa-health.fsx` | `ignition status` | **L2** | FPPS Consensus | **SIL-4** | 140 (Quorum Loss) | COMPLETED |
| `sa-status` | `ignition status` | **L2** | Component Health | **SIL-4** | 140 (Visibility Gap) | COMPLETED |
| `sa-clean.fsx` | `ignition scour` | **L3** | Transaction Cleanup | Med | 120 (Disk Exhaustion) | 2 (Lifecycle) |
| `sa-up.fsx` | `ignition launch` | **L4** | System Boot | **SIL-4** | 168 (Boot Race) | COMPLETED |
| `sa-down.fsx` | `ignition down` | **L4** | System Teardown | **SIL-4** | 180 (Orphaned Nodes) | 2 (Lifecycle) |
| `sa-listen.fsx` | `ignition listen` | **L4** | Zenoh Observer | Med | 90 (Debug Blindness) | 3 (Debug) |
| `sa-logs.fsx` | `ignition logs` | **L4** | Tail Aggregator | Med | 80 (Data Loss) | 3 (Debug) |
| `sa-plan` | **`planning_daemon`** | **L5** | Cognitive Intent | **SIL-6** | 225 (State Loss) | 1 (Foundation) |
| `sa-genotype.fsx` | `ignition genotype` | **L5** | DNA Synthesis | Med | 140 (Drift) | 5 (Genetic) |
| `sa-mesh.fsx` | `ignition status` | **L6** | Ecosystem Topology | Med | 120 (Partition) | COMPLETED |
| `sa-multiverse.fsx` | `ignition multiverse` | **L7** | Federation Sync | Med | 110 (Split Brain) | 7 (Federation) |

## 3. Operational Utility & FMEA Mitigation

### 3.1 `planning_daemon` (L5 Cognitive Authority)
*   **Operational Utility**: Extremely High. This daemon is the sole gateway to `PROJECT_TODOLIST.md`, enforcing the SC-TODO-001 mandate.
*   **FMEA Mitigation**: SQLite database locks are managed via `rusqlite` with `BUSY_TIMEOUT`. The state is synchronously dumped to Markdown after every transaction to ensure human-readable recovery in case of DB corruption.

### 3.2 `ignition down` & `ignition scour` (L4 System Lifecycle)
*   **Operational Utility**: High. Replaces unstable shell scripts with parallelized `tokio` futures interacting directly with the Podman API.
*   **FMEA Mitigation**: `down` uses a 10s graceful timeout followed by `SIGKILL`. `scour` uses the `SubstrateGuard` to verify filesystem states before volume pruning.

### 3.3 `ignition listen` & `ignition logs` (L4 System Debugging)
*   **Operational Utility**: High. Provides developers with real-time insight into the mesh without relying on `.dotnet` runtimes.
*   **FMEA Mitigation**: Zenoh buffers are decoupled from the main event loop to prevent terminal I/O from creating backpressure on the mesh.

### 3.4 `ignition emergency` (L0 Safety Kernel)
*   **Operational Utility**: Critical. Directly wires to the `apoptosis` module.
*   **FMEA Mitigation**: Uses asynchronous execution with a strict 5s watchdog timeout, ensuring the panic sequence does not deadlock on network calls.

## 4. Organic Evolutionary Approach
The migration is executed "in-place" without halting operations:
1.  **Parallel Compilation**: Both Rust binaries (`ignition` and `sa-plan-daemon`) are compiled.
2.  **Bash Wrapper Swap**: The entry points (e.g., `./sa-plan`, `./sa-down`) are rewritten from F# `dotnet run` commands into simple exec wrappers pointing to the Rust binaries.
3.  **Operator Transparency**: The development team continues to use `./sa-plan add` or `./sa-down` without needing to learn new tools.
4.  **Gradual Decommissioning**: The legacy `.fsx` scripts and `.fsproj` files are marked `[DEPRECATED]` and moved to an archive before final deletion.

## 5. Execution Directive
The migration will now proceed with compiling the Rust daemons and swapping the root wrapper scripts.
