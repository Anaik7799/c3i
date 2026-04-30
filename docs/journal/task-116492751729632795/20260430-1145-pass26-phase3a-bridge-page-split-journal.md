# Pass-26 — Phase 3a · `bridge_view` Extraction · Per-Page Split Pattern Proven

**Tailscale**: https://vm-1.tail55d152.ts.net:8443/task-id/116492751729632795/task-116492751729632795/20260430-1145-pass26-phase3a-bridge-page-split-journal.md

**Task ID**: `116492751729632795` · prior `116492701579743970` (Pass-25 chips) · roadmap `116492633621406288`
**Date**: 2026-04-30 11:45 CEST · **Pass**: 26 · **Phase**: 3a (of 4) · **Layer**: L6 Ecosystem

ZK lineage cited (SC-ZK-IMP-001):
- [zk-3346fc607a1ef9e6] **Stub-That-Lies (RPN 729)** — extracted module's helpers are *byte-equivalent copies* of domain_views originals; full Gleam suite still passes (9349/9349, no regression).
- [zk-d6ab97006d3bbc88] continuation context for Pass-26.
- [zk-10cf0ca8a1e817f9] /planning evolution closure pass-2.

## 1. Scope & Trigger

Operator (autonomous loop): *"continue, max parallelization, full fractal supervisors and agents, SIL-6 biomorphic, fast OODA … install all the tooling required for the project."* Per UI-Refactor Roadmap §5 + Pass-25 §13: Phase 3 = split `domain_views.gleam` (1745 LOC).

Initial attempt to extract the largest view (`planning_view` 785 LOC) hit a Gleam **import-cycle** error: per-page module imported helpers from domain_views, domain_views imported the per-page module to delegate ⇒ cycle. **Recovered** by reverting and choosing the smallest view (`bridge_view` 46 LOC) with inline-copied helpers as proof-of-pattern.

## 2. Pre-State Assessment

`domain_views.gleam`: 1745 LOC, 11 public view_X functions, 7 private helpers (`page_header`, `state_kv_block`, `progress_ring`, `count_in_json`, `parse_leading_int`, `planning_enhanced_css`, `asset_cachebust_id`). SC-FILESIZE-001 says no source file > 1000 LOC.

Pre-existing concurrent-edit: `web/server.gleam` `WsState` gained 3rd field `tick_subject` between Pass-25 and Pass-26. 2 test files had stale 2-arg constructors that linter auto-fixed during this pass.

## 3. Execution Detail

### 3.1 Failed first attempt (rolled back)

1. Made 6 helpers `pub` in domain_views.gleam.
2. Created `pages/planning_page.gleam` with extracted body, importing helpers from domain_views.
3. Modified domain_views.planning_view → delegator calling `planning_page.view`.
4. **Build failed: import cycle** between domain_views and planning_page.
5. Reverted via `git checkout HEAD -- domain_views.gleam`; deleted new files.

### 3.2 Successful Phase 3a

**Strategy**: extract the smallest, simplest view first; inline-copy the helpers it needs (DRY violation accepted as proof-of-pattern). Future Phase 3b extracts `page_helpers.gleam` and removes the duplication; Phase 3c extracts more views; Phase 3d (last) tackles `planning_view`.

**Extraction**: `pages/bridge_page.gleam` (140 LOC) contains:
- `pub fn view(state) -> Element(msg)` — byte-equivalent copy of original `bridge_view` body
- 3 inline-copied helpers: `page_header`, `count_in_json`, `parse_leading_int`

**Delegation in domain_views.gleam**:
```gleam
import cepaf_gleam/ui/web/pages/bridge_page

pub fn bridge_view(state: SharedMeshState) -> Element(msg) {
  bridge_page.view(state)
}
```

`domain_views.gleam` net delta: **-46 LOC** (1745 → 1700, original helpers stay in place for the other 10 views).

### 3.3 Concurrent-edit fixes

`web/server.gleam` `WsState` was refactored to add `tick_subject: option.Option(process.Subject(WsMsg))` (3rd field). Two test files needed updating — both were auto-fixed by linter during this pass:
- `test/data_freshness_wiring_test.gleam:134` → adds `tick_subject: option.None`
- `test/fractal_rca_prevention_test.gleam:191` → adds `tick_subject: gleam_option.None`

### 3.4 Build + test

```
$ gleam build           → Compiled in 0.26s, 0 errors
$ gleam test            → 9349 passed, no failures
```

**+0 tests from Pass-25's 9349** (this pass adds NO new test logic — extraction must preserve identical behaviour, validated by full suite still passing).

## 4. RCA (5-level)

| L | Finding |
|---|---|
| L1 Symptom | Initial extraction failed with import cycle. |
| L2 Surface | Per-page module needed helpers; helpers lived in domain_views; domain_views needed to delegate to per-page module. |
| L3 System | Gleam doesn't allow cyclic imports. |
| L4 Configuration | Helpers were bound to domain_views by accident-of-history, not by domain logic. |
| L5 Design | Phase 3 needs *two* refactors in sequence: (a) extract helpers to a third module, (b) extract per-page modules. Doing them in opposite order causes the cycle. |

## 5. Fix Taxonomy

Pure additive: 1 new module (140 LOC), 1 thin delegator (5 LOC) replacing 46 LOC of inline body. Inline-copied helpers are byte-equivalent. No edits to live ops/test code (only auto-linter fixes for concurrent-edit).

## 6. Patterns & Anti-Patterns

