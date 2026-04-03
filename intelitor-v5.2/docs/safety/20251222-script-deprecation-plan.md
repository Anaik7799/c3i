# Container Script Deprecation & Unification Plan

**Date**: 2025-12-22
**Status**: PROPOSED
**Objective**: Eliminate redundant and unsafe container management scripts to enforce the VTO protocol as the Single Source of Truth for orchestration.

## 1. Analysis (5-Level RCA)

*   **L1 (Surface)**: Over 34 scripts exist for starting, building, or managing containers. This creates confusion and risk.
*   **L2 (Direct)**: No single, authoritative orchestration script existed previously.
*   **L3 (Mechanism)**: Scripts were created ad-hoc for specific tasks, leading to high duplication and entropy.
*   **L4 (Process)**: Lack of a "Deprecation" step in the development lifecycle for old tooling.
*   **L5 (Systemic)**: Project treated scripts as disposable, not as long-term, managed artifacts.

## 2. Deprecation Strategy

The scripts are categorized into two groups:
1.  **DELETE**: These scripts are dangerously outdated, use incorrect methodologies (e.g., direct `podman-compose up`), or are simple, one-off helpers that are now handled by the VTO orchestrator. Their existence poses a direct risk of someone running them and de-stabilizing the environment.
2.  **ARCHIVE**: These scripts, while now obsolete, contain complex logic or specific configurations (e.g., Nix builds, security hardening) that have been integrated into the new framework but may be useful for future reference or auditing. They will be moved to `archive/scripts/` to prevent execution.

## 3. Deprecation List

### 3.1 Scripts to DELETE

| File | Reason | Replaced By |
| :--- | :--- | :--- |
| `scripts/containers/start-*.sh` | Simple `podman run` wrappers. | `vto_orchestrator.exs` |
| `scripts/container_operations/*.exs` | Ad-hoc start/stop logic. | `vto_orchestrator.exs` |
| `scripts/demo/test_pure_nixos_stack.exs` | Monolithic test/run script. | VTO + separate tests |
| `scripts/security/container_hardening.sh` | Logic now baked into `Dockerfile.sopv51-base`. | Nix build process |

### 3.2 Scripts to ARCHIVE

| File | Reason | Replaced By |
| :--- | :--- | :--- |
| `scripts/containers/nixos_only_container_rebuild.exs` | Contains complex Nix logic, now superseded. | `vto_orchestrator.exs` + Nix files |
| `scripts/containers/complete_environment_rebuild.sh`| "Nuclear option" script. Logic now in `master_safety_protocol.exs`. | `master_safety_protocol.exs` |
| `scripts/containers/build_nixos_containers.exs` | Contains Nix build logic. | `master_safety_protocol.exs` |
| `scripts/ga_release/*.exs` | Release-specific logic. | VTO + future CI/CD pipeline |

## 4. Execution Plan

1.  **Create Archive**: `mkdir -p archive/scripts`
2.  **Move Scripts**: Use `git mv` to move all scripts marked "ARCHIVE" to the archive directory.
3.  **Delete Scripts**: Use `git rm` to delete all scripts marked "DELETE".
4.  **Commit**: Commit the changes with the message "refactor: Deprecate 34 obsolete container scripts to enforce VTO protocol."
5.  **Documentation**: Update `README.md` to point developers exclusively to `vto_orchestrator.exs` for container management.

This plan will reduce technical debt, eliminate confusion, and enforce the new safety-critical VTO protocol as the one true way to manage the container lifecycle.
