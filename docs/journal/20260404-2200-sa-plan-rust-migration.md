# Journal Entry: 20260404-2200 — Migration to Native Rust Daemons (`planning_daemon` & `ignition`)

## 1. Scope & Trigger
**Why**: Migrate all remaining F# operational commands into Rust to achieve 100% substrate independence.
**Trigger**: User directive to adopt an organic evolutionary approach, decoupling `sa-plan` into a dedicated Rust daemon rather than a subcommand of `ignition`, and porting the rest of the mesh lifecycle logic into `ignition`.

## 2. Pre-State Assessment
**Quantified System State**:
- **Planning**: Handled entirely by F# (`sa-plan`, `Cepaf.Planning.CLI`).
- **Lifecycle**: `sa-down`, `sa-scour`, `sa-listen`, `sa-logs` are legacy F# or bash scripts relying on F#.
- **Ignition Core**: Rust `ignition_daemon` is authoritative for Boot, Status, and Verification.

## 3. Execution Detail
**Phase 1: Planning Daemon Initialization**
- Cloned `native/ignition_daemon` to `native/planning_daemon`.
- Practiced Muda by stripping out unrelated modules (`launch.rs`, `podman.rs`, `verify.rs`, etc.).
- Rewrote `main.rs` in `planning_daemon` to expose the new task authority subcommands (`status`, `add`, `update`, `sync`).
- Registered `planning_daemon` in the root workspace `Cargo.toml`.

**Phase 2: Master Plan Formulation**
- Created `docs/plans/20260404-2200-rust-sa-migration-plan-v2.md`.
- Mapped all F# commands to Rust targets, documenting Criticality, Operational Utility, FMEA Risk, and Evolution Phases.

## 4. Root Cause Analysis
**Pattern-based 5-Why Grouping**:
1. **Decoupling Need**: Why create a separate daemon? Combining `sa-plan` and `ignition` into a single monolithic binary increases blast radius. A crash in container orchestration shouldn't take down the project's task authority.
2. **Speed & Safety**: Rust provides bounded memory guarantees, ensuring task state updates never suffer from GC pauses during critical OODA loops.

## 5. Fix Taxonomy
- **The "Bifurcated Daemon" Pattern**: Splitting the Rust operational core into two dedicated services (`ignition` for execution, `planning` for cognitive intent tracking).
- **SQLite Interop**: Using `rusqlite` to seamlessly interface with the existing F# database (`planning.db`) ensuring a hitless transition.

## 6. Patterns & Anti-Patterns Discovered
- **DO**: Use `ignition` as the structural baseline for `planning_daemon` to inherit mature Zenoh telemetry, Ratatui dashboards, and error propagation.
- **AVOID**: Monolithic design. Splitting execution from planning enhances the overall resilience of the SIL-6 architecture.

## 7. Verification Matrix
- **Scaffolding Complete**: `planning_daemon` structure exists and is added to the Rust workspace.
- **Next Steps**: Resolve compilation errors caused by legacy `tui.rs` references to deleted modules, then implement the `rusqlite` database logic.

## 8. Files Modified
| File | Delta | Purpose |
|:---|:---|:---|
| `Cargo.toml` | UPDATED | Added `native/planning_daemon` to workspace. |
| `native/planning_daemon/*` | CREATED | Cloned from `ignition` and pruned for Muda. |
| `native/planning_daemon/Cargo.toml` | UPDATED | Added `rusqlite`, `pulldown-cmark`. |
| `docs/plans/...-migration-plan-v2.md` | CREATED | 6-phase detailed migration plan. |

## 9. Architectural Observations
By separating `planning_daemon` from `ignition_daemon`, we formally establish the boundary between **L5-Cognitive (Intent/Planning)** and **L4-System (Execution/Mesh)** within the Rust layer. This maps perfectly to the Allium specifications and prevents systemic coupling.

## 10. Remaining Gaps
- **P0**: Clean up `tui.rs` and `zenoh_telemetry.rs` in `planning_daemon` to fix unresolved imports from the pruned files.
- **P1**: Implement `db.rs` to read/write `data/smriti/planning.db`.
- **P1**: Expand `ignition` to include `down`, `scour`, `listen`, and `logs`.

## 11. Metrics Summary
- **Target F# Dependency Drop**: 12 operational commands slated for elimination.
- **Architectural Shift**: Transitioning from Polyglot orchestration to pure Rust/Gleam.

## 12. STAMP & Constitutional Alignment
- **SC-TODO-001**: `planning_daemon` will become the sole, authoritative gateway to `PROJECT_TODOLIST.md`, enforcing the non-manual edit rule.
- **SC-ZMOF-001**: `planning_daemon` will emit its status updates via Zenoh, adhering to the OTel-over-Zenoh backplane architecture.

## 13. Conclusion
The foundation for a complete F# to Rust operational migration is laid. By utilizing an organic evolutionary approach and establishing `planning_daemon` as a dedicated sibling to `ignition`, the c3i system maintains its homeostasis. The detailed master plan prioritizes non-destructive integration (Wave 1: The Planning Bridge) before actively overtaking lifecycle commands (Wave 2: Ignition Expansion). The system is now primed for the deep Rust implementation phase.
