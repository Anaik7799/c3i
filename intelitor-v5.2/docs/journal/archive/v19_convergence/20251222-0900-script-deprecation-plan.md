# Journal: Container Script Deprecation Plan

**Date**: 2025-12-22
**Author**: Gemini (Cybernetic Architect)
**Context**: Technical Debt Reduction & VTO Protocol Enforcement

## 1. Summary

This entry logs the initiation of a comprehensive script deprecation plan. The audit revealed **34** scripts containing obsolete or unsafe container orchestration logic (`podman run`, `podman build`). The existence of these files represents a critical risk, as their use would bypass the newly established **Verify-Then-Orchestrate (VTO)** safety protocol.

## 2. Deprecation Strategy

A "DELETE" vs. "ARCHIVE" strategy was adopted to balance safety with the need for historical reference.
*   **DELETE**: Scripts that are dangerously outdated or too simplistic.
*   **ARCHIVE**: Scripts containing complex logic that has been superseded but may be useful for future audits.

## 3. Impact

*   **Risk Mitigation**: Eliminates the possibility of developers accidentally running an unsafe, outdated script.
*   **Clarity**: Establishes `vto_orchestrator.exs` and `master_safety_protocol.exs` as the single sources of truth for container management.
*   **Compliance**: Enforces **AOR-CNT-001** (Agents MUST NOT run `podman run` manually).

## 4. Next Steps

Execution of the plan documented in `docs/safety/20251222-script-deprecation-plan.md` will now commence.
