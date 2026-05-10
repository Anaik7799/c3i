# FP-Rust Stack — Way of Working

Tailscale: https://vm-1.tail55d152.ts.net:4200/task-id/116499874901057156/way-of-working.md

> Operating cadence, OODA integration, conflict resolution, governance flow, and operator surfaces for the 12-library FP-Rust stack. Companion to `analysis.html` (the what) and `user-guide.md` (the how).

---

## OODA cycle integration

Every FP-discipline change rides the standard C3I OODA loop:

| Phase | What happens | Tool |
|---|---|---|
| **Observe** | Read FP-1..FP-12 from the live KPI feed | `GET /api/v1/fp-kpi` |
| **Orient** | ZK recall — which prior pass moved this KPI? Which library is involved? | `sa-plan-daemon knowledge-search "FP-N <kpi-name>"` |
| **Decide** | Choose the **smallest** change that moves the lagging KPI | RETE-UL fp_discipline rules |
| **Act** | Edit code, add proptest, run criterion bench | cargo + proptest + criterion |
| **Verify** | gleam test + cargo test + cargo bench + cargo kani (vault only) | full pyramid |

The OODA budget is unchanged: Observe < 30 ms, Orient < 100 ms, Decide < 50 ms, Act varies, Verify ≤ 30 s.

---

## Per-pass cadence

### Daily (every working session)
- Agent runs `cd sub-projects/scripts-gleam && gleam run -m scripts/verify/fp_purity` at session start.
- Output: 12 KPI values + 4 composites, published to Zenoh under `indrajaal/l5/cog/fp/{kpi}/**`.
- Hooks `UserPromptSubmit` and `Stop` consume the snapshot.

### Weekly (Sunday 02:00 UTC, cron)
- `cargo kani --harness vault_sealed_invariant` runs in the dedicated multiverse worktree.
- Result published to `indrajaal/l5/cog/fp/kani/vault_sealed/{ok|fail}`.
- A failure opens a P0 sa-plan task automatically (RETE-UL `FpVaultBelowFloor`).

### Per-PR (CI gate)
- Criterion regression check on the 6 hot-path benches (`cortex_dispatch`, `cache_get`, `pii_scrub`, `rule_evaluate`, `trace_finish`, `ingest_validated`).
- If FP-9 (`alloc_delta`) > +20% vs `main`, the PR is **blocked** until justified or reverted.

---

## Per-surface workflow

| Surface | Allowed FP libraries | Notes |
|---|---|---|
| `planning_daemon` (Rust, async, online) | full 12-library stack | reference implementation |
| `c3i_nif` (Rust, sync, BEAM-bound) | `derive_more`, `nutype`, `itertools`, `either` | NO `rayon`, NO `tower`, NO async |
| `rusty_vault_nif` (Rust, sync, sealed) | `derive_more`, `nutype`, `proptest`, `kani-verifier` | crate budget per SC-FP-RUST-014 |
| `scripts_nif` (Rust, sync, scripts-gleam) | `itertools`, `either`, `derive_more` | lightweight, no heap-heavy crates |

Cross-surface drift is caught by `cargo-deny` rules in each crate's `deny.toml`.

---

## Governance flow — adding a new library

When a future pass needs an FP library not in the 12-library stack:

1. **Brainstorming skill** — confirm fit, capture intent.
2. **ZK recall** — `sa-plan-daemon knowledge-search "<crate-name>"` — has anyone tried this lib?
3. **Multiverse branch** — `git worktree add ../mv-fp-<name> -b multiverse/fp-<name> main`.
4. **Add to Cargo.toml** with version pin.
5. **Vault-adjacent audit** — `cd lib/cepaf_gleam/native/rusty_vault_nif && cargo tree | grep -iE 'tongsuo|sm[234]'` MUST be empty.
6. **Criterion bench baseline** — capture `target/criterion/` snapshot before and after.
7. **At least one reference call site** in the appropriate surface.
8. **Add proptest properties** for the new abstraction.
9. **Update `wiring_guard.gleam`** if any new types cross the BEAM boundary.
10. **Update `pi_claude_code.gleam`** if tool federation count changes (currently 93).
11. **Open sa-plan task** via `./sa-plan add "<desc>" P1`; attach to the multiverse branch.
12. **Author closure pack** following this protocol (analysis.html + user-guide.md + way-of-working.md + journal).
13. **Email + ZK ingest** via `sa-plan-daemon send-email` + Stop hook.
14. **CPIG matrix bump** — record subsystem score increment in `docs/journal/task-116480247290237220/cpig-matrix.json`.

