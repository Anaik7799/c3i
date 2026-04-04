# Plan: Gleam CLI SQLite Integration & F# Bridge

**Version**: 1.0.0
**Date**: 2026-04-03
**Status**: DRAFT

## Objective
Enable the Gleam CLI (`cepaf_gleam`) to read and manage the authoritative planning data currently stored in the F# system's SQLite database (`sub-projects/intelitor-v5.2/data/smriti/planning.db`). This fulfills the user's requirement to "read via gleam" while maintaining data consistency across the multi-language stack.

## Key Files & Context
- `lib/cepaf_gleam/src/cepaf_gleam/db/sqlite.gleam`: (NEW) SQLite FFI wrapper.
- `lib/cepaf_gleam/src/cepaf_gleam/planning/repository.gleam`: Update to support SQLite as a primary backend.
- `lib/cepaf_gleam/src/cepaf_gleam/planning/manager.gleam`: Update to handle SQLite initialization.
- `sa-plan`: (COMPLETED) Root wrapper for F# CLI.
- `sa-gleam`: (NEW) Root wrapper for Gleam CLI.
- `docs/journal/20260403-2000-gleam-sqlite-integration.md`: (NEW) Mandatory 13-section journal.

## Implementation Steps

### Phase 1: SQLite Infrastructure
1. Create `lib/cepaf_gleam/src/cepaf_gleam/db/sqlite.gleam` using existing `esqlite` bindings in `cepaf_gleam_ffi.erl`.
2. Update `lib/cepaf_gleam/src/cepaf_gleam/planning/repository.gleam` to:
    - Add SQLite-specific retrieval functions.
    - Implement a switching mechanism between SQLite and DuckDB.
3. Update `lib/cepaf_gleam/src/cepaf_gleam/planning/manager.gleam` to point `init_db` to the F# SQLite path as a high-priority source.

### Phase 2: CLI Integration
1. Create `./sa-gleam` root wrapper to execute the Gleam CLI.
2. Verify all 742 tasks are visible via `./sa-gleam status`.

### Phase 3: Documentation
1. Create the mandatory 13-section journal entry documenting the migration and integration.

## Verification & Testing
- Run `./sa-plan status` and compare output with `./sa-gleam status`.
- Add a task via `./sa-gleam add "Test Gleam Task" HIGH`.
- Verify the new task is visible in `./sa-plan status`.
- Ensure all commands (`add`, `delete`, `update`, `sync`) work against the SQLite backend.
