# Journal Entry: 20260404-2100 — Rust Migration Plan for F# Operational Commands

## 1. Scope & Trigger
**Why**: Eliminate the final operational dependencies on F# by migrating all `sa-*` CLI commands and the authoritative `sa-plan` task manager to the Rust `ignition` daemon.
**Trigger**: User directive to consolidate all system functions into Rust/Gleam and achieve total substrate independence.

## 2. Pre-State Assessment
**Quantified System State**:
- **Ignition Core**: Rust binary handles boot, status, and verification.
- **Planning**: Authoritative logic resides in F# (`sa-plan`), with data in SQLite (`planning.db`).
- **Gaps**: `sa-down`, `sa-scour`, `sa-listen`, and `sa-logs` are legacy F# shell wrappers or scripts.
- **Specification**: Allium v3 behavioral specs created for ZMOF, Ark, and FFI invariants.

## 3. Execution Detail
**Phase 1: Planning Migration (`sa-plan` -> `ignition plan`)**
- Implement `rusqlite` interface in Rust.
- Port task `list`, `add`, `update`, and `status` logic.
- Ensure `PROJECT_TODOLIST.md` is generated correctly from Rust.

**Phase 2: Lifecycle Completion (`sa-down`, `sa-scour`)**
- Implement graceful parallel shutdown in `src/down.rs`.
- Implement BLAKE3-aware nuclear clean in `src/scour.rs`.

**Phase 3: Debugging Parity (`sa-listen`, `sa-logs`)**
- Implement raw Zenoh payload inspection.
- Implement multi-container log tailing.

## 4. Root Cause Analysis
**Pattern-based 5-Why Grouping**:
1. **Consistency**: Unified tooling reduces operator cognitive load.
2. **Performance**: Rust provides lower latency for OODA-critical operations (like `sa-down`).
3. **Resilience**: A single statically-linked binary eliminates runtime dependencies (e.g., `.dotnet`).

## 5. Fix Taxonomy
- **Consolidation Pattern**: Moving disparate shell scripts into a unified subcommand architecture.
- **Shared State Pattern**: Ensuring both the new Rust `plan` and old F# `sa-plan` can interoperate during the cutover by sharing the same SQLite DB.

## 6. Patterns & Anti-Patterns Discovered
- **DO**: Use the existing `ignition` binary as the foundation for all new subcommands.
- **DO**: Maintain the "authoritative tool" mandate (SC-TODO-001) throughout the transition.
- **AVOID**: Manual edits to `PROJECT_TODOLIST.md` during implementation.

## 7. Verification Matrix
- **Binary Parity**: `ignition plan status` output must match `sa-plan status`.
- **Mesh Resilience**: `ignition down` must stop all 16 containers without orphaned processes.
- **Compilations**: Must pass `cargo check` with zero warnings (Muda compliance).

## 8. Files to be Modified
| File | Action | Purpose |
|:---|:---|:---|
| `native/ignition_daemon/Cargo.toml` | Update | Add `rusqlite`. |
| `native/ignition_daemon/src/main.rs` | Update | Register new subcommands. |
| `native/ignition_daemon/src/plan.rs` | NEW | Authoritative task management logic. |
| `native/ignition_daemon/src/down.rs` | NEW | Graceful mesh shutdown logic. |
| `native/ignition_daemon/src/scour.rs` | NEW | Substrate pruning logic. |

## 9. Architectural Observations
This migration transitions the system from a **Polyglot Substrate** to a **Bimodal Substrate** (Rust for Performance/CRI, Gleam for UI/OTP). This reduces the surface area for failure and simplifies the CI/CD pipeline.

## 10. Remaining Gaps
- **P0**: Move `LethalMutationGate` logic to the Rust OODA loop.
- **P1**: Implement `sa-genotype` DSL parser in Rust.

## 11. Metrics Summary
- **F# Dependencies**: 12 (Current) -> 0 (Target).
- **Binary Footprint**: Reduced by removing the need for .NET runtime in production.

## 12. STAMP & Constitutional Alignment
- **SC-TODO-001**: "All task management via sa-plan" is preserved by routing the `./sa-plan` wrapper to the new Rust binary.
- **SC-ZMOF-001**: New subcommands will utilize the Zenoh fractal namespace for all internal signaling.

## 13. Conclusion
The migration of `sa-plan` and the remaining lifecycle commands to Rust is the final step in the Indrajaal c3i "Substrate Independence" initiative. By centralizing all operational logic into the high-performance `ignition` daemon, we achieve a leaner, faster, and more auditable mesh. The implementation will follow the "Muda" principle, ensuring a clean, warning-free codebase that maintains the biomorphic mesh's homeostasis.
