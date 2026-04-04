# SA-* CLI & Rust Crate Inventory Audit

**Date**: 2026-04-04 22:40
**Session**: CLI command inventory and Rust crate analysis
**STAMP**: SC-SYNC-DOC-001, SC-GLM-UI-001, SC-UIGT-001

---

## 1. Scope & Trigger

Operator-initiated audit of all `sa-*` devenv commands and the three standalone Rust crates under `lib/rust/`. Goal: understand what exists, what runs them, and what language each uses.

## 2. Pre-State Assessment

- 50+ `sa-*` commands defined in `devenv.nix` (lines 382-730+)
- 3 Rust crates under `lib/rust/` with no devenv script wrappers
- 1 Rust FFI crate (`zenoh_ffi`) used as a native library, not a CLI
- No documentation connecting Rust crates to the sa-* CLI ecosystem

## 3. Execution Detail

### SA-* Command Inventory (devenv.nix)

All commands delegate to one of three backends:

| Backend | Command Pattern | Count |
|---------|----------------|-------|
| F# compiled CLI | `dotnet run --project ...fsproj -- mesh <cmd>` | ~15 (sa-up, sa-down, sa-status, sa-health, sa-scour, sa-clean, sa-resurrect, sa-security, sa-nuclear, sa-logs, sa-emergency, sa-verify, sa-monitor, sa-dashboard) |
| F# scripted (fsx) | `dotnet fsi lib/cepaf/scripts/*.fsx` | ~20 (sa-mesh-*, sa-swarm-*, sa-checkpoint-*, sa-bdd-smoke, sa-orchestrate, sa-ux, sa-fork, sa-restore) |
| Shell (bash) | `source scripts/*.sh` or `bash scripts/*.sh` | ~8 (governed-compile, governed-test, governed-wallaby, governed-exec, cpu-status, sa-sanitize-treesitter, test-orchestrate, zenoh-*-sub) |

**Zero Rust-based sa-* commands.**

### Command Categories

1. **Core Mesh Ops** (12): sa-up, sa-down, sa-status, sa-health, sa-scour, sa-clean, sa-logs, sa-emergency, sa-verify, sa-resurrect, sa-nuclear, sa-security
2. **SIL-6 Full Mesh** (10): sa-mesh, sa-mesh-boot, sa-mesh-status, sa-mesh-test, sa-test-obs, sa-test-cc, sa-test-mv, sa-test-zenoh, sa-test-agents, sa-bdd-smoke
3. **Enhanced Swarm** (9): sa-swarm-up/down/status/quorum/bio/dag/cpm/rca/verify
4. **Checkpoint/Restore** (6): sa-checkpoint, sa-checkpoint-verify, sa-checkpoint-restore, sa-checkpoint-list, sa-restore, sa-fork
5. **Monitoring/Cockpit** (5): sa-monitor, sa-dashboard, cockpit, sa-ux, sa-orchestrate
6. **Zenoh Subscribers** (4): zenoh-boot-sub, zenoh-test-sub, zenoh-smoke-sub, zenoh-all-sub
7. **CPU Governor** (5): governed-compile, governed-test, governed-wallaby, governed-exec, cpu-status
8. **Config/Boot** (5): sa-build-precompiled, sa-parallel-boot, sa-config-sync, sa-config-drift, sa-compose-gen
9. **Other** (5): sa-agents, sa-control, sa-plan, sa-orch, test-orchestrate

### Rust Crate Analysis

| Crate | Lines | Dependencies | Purpose |
|-------|-------|-------------|---------|
| `c3i_swarm_generator` | 513 | rayon, rand | Generates 900 FMEA/STAMP directives across 9 fractal layers using Rayon work-stealing. Outputs `C3I_MSTS_RUST_GENERATED_900.md` |
| `c3i_browser_regression` | 1,032 | reqwest, ratatui, crossterm, serde_json, chrono | Live Ratatui TUI running 40+ HTTP regression tests against all C3I Wisp endpoints (C1-C8 + AG-UI + A2UI). Supports `--headless` for CI |
| `c3i_agui_ideas` | ~800+ | std only | Generates 80+ AG-UI/A2A feature idea catalog with Zenoh topic mappings, criticality/usability/info/UX scores |

