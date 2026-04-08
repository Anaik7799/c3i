# C3I Artifact Synchronization Protocol (SC-SYNC-001)

**Mandate**: The system MUST maintain 100% artifact parity across submodule boundaries to prevent cognitive drift and tool desynchronization.

## Enforcement Rules
1.  **Session Start Sync**: Every agent session MUST begin by executing `./sa-sync`.
2.  **Authoritative Propagation**:
    *   `PROJECT_TODOLIST.md` propagates from **Sub-project -> Root**.
    *   `GEMINI.md` and `CLAUDE.md` propagate from **Root -> Sub-project**.
3.  **Database Alignment**: All planning tools (`sa-plan`, `sa-gleam`) MUST target `Smriti.db` as the primary task authority.
4.  **Git State**: Synchronized artifacts MUST be staged (`git add`) immediately following a sync operation.

## Failure Response
If a desync is detected (e.g., `sa-plan status` and `sa-gleam status` counts differ), the agent MUST halt execution and perform a Fractal RCA before proceeding.
