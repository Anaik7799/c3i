# Plan: Full Panoptic SIL-6 Ignition & Architectural Review
**Date**: 2026-03-25
**Status**: DRAFT / SUPREME
**Mandate**: Establish the Canonical Path to booting the 15-Node SIL-6 Fabric based on an exhaustive review of F#, SMRITI, and constitutional rules.

## 1.0 Architectural Review (The "Best Way" Discovery)

### 1.1 F# Mechanism (`Cepaf.Mesh`)
*   **Analysis**: The F# CLI (`sa-up`, `sa-scour`, `SIL6MeshCLI.fs`) is the authoritative Substrate Master. It implements a **Wave-Based Boot Sequence** (Wave 0: Infrastructure -> Wave 1: Seed -> Wave N: Satellites).
*   **The Gap**: `sa-up` defaults to a 4-node subset unless explicitly configured for the full mesh. Nuclear commands (`sa-scour`) can leave ghost metadata if not paired with strict image verification.
*   **The Best Way**: The boot process MUST use the F# orchestrator to ensure 5-Order Effect logging, but it MUST be preceded by a **Genomic Preflight Check** (verifying local images exist) to avoid the pull-blockade.

### 1.2 SMRITI (Holonic Memory)
*   **Analysis**: SMRITI governs the authoritative system state (SQLite/DuckDB) residing in `data/holons/` and `data/kms/`.
*   **The Gap**: If the App tier boots before SMRITI is initialized, it enters a crash loop.
*   **The Best Way**: `dotnet fsi sa-stabilize.fsx` MUST be the very first execution step. It seeds the Multiverse Registry and Founder's Directive, ensuring the "Soul" is ready before the "Body" (Containers) wakes up.

### 1.3 .claude Rules & Docs
*   **Analysis**: `agent-cognitive-protocol.md` and `todolist-access-control.md` enforce the **Bicameral Mind** and strict isolation.
*   **The Best Way**: Agents MUST NOT execute raw `podman-compose up` or `rm -rf` indiscriminately. We must use the established `sa-*` CLI commands to respect the safety wrappers and audit trails.

### 1.4 GEMINI.md (Constitutional Axioms)
*   **Analysis**: 
    - **Axiom 2**: Localhost registry ONLY. NixOS containers ONLY.
    - **Axiom 10**: Zenoh Heart MUST NOT be terminated ungracefully.
    - **SC-SIL6-001**: Mandates the full 15-container architecture (Data, Obs, 4xZenoh, Cortex, Bridge, 3xApp, Chaya, 2xML, Ollama).
*   **The Best Way**: The system must be built deterministically from `containers/*.nix`, loaded via `podman load`, and orchestrated without relying on *any* external network pulls.

## 2.0 The Canonical Execution Path

### Phase 1: Genomic Preflight & Build (L0-L1)
1. **Verify**: Check `podman images` for all 15 `localhost/indrajaal-*` images.
2. **Re-Synthesis** (If missing): Execute `nix-build` and `podman load` for the DB, Obs, App, and Zenoh tiers to guarantee Axiom 2 compliance.

### Phase 2: SMRITI Stabilization (L3)
1. **Initialize State**: Execute `dotnet fsi sa-stabilize.fsx` to mount the KMS and Multiverse registries.

### Phase 3: Panoptic Ignition (L4-L6)
1. **Scour**: `sa-scour` to clean the port substrate deterministically.
2. **Boot**: `sa-up` (Configured to target `podman-compose-sil6-full-mesh.yml`).
3. **Verify**: `sa-status` to confirm 15/15 nodes are healthy and 3oo4 Quorum is achieved.

### Phase 4: Journaling & Observability
1. **Journal**: Write the final boot state to `docs/journal/`.
2. **Metabolic Pulse**: Publish `HOMEOSTASIS_ACHIEVED` to the Zenoh bus.
