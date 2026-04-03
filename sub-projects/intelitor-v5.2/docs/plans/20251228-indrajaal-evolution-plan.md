# Indrajaal Evolution Plan (5-Level) & Criticality Task List

**Date**: 2025-12-28
**Status**: APPROVED / IN EXECUTION
**Framework**: SOPv5.11 + STAMP + Biomorphic Architecture

## 1.0 Strategic Objective (L1)
**Transform "Indrajaal" (a monitoring tool) into "Indrajaal" (a Cybernetic Organism).**
The system shall no longer be a passive collection of modules but a living, breathing **Fractal Mesh** where every component ("Holon") possesses local autonomy, health awareness ("Vital Signs"), and connection to the whole ("Indra's Net").

## 2.0 Major Milestones (L2)

### 2.1 Identity & Structural Transformation (Foundational)
- **Goal**: Complete migration of namespaces, directories, and artifacts from `Indrajaal` to `Indrajaal`.
- **Status**: Codebase migration executed. Verification pending.

### 2.2 Infrastructure & Runtime Evolution (Physical)
- **Goal**: Rename and optimize containers, databases, and network mesh to reflect the new identity.
- **Key Artifacts**: `podman-compose.yml`, `rel/`, `scripts/containers/`.

### 2.3 Biomorphic Architecture Implementation (Biological)
- **Goal**: Re-architect core domains as **Holons** wrapped in **Membranes**.
- **Key Concepts**:
    - **Holon**: Autonomous unit (Cell/Organ).
    - **Membrane**: Protection & Interface boundary.
    - **Vital Signs**: Real-time health metrics (not just boolean checks).

### 2.4 Cognitive Cortex Integration (Mental)
- **Goal**: Activate the **Cortex** (AI Brain) and **Spine** (Reflex System) to drive OODA loops.
- **Key Artifacts**: `lib/indrajaal/cortex`, `lib/indrajaal/cockpit/prajna`.

### 2.5 Verification & Stabilization (Safety)
- **Goal**: Prove system stability using the Triple-Layer Verification Pyramid (Quint/Agda/ExUnit).
- **Constraint**: Zero-defect tolerance for the new architecture.

## 3.0 Task Groups (L3) & 4.0 Critical Tasks (L4)

### Group 3.1: Codebase Stabilization (Immediate)
*   **P0 (CRITICAL)**: Verify compilation of the renamed `Indrajaal` codebase.
*   **P0 (CRITICAL)**: Fix any broken references in `priv/` or dynamic atoms.
*   **P1 (HIGH)**: Update `mix.exs` dependencies and ensure clean fetch.

### Group 3.2: Infrastructure Rename
*   **P0 (CRITICAL)**: Rename `indrajaal_dev` database to `indrajaal_dev` (migration script).
*   **P1 (HIGH)**: Update `podman-compose.yml` service names and image tags.
*   **P1 (HIGH)**: Update `rel/` release configuration for `indrajaal` executable.

### Group 3.3: Biomorphic Refactoring
*   **P1 (HIGH)**: Implement `Indrajaal.Bio.Holon` behaviour in 3 core domains (Alarms, Accounts, Access).
*   **P2 (MEDIUM)**: Wrap Domain APIs in `Indrajaal.Bio.Membrane` GenServers.

### Group 3.4: Documentation Alignment
*   **P1 (HIGH)**: Rewrite `README.md` to reflect Indrajaal identity.
*   **P2 (MEDIUM)**: Update `CLAUDE.md` / `GEMINI.md` context rules.

## 5.0 Criticality-Based Task List (Execution Queue)

| ID | Priority | Task | Status | Dependencies |
|----|----------|------|--------|--------------|
| **T-001** | **P0** | **Compile & Verify Indrajaal** | Pending | Migration |
| **T-002** | **P0** | **Fix Database Config (`indrajaal_dev`)** | Pending | T-001 |
| **T-003** | **P0** | **Update Container Orchestration (`podman`)** | Pending | T-001 |
| **T-004** | **P1** | **Regenerate Lockfiles (`mix.lock`)** | Pending | T-001 |
| **T-005** | **P1** | **Run Full Test Suite** | Pending | T-001 |
| **T-006** | **P2** | **Refactor `Accounts` to Holon** | Pending | T-005 |
| **T-007** | **P2** | **Refactor `Alarms` to Holon** | Pending | T-005 |
| **T-008** | **P3** | **Update Documentation Artifacts** | Pending | T-001 |

## 6.0 System Artifacts Update Strategy
1.  **PROJECT_TODOLIST.md**: Replace current content with this 5-Level Plan.
2.  **CLAUDE.md / GEMINI.md**: Append "Indrajaal Protocol" section.
3.  **Docs**: Move `docs/prajna` concepts into main `docs/architecture`.
