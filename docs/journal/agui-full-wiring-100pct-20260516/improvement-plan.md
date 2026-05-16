# Improvement Plan — Significant Wiring Upgrades (Pass-28 → Pass-N)

## Honest gap inventory (mechanically probed, anti-Stub-That-Lies)

| # | Gap | Severity | Evidence | Improvement |
|---|---|---|---|---|
| 1 | **Empty `change-log-feed` div** on every page | HIGH | `curl /immune \| grep -c "change-log-feed.*></div>" → 1` (empty container) | Wire to existing 8 WebSocket endpoints. Each page subscribes to its `/ws/<page>` and pushes diff events into the feed. |
| 2 | **Empty `detail-panel-body` initial state** on every page until clicked | MEDIUM | drill-down only populates on user click; no per-page default content | Inject page-specific "what to expect" preview (status counts, last update timestamp) on page load. |
| 3 | **`agui-chrome.js` is vanilla JS, not Effect-TS** | MEDIUM (SC-EFFECT-TS-001 violation) | `priv/static/agui-chrome.js` is plain IIFE | Migrate to Effect TypeScript under `priv/web-build/src/` per `.claude/rules/effect-ts-only-js.md`. |
| 4 | **Gemma chat shows 401 to anonymous users** with no auth UI | LOW | `POST /api/v1/ai/chat → 401` | Add inline auth-prompt or anonymous-fallback (uses cached responses). |
| 5 | **AI search filters DOM textContent, not semantic** | MEDIUM | `agui-chrome.js` `searchInputs[…].input` handler does substring `.textContent.toLowerCase()` only | Wire to `/api/v1/knowledge_search` (NIF-backed FTS5 + embeddings) for cross-page semantic search. |
| 6 | **Fractal-filter only filters `[data-layer]` + textContent fallback** | LOW | line 53-54 of `agui-chrome.js` | Pages should set `data-layer="lN"` on every section; currently most don't. |
| 7 | **AGUI conformance: UI-005 gemma-chat passes via substring** | LOW | 30 pages at 10/11, the missing point is structural | Validator could be strengthened to require `chat-panel-form` element specifically. |
| 8 | **No per-page WebSocket attachment indicator** | LOW | heartbeat exists only on /cockpit | Add small `[●live]` badge to chrome that shows last WS message age. |
| 9 | **Per-page LTS specs absent for 27 of 32 pages** | HIGH (SC-UIGT-003) | `specs/allium/*.allium` covers only ~5 pages | Auto-generate Allium spec stub from each Lustre `Model`/`Msg` ADT. |
| 10 | **Wallaby/Playwright browser tests cover ~5 pages** | HIGH (SC-AGUI-UI-010) | only `/planning` has 179-test E2E | Generate baseline Playwright tests for the other 27 pages from page-checker substring rules. |

## Top-3 highest-leverage upgrades (ROI > effort)

### #1 — Wire change-log feed to WS event stream
**Effort**: ~80 LOC JS + 30 LOC per-page server | **Value**: turns 32 stub feeds into real-time mutation displays.

Each page already has its own Wisp route returning JSON state. Extend the existing `/ws/<page>` handlers (8 already exist for /planning, /dashboard, /cockpit) to push diff events. The chrome's `agui-change-log` opens a single WebSocket on page load and renders incoming events.

### #2 — Migrate agui-chrome.js → Effect TS IIFE
**Effort**: ~200 LOC TS + esbuild config | **Value**: brings the cross-page chrome under SC-EFFECT-TS-001..007 compliance (operator-gated H-risk family).

Author `priv/web-build/src/agui-chrome.ts` using `Effect`, `Schedule.exponential` for retry, `Schema` for incoming WS payloads. Build to IIFE bundle. Removes the last raw-JS file from the static directory.

### #3 — Auto-generate per-page Allium specs
**Effort**: ~150 LOC Gleam codegen tool | **Value**: lifts 27 pages from L-spec-absent to L-spec-present, unblocking SC-UIGT-003 (prime path coverage).

Read every `ui/lustre/*.gleam` file, extract `Model` fields + `Msg` variants, emit `specs/allium/<page>.allium` with the LTS skeleton. Operator fills in `@guidance` annotations.

## Math gates (current state)

```
H (Shannon entropy over 8 test categories)    = 2.67 bits  (target ≥ 2.5  ✓)
CCM (cyclomatic-coverage composite)           = 0.770      (target ≥ 0.90 IMPROVING)
ITQS (integrated test quality)                = 0.736      (target ≥ 0.85 IMPROVING)
D_EA (expected vs actual divergence)          = TBD        (target ≤ 0.10)
PageRank max                                  = Dashboard 0.055
```

CCM gap (0.770 → 0.90 = +17%) primarily caused by uneven C5 (interactive) and C8 (action button) coverage on the 27 non-planning pages.

## Recommended sequencing

| Pass | Focus | Lifts |
|---|---|---|
| 29 | Change-log WS wiring | UI-007 stub → real event feed, 32 pages |
| 30 | Effect-TS chrome migration | SC-EFFECT-TS compliance |
| 31 | Allium spec auto-gen | 27 page L-specs → SC-UIGT-003 coverage |
| 32 | Playwright baseline for 27 pages | SC-AGUI-UI-010 coverage; CCM 0.77 → 0.85+ |
| 33 | Semantic AI search wiring | UI-003 textContent → FTS5+embeddings |

After pass-33: estimated CCM ≥ 0.90, ITQS ≥ 0.85, all 32 pages with executable E2E coverage.

## Anti-pattern guardrails carried forward

- [zk-bd82645aedcb5ef4] Stub-That-Lies (RPN 729) — never ship class name without handler; validator chain enforces
- [zk-50657feb899e0a2f] Two-step collapse — ship enhancement alongside legacy first
- [zk-c14e1d23afff486c] Implicit invariants — every co-dependent pair gets a machine check
- [zk-426c4adf07d076ad] Measure don't assert — every "✓" backed by mechanical evidence
