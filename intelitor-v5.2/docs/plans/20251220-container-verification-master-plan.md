# 20251220-container-verification-master-plan.md

**Date**: 2025-12-20
**Status**: IN_PROGRESS
**Owner**: Gemini (Cybernetic Architect)
**Context**: Task 23.0 - Container Verification & Stabilization

## Executive Summary
This master plan defines the strategy to achieve 100% completion of GDE goals related to the container infrastructure. It operationalizes the "5-Level Container Environment Strategy" defined in `CLAUDE.md` and `GEMINI.md`, ensuring all container environments are verified, stable, and monitored.

## 5-Level Verification Hierarchy

### Level 1: Foundation Verification (Development)
**Objective**: Ensure the high-velocity development environment is stable and PHICS-compliant (<50ms).
- **Target Artifact**: `podman-compose-3container.yml`
- **Key Constraints**: SC-CNT-ENV-001, Axiom 2 (PHICS)
- **Actions**:
    - [ ] Verify `dev-start.exs` executes correctly.
    - [ ] Validate PHICS latency is < 50ms.
    - [ ] Confirm hot-reloading works for Elixir/Phoenix.
    - [ ] Verify Localhost Registry usage.

### Level 2: Resilience Verification (Testing)
**Objective**: Ensure the testing environment supports HA simulation and correct test isolation.
- **Target Artifact**: `podman-compose-testing.yml`
- **Key Constraints**: SC-CNT-ENV-002, SC-CLU-001
- **Actions**:
    - [ ] Verify multi-node cluster startup.
    - [ ] Run full test suite inside the container environment.
    - [ ] Validate database replication simulation (if applicable).

### Level 3: Visibility Verification (Demo)
**Objective**: Ensure the demo stack provides full observability and stability for stakeholder reviews.
- **Target Artifact**: `podman-compose.yml` (+ `.observability`)
- **Key Constraints**: SC-CNT-ENV-005, SC-OBS-065
- **Actions**:
    - [ ] Verify all 6 services start cleanly.
    - [ ] Confirm Telemetry/SigNoz integration.
    - [ ] Validate resource limits are respected.

### Level 4: Security Verification (Production)
**Objective**: Ensure the production baseline is secure, rootless, and hardened.
- **Target Artifact**: `podman-compose-secure.yml`
- **Key Constraints**: SC-CNT-ENV-003, SC-SEC-041
- **Actions**:
    - [ ] Verify rootless execution.
    - [ ] Check read-only file system mounts.
    - [ ] Validate network isolation policies.

### Level 5: Distribution Verification (Mesh)
**Objective**: Ensure the distributed FLAME/Tailscale architecture functions correctly.
- **Target Artifact**: `podman-compose-cluster.yml`
- **Key Constraints**: SC-FLAME-001, SC-CLU-004
- **Actions**:
    - [ ] Verify Tailscale integration (mock or real).
    - [ ] Test FLAME runner spawning.
    - [ ] Validate cluster node discovery.

## Execution Strategy (SOPv5.11)

1.  **Registration**: Add this plan to `PROJECT_TODOLIST.md` as Task 23.0.
2.  **ASSP Execution**: Use `todolist_manager.exs` to lock and track each level.
3.  **Verification**: Use `scripts/sopv511/phase_2_container_deployment.exs` as the core verification engine, extending it if necessary.
4.  **Reporting**: Update dashboards and journals after each level.

## Impact Analysis
- **Scripts Impacted**: `scripts/env/dev-start.exs`, `scripts/sopv511/phase_2_container_deployment.exs`, `scripts/containers/*`.
- **Docs Impacted**: `GEMINI.md`, `CLAUDE.md` (updates to reflect verification status).

## Success Criteria
- All 5 Levels marked COMPLETE.
- Zero "build time" or "runtime" drift detected.
- 100% Code & Runtime Coverage for container scripts.
- Operational Dashboards active.