**Key finding**: All three are standalone offline tools — none are wired into devenv, sa-* CLI, or CI pipelines.

## 4. Root Cause Analysis

Rust crates were created as one-shot generators and exploratory tools during the AG-UI design phase. No integration story was defined because:
- F# CLI was the established command pattern
- Rust was used opportunistically for performance (Rayon) and TUI (Ratatui)
- No sa-* wrapper was created because they weren't part of the operational workflow

## 5. Fix Taxonomy

| Gap | Type | Priority |
|-----|------|----------|
| Rust crates have no devenv wrappers | Integration | P2 |
| `c3i_browser_regression` not in CI | Automation | P1 |
| `c3i_agui_ideas` catalog not referenced from CLAUDE.md | Documentation | P3 |
| No `cargo test` in quality gates | Testing | P2 |

## 6. Patterns & Anti-Patterns Discovered

**Patterns (Good)**:
- Consistent sa-* naming convention across all F# commands
- CPU Governor wraps all compute-intensive commands
- Help command provides comprehensive reference table

**Anti-Patterns**:
- Rust crates exist as orphaned tools with no integration path
- `c3i_browser_regression` duplicates some Gleam test coverage but adds value with live TUI and response-time assertions
- No cargo workspace — each crate is independent

## 7. Verification Matrix

| Check | Status |
|-------|--------|
| All sa-* commands documented in `help` | PASS (lines 990-1114) |
| All sa-* commands have devenv.nix definitions | PASS |
| Rust crates compile | NOT VERIFIED (no CI) |
| Rust crates have devenv wrappers | FAIL — none exist |
| zenoh-ffi-build is the only Rust devenv command | PASS |

## 8. Files Modified

None — this was a read-only audit.

**Files examined**:
- `devenv.nix` (lines 382-730, 990-1120)
- `lib/rust/c3i_swarm_generator/Cargo.toml` + `src/main.rs` (513 lines)
- `lib/rust/c3i_browser_regression/Cargo.toml` + `src/main.rs` (1,032 lines)
- `lib/rust/c3i_agui_ideas/Cargo.toml` + `src/main.rs` (~800+ lines)

## 9. Architectural Observations

1. The sa-* CLI is exclusively F#-backed. Rust is used only at the FFI boundary (zenoh_ffi) and for standalone tools.
2. `c3i_browser_regression` is the most operationally valuable Rust crate — it tests real HTTP endpoints with a live dashboard. This complements Gleam's gleeunit (which tests types/logic) and Wallaby (which tests LiveView).
3. The ZMOF backplane (new in v22.0.0) creates opportunity for a Rust-native Zenoh subscriber/publisher tool.
4. The 3 Rust crates share no workspace, dependencies, or common patterns.

## 10. Remaining Gaps

- No `sa-regression` or `sa-browser-test` command wrapping `c3i_browser_regression`
- No CI step for `cargo build` / `cargo test` on the 3 Rust crates
- `c3i_agui_ideas` output not referenced in design docs
- No Cargo workspace unifying the 3 crates + zenoh_ffi

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Total sa-* commands | ~56 |
| F# compiled commands | ~15 |
| F# scripted commands | ~20 |
| Shell commands | ~8 |
| Rust commands | 0 |
| Rust crates (lib/rust/) | 3 |
| Rust crate total LOC | ~2,345 |
| Integration gaps | 4 |

## 12. STAMP & Constitutional Alignment

- **SC-SYNC-DOC-001**: This audit documents previously undocumented Rust tooling
- **SC-FUNC-001**: Rust crates don't affect compilation (isolated)
- **SC-GLM-UI-001**: `c3i_browser_regression` validates triple-interface via HTTP
- **SC-UIGT-001**: Browser regression covers all 8 test categories (C1-C8)
- **SC-ZMOF-001**: New backplane creates integration opportunity for Rust Zenoh tools

## 13. Conclusion

The sa-* CLI is a mature, well-organized F#-first command system with ~56 commands across 9 categories. The 3 Rust crates under `lib/rust/` are valuable but orphaned — particularly `c3i_browser_regression` which provides unique live HTTP regression testing with a Ratatui dashboard. Integration into devenv and CI would close the gap between Rust tooling and the operational workflow.
