# 7-Level Fractal Comprehensive Test Plan
**Date**: 2026-01-06
**Status**: APPROVED
**Context**: Post-Stabilization (v21.3.0)

## 1. Objective
To exhaustively test the Indrajaal system across 7 fractal levels, covering features introduced in the last two commits (v21.3.0 and MCP integration), ensuring SIL-6 compliance and 100% coverage of critical paths.

## 2. Scope (Recent Features)
*   **SIL-6 Biomorphic Fractal Mesh**: Homeostasis, Self-Stabilization.
*   **Graph Verification**: Libgraph alias fixes, Functional Invariant Axiom.
*   **MCP Integration**: New domains (Accounts, Alarms, etc.), Foundation layers.
*   **KMS**: Operational Stability, Web Knowledge.
*   **CEPAF (F#)**: Functionality Guide, Fractal TUI updates.

## 3. Fractal Levels Definition
| Level | Name | Scope | Key Features Tested |
|---|---|---|---|
| **L1** | **System Context** | Global boundary, External APIs | API Gateways, Auth, Load Balancing |
| **L2** | **Container/Infra** | Podman, Network, OS | SIL-6 Containers, Tailscale, Resources |
| **L3** | **Domain/Holon** | Business Domains (Ash) | Accounts, Alarms, MCP Domains |
| **L4** | **Component** | Modules, GenServers | MCP Handlers, Supervisors, F# Scripts |
| **L5** | **Code/Function** | Functions, Types | Functional Invariants, Graph Algorithms |
| **L6** | **Mesh/Cluster** | Distributed Consensus | Libcluster, FLAME, Biomorphic Mesh |
| **L7** | **Federation/Meta** | Evolution, Entropy | IKE, OODA Loops, Homeostasis |

## 4. Implementation Plan

### 4.1 Elixir Test Suite (`test/fractal/`)
*   **Update**: L1-L5 tests to include MCP and KMS validation.
*   **Create**: `test/fractal/l6_mesh_network_test.exs` (Cluster, Mesh).
*   **Create**: `test/fractal/l7_federation_evolution_test.exs` (Evolution, Entropy).

### 4.2 F# Test Suite (`lib/cepaf/scripts/`)
*   **Create**: `FractalLevel67Test.fsx` to verify infrastructure-level mesh and federation properties.

### 4.3 Execution Strategy
*   **Recursive Runs**: 7 iterations of the full suite to verify stability and non-determinism handling (Chaos engineering).
*   **Impact Analysis**: Check cascading effects across layers.

## 5. Requirements & Specs
*   **SIL-6**: Probability of Failure per Hour (PFH) < 10^-12 (Simulated).
*   **Biomorphic**: Self-healing verified in L7 tests.
*   **Coverage**: 100% path coverage for new MCP handlers.

## 6. Run Results Implications
*   **Pass**: System is stable and ready for "Homeostasis" phase.
*   **Fail**: Immediate Rollback (Axiom 0).

---
**Signed**: Gemini (Cybernetic Architect)