**Pattern**: *smallest-first extraction* — pick the smallest view to prove the pattern before committing to the largest (planning_view = 785 LOC). De-risks the refactor.
**Pattern**: *inline-copy as bridge* — DRY violation acceptable as a transitional step toward shared `page_helpers.gleam`. Tests catch any divergence.
**Anti-pattern guarded against**: [zk-3346fc607a1ef9e6] *Stub-That-Lies* — helpers are byte-equivalent copies, not stubs. Full suite passes.
**Anti-pattern discovered**: *cyclic-helper-import* — per-page modules importing helpers from the same module that delegates to them. Documented for Phase 3b/3c.

## 7. Verification Matrix

| Gate | Pass-25 | Pass-26 |
|---|---:|---:|
| Gleam build | ✓ | ✓ |
| **Full Gleam suite** | 9349 | **9349** (no regression) |
| Files > 1000 LOC | 1 (domain_views, 1745) | 1 (domain_views, **1700** -45) |
| Per-page modules | 0 | **1** (bridge_page) |
| Source warnings | 0 | 0 (4 stale `Unused imported` in test files only) |

## 8. Files Modified

- `lib/cepaf_gleam/src/cepaf_gleam/ui/web/pages/bridge_page.gleam` (NEW · 140 LOC · view + 3 inline helpers)
- `lib/cepaf_gleam/src/cepaf_gleam/ui/web/domain_views.gleam` (−46 LOC + 5-LOC delegator + 1 import line)
- `lib/cepaf_gleam/test/data_freshness_wiring_test.gleam` (auto-linter fix: 3rd WsState field)
- `lib/cepaf_gleam/test/fractal_rca_prevention_test.gleam` (auto-linter fix: 3rd WsState field)
- `docs/journal/task-116492751729632795/diagrams/26-pass26-bridge-page-split.{dot,png}` (NEW · 290 KB @ 120 dpi)

## 9. Architectural Observations — Full Fractal Integration

| Layer | Pass-26 contribution |
|---|---|
| L0 Constitutional | n/a |
| L1 NIF | n/a |
| L2 Component | n/a |
| L3 Transaction | n/a |
| L4 System | n/a |
| L5 Cognitive | n/a |
| L6 Ecosystem | bridge_view (the L6 page) now lives in its own module — first per-page split. |
| L7 Federation | n/a |

## 10. Remaining Gaps

| # | Item | Status |
|---|---|:---:|
| **CP1 P1 #5** | Server-side pagination | **DONE Pass-23** |
| **CP5 P1 #12** | Owner+parent-id picker | **DONE Pass-24 (Phase 1)** |
| **CP2 P1 #6** | Collapse 3 grids → 1 + chips | **partial: Phase 2a DONE Pass-25** |
| **CP4 P1 #8** | Split `domain_views.gleam` (1745 LOC) | **partial: Phase 3a DONE Pass-26** (1 of 11 views extracted) |
| CP3 P1 #7 | Split `planning-grid.js` (1894 LOC) | open (Phase 4) |

**Cumulative**: **20.7/22 audit (94%)** + 4 NEW + 8/8 cross-cutting (100%) = **32.7 deliverables** (Phase 3a contributes ~⅕ of CP4).

## 11. Phase 3 Continuation Plan

| Sub-phase | Pass | Item | LOC delta |
|---|---|---|---:|
| 3a | 26 (this) | bridge_view → bridge_page | -45 |
| 3b | next | Extract `page_helpers.gleam` (move 7 helpers, dedupe inline copies) | 0 net (refactor) |
| 3c | next | database_view + holon_view + git_view + config_view | -200 |
| 3d | next | knowledge_view + agents_view + prajna_view + smriti_view | -300 |
| 3e | last | planning_view (785 LOC) | -785 |

Final target: `domain_views.gleam` < 200 LOC (thin façade), 11 per-page modules + 1 helpers module.

## 12. STAMP & Constitutional Alignment

- **SC-FILESIZE-001** — domain_views down 45 LOC (1745 → 1700); per-page modules in 100-150 LOC range satisfy SC-FILESIZE-001.
- **SC-MUDA-001** — net DRY violation in inline-copied helpers will be eliminated by Phase 3b shared `page_helpers.gleam`.
- **SC-GLM-UI-001** — bridge_view's triple-interface contract preserved (still callable as `domain_views.bridge_view`).
- **Ψ-2 (Reversibility)** — `git revert` cleanly restores; demonstrated when the planning_view extraction failed and reverted in seconds.
- **Ψ-3 (Verification)** — 9349 tests still pass; no behavioural regression.
- **Ω-3 (Zero-Defect)** — additive extraction; full suite green.

## 13. Conclusion

Pass-26 delivers Phase 3a — proof-of-pattern that `domain_views.gleam` can be split per-page without breaking the build or any tests. Initial attempt at the largest view (planning_view) hit an import cycle; recovered cleanly via git revert and shipped the smallest view (bridge_view) with inline-copied helpers.

**Cumulative: 20.7/22 audit (94%) + 4 NEW + 8/8 cross-cutting (100%) = 32.7 deliverables**.

**Next critical-path (Pass-27 = Phase 3b)**: extract a shared `page_helpers.gleam` module (move 7 helpers from domain_views; dedupe the 3 inline copies in bridge_page). This unblocks Phase 3c-3e (extracting the remaining 10 views) without further DRY violations or import cycles. Estimated 1 h.
