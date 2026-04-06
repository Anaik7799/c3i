# Comprehensive Implementation & Test Specification: Remaining Tasks (v2.0.0)

## 1. Feature-to-Language Mapping Matrix
To ensure Muda (waste reduction) and substrate independence, all remaining tasks are mapped to either Rust (Infrastructure/Performance) or Gleam (UI/Orchestration).

| Task ID | Feature Name | Language | Layer | Criticality |
|:---:|:---|:---:|:---:|:---:|
| 5740a000 | Rust NIF-Layer ProofToken Enforcement | **Rust** | L1 | SIL-6 |
| 9c4452d5 | Zenoh Router Plugin (ProofToken) | **Rust** | L6 | SIL-6 |
| a0c68c7e | Mathematical Integrity Pane (Hs, epsilon, Ds) | **Gleam** | L2 | SIL-4 |
| 1f5e1cc0 | Evolution Vector Visualization (V1-V4) | **Gleam** | L5 | SIL-4 |
| aa1ce076 | NASA-STD-3000 Biomorphic Matrix View | **Gleam** | L4 | SIL-4 |
| 167fff39 | Interactive Threshold Controls | **Gleam** | L3 | SIL-4 |
| 813a7a93 | Bicameral Release Dashboard | **Gleam** | L0 | SIL-6 |
| 0f2b36e6 | Expand F# Canopy tests (Port to Wallaby) | **Gleam** | L2 | SIL-4 |
| c2467ea8 | Elixir Reflex Core (Nx/EXLA Bridge) | **Rust** | L5 | SIL-4 |
| e134393a | Deploy Mojo MAX Compute Container | **Rust** | L4 | SIL-4 |
| da5b06f9 | Substrate-Native Cognitive Sovereignty | **Rust** | L0 | SIL-6 |
| f26cefc3 | Semantic caching for OODA observations | **Rust** | L5 | SIL-4 |
| fc7e545e | Two-Key manual override via Cockpit | **Gleam** | L0 | SIL-6 |
| 09311046 | Reed-Solomon RS(32, 28) state parity | **Rust** | L3 | SIL-4 |
| c1792092 | Time-to-Singularity estimation sparkline | **Gleam** | L5 | SIL-4 |
| 15-100 | Morphogenic Evolution (Saturation) | **Mixed** | L0-L7 | SIL-4 |

## 2. Test Specification & Parallelization strategy

### 2.1 Layer 1 Supervisor (Rust/Infrastructure)
*   **Parallelization**: Utilize `cargo test -- --test-threads=16`.
*   **Security Protocol**: Implement Ed25519 signature verification in `zenoh_nif`. Test with 10,000 randomized signature injections to ensure p99 latency < 1ms.
*   **Lifecycle Protocol**: Verify `ignition down` and `scour` against a mocked Podman socket to ensure zero orphaned processes.

### 2.2 Layer 2 Supervisor (Gleam/UI/Cognitive)
*   **Parallelization**: Utilize `gleam test --jobs 16`.
*   **UI Protocol**: Implement NASA-STD-3000 contrast checking in `lib/cepaf_gleam/test/ui_visual_regression_test.gleam`.
*   **Cognitive Protocol**: Implement `LethalMutationGate` property-based tests using `PropCheck`. Verify that any state with Shannon Entropy > 0.2 is blocked with 100% precision.

## 3. Autonomous Evolution Rules
1.  **Read**: supervisors read `PROJECT_TODOLIST.md` every 5 cycles.
2.  **Act**: Select highest priority (P0 -> P1 -> P2).
3.  **Validate**: Write test first (TDD). Implement in Rust/Gleam.
4.  **Sync**: Mark as COMPLETED in `sa-plan`.