---

## Conflict resolution — when libraries fight

| Conflict | Resolution |
|---|---|
| `rayon` vs `tokio` | `rayon` offline only (build-time, fixture regen, batch ingest). `tokio` for any online path. **Never mix in the same call stack.** |
| `rpds` vs `Vec` / `HashMap` | `rpds` for long-lived state needing snapshots. `Vec` / `HashMap` for hot-loop locals (allocator pressure wins). |
| `tower` vs raw `async fn` | `tower` when you need retry / circuit-break / timeout / rate-limit. Raw `async fn` for trivial one-shot ops. |
| `nutype` vs `derive_more` | `nutype` when validation is needed. `derive_more` when only wrapping. **Usually you want both** — `nutype` for the validator, `derive_more` for the additional traits not covered by nutype's derive list. |
| `frunk::Validated` vs `Result` | `Validated` when accumulating multiple independent errors (ingest, batch validation). `Result + ?` when first error should short-circuit. |
| `winnow` vs hand-rolled | `winnow` for any format ≥ 3 alternatives or with recursive structure. Hand-rolled OK for trivial split-by-delimiter. |
| `recursion` vs native | `recursion` when worst-case depth ≥ 100. Native recursion fine when depth bound proven < 100. |

---

## KPI escalation thresholds

| KPI | Yellow (warn) | Red (block) |
|---|---|---|
| `FP_TOTAL` | < 0.75 | < 0.65 |
| `FP_VAULT` | < 0.85 | < 0.75 |
| `FP_HOTPATH` | < 0.70 | < 0.55 |
| `FP_DRIFT λ` | < 0.0 over 1 pass | < 0.0 over 3 passes |

Yellow = advisory, surfaced in dashboard amber tile.
Red = automatic P0 sa-plan task; new feature commits to that surface BLOCKED until score recovers (mirrors SC-CPIG-010).

---

## Operator surfaces

| Surface | URL / command |
|---|---|
| Dashboard tile (HTML) | https://vm-1.tail55d152.ts.net:4100/fp-kpi |
| REST API (JSON) | `GET /api/v1/fp-kpi` — returns all 12 + 4 composites |
| TUI | split-screen tab #15 "FP Discipline" |
| MCP tool | `fp_score(scope: planning_daemon \| c3i_nif \| rusty_vault_nif \| scripts_nif \| composite)` |
| Zenoh topic | `indrajaal/l5/cog/fp/{kpi}/**` |
| CLI | `./sa-plan fp-status` |

The dashboard tile auto-refreshes every 30 s (matches SC-CPIG-015 cadence). The TUI tab streams live via the WebSocket diff-detected push protocol (1 s ping; full update on KPI change).

---

## Ingestion + closure protocol

After every FP-discipline pass:

1. Journal entry under `docs/journal/task-<id>/journal.md` (13-section per SC-JOURNAL).
2. Analysis HTML + user-guide + way-of-working under `docs/journal/task-<id>/`.
3. Email via `sa-plan-daemon send-email -a journal.md -a analysis.html -a user-guide.md -a way-of-working.md`.
4. ZK ingest via `sa-plan-daemon ingest-docs` (Stop hook handles automatically).
5. CPIG matrix subsystem score bump (manual edit + commit).
6. Tailscale link surfaced in journal first line + email body (per SC-NOTIFY-JOURNAL-002).

This document IS the way-of-working. Future FP-discipline passes inherit it verbatim.
