# Ultimate Migration Plan & Test Specification (L0-L7)
**Version:** 5.0.0 | **Status:** ACTIVE | **Date:** 2026-04-04

## 1. Objective
Achieve 100% completion of the Indrajaal c3i migration. This plan mandates **Maximum Parallelization**, **Fully Autonomous** resolution via a **2-Layer Supervisor** architecture, continuing unattended until every F# operational, testing, and cognitive function is native Rust or Gleam.

## 2. Feature-to-Language Mapping Matrix

| Feature Category | Component | Target Language | Criticality | Supervisor |
|:---|:---|:---:|:---:|:---:|
| **Security (L1/L6)** | Ed25519 ProofToken Enforcement | **Rust** | SIL-6 | Layer 1 |
| **Cognitive (L5)** | LethalMutationGate (Entropy) | **Rust** | SIL-6 | Layer 1 |
| **Lifecycle (L4)** | Mojo MAX Compute Deployment | **Rust** | SIL-4 | Layer 1 |
| **Performance (L5)** | Semantic OODA Caching | **Rust** | SIL-4 | Layer 1 |
| **Integrity (L2)** | Mathematical Hs/Ds Pane | **Gleam** | SIL-4 | Layer 2 |
| **Visualization (L5)** | Evolution Vector V1-V4 | **Gleam** | SIL-4 | Layer 2 |
| **UI Matrix (L4)** | NASA-STD-3000 Biomorphic Matrix | **Gleam** | SIL-4 | Layer 2 |
| **Control (L3)** | Interactive Homeostasis Thresholds | **Gleam** | SIL-4 | Layer 2 |
| **Verification (L2)** | Wallaby GUI Regression Suite | **Gleam** | SIL-4 | Layer 2 |

## 3. Two-Layer Autonomous Supervisor Model

### 3.1 Layer 1 Supervisor (Rust / Infrastructure)
- **Scope**: `ignition_daemon`, `zenoh_router_plugin`, `zenoh_nif`, `indrajaal_ark`.
- **Strategy**: Maximize hardware threads (`--test-threads=16`). Implement high-assurance cryptographic primitives and atomic state caching.

### 3.2 Layer 2 Supervisor (Gleam / UI / Ecosystem)
- **Scope**: `cepaf_gleam` (Lustre + Wisp + TUI).
- **Strategy**: Maximize parallel jobs (`gleam test --jobs 16`). Enforce the **Triple-Interface Mandate** (SC-GLM-UI-001) for all new visualizations.

## 4. Unattended Execution Directives
1. **Fetch**: Query `data/smriti/Smriti.db` for pending tasks.
2. **Prioritize**: P0 (Security/Safety) -> P1 (Lifecycle) -> P2 (Hardening).
3. **Implement**: Write Rust/Gleam code using the `ignition` baseline.
4. **Verify**: Write property-based and BDD tests first.
5. **Sync**: Mark tasks `[COMPLETED]` via `sa-plan` only.
