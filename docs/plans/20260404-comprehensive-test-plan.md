# Comprehensive Master Test Plan: Full System Fractal Verification

## 1. Objective
Establish a **Maximum Parallelization** testing architecture to verify 100% of the newly migrated Rust and Gleam features. This plan enforces a fully autonomous, 2-layer supervisor execution model to ensure the entire SIL-6 biomorphic mesh adheres to the Allium behavioral specifications and MSTS contracts without human intervention.

## 2. Testing Architecture & Fractal Coverage

| Fractal Layer | Domain | Framework | Target Metrics | Responsible Supervisor |
|:---:|:---|:---|:---|:---|
| **L0** | Safety Kernel (Apoptosis) | Rust `cargo test` | 100% Branch | L1-L4 (Execution) |
| **L1** | Atomic NIF & Substrate | Rust `cargo test` | 100% Branch | L1-L4 (Execution) |
| **L2** | FPPS Consensus | Rust `cargo test` | Property-Based | L1-L4 (Execution) |
| **L3** | Transaction (SQLite/DuckDB)| Rust/Gleam tests | 100% Consistency | L1-L4 & L5-L7 |
| **L4** | Lifecycle (`sa-down`, `scour`)| Bash `BATS` / Rust | Idempotency | L1-L4 (Execution) |
| **L5** | Task Authority (`sa-plan`) | Rust `cargo test` | BDD / 100% Sync | L5-L7 (Cognitive) |
| **L6** | Mesh Topology (Zenoh) | Gleam `gleam test` | Split-Brain Recovery | L5-L7 (Cognitive) |
| **L7** | Federation & ZMOF | `sa-verify-fractal` | End-to-End | L5-L7 (Cognitive) |

## 3. Two-Layer Autonomous Supervisor Model

### 3.1 Layer 1 Supervisor (L1-L4 Execution & Lifecycle)
*   **Scope**: `ignition` daemon, `podman` lifecycle wrappers, substrate verification, `apoptosis` protocol, and `health_orchestra`.
*   **Mandate**: Run all Rust unit and integration tests. Implement property-based testing (e.g., using `proptest`) for the FPPS consensus logic to simulate Byzantine failure modes. Verify `ignition down` and `ignition scour` idempotency.

### 3.2 Layer 2 Supervisor (L5-L7 Cognitive & Ecosystem)
*   **Scope**: `planning_daemon` (`sa-plan`), Gleam Penta-Stack UI, Zenoh-MCP-OTel (ZMOF) backplane, and Digital Twin genotype synthesis.
*   **Mandate**: Run all Gleam BDD and property tests. Execute Rust tests for the `planning_daemon` ensuring 100% SQLite/Markdown synchronization. Validate MCP tool discovery and OTel span emission across the mesh.

## 4. Fully Autonomous Execution Rules
1.  **Max Parallelization**: Supervisors MUST run their test suites using maximum hardware concurrency (e.g., `cargo test -- --test-threads=16` and `gleam test --jobs=16`).
2.  **Unattended Operation**: Supervisors are authorized to identify gaps in test coverage, write the missing tests, compile, and execute them recursively until 100% of the target domains are verified.
3.  **Jidoka Gates**: Any test failure MUST trigger a root-cause analysis (RCA) and automatic remediation by the respective supervisor. The loop only terminates when the entire suite is green.

## 5. Success Criteria
*   Zero compilation warnings (Muda).
*   All formal invariants (INV-1 through INV-12) proven stable under high-load parallel testing.
*   `planning_daemon` proven to maintain database integrity under concurrent stress.
*   Total substrate independence fully verified.
