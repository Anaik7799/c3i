# /planning page evolution closure protocol (SC-PLANNING-EVO)

**Status:** MANDATORY for any commit that touches `lib/cepaf_gleam/priv/static/planning-grid.js`, `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam` (planning routes), `rules/engine.gleam` UI domain, or `web/domain_views.gleam`.

This rule encodes the closure pattern proven by sa-plan task `urn:c3i:task:misc:116492319530224001` (2026-04-30). It is the `/planning`-specific specialization of SC-FEAT-EVO + SC-FRAC-RRF + SC-AGUI-UI + SC-PAGE-SPEC.

## STAMP constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-PLANNING-EVO-001 | Every PR touching `/planning` MUST run `gleam test` (≥ 9 000 passes, 0 failures) | CRITICAL |
| SC-PLANNING-EVO-002 | Every PR MUST run `gleam run -m scripts/verify/page_checker` and produce `pass=32/32 drift=0` | CRITICAL |
| SC-PLANNING-EVO-003 | Every PR MUST run `gleam run -m scripts/verify/data_quality_scan` and produce `total=0` violations | CRITICAL |
| SC-PLANNING-EVO-004 | Every PR MUST run a Playwright sweep verifying all 4 view modes + WS + freshness + responsive | HIGH |
| SC-PLANNING-EVO-005 | Every PR MUST update `specs/allium/planning_page.allium` if any new entity / contract / invariant emerges | HIGH |
| SC-PLANNING-EVO-006 | Every PR MUST emit OTel spans on `indrajaal/otel/spans/planning/{op}` for every state change | HIGH |
| SC-PLANNING-EVO-007 | Every PR MUST keep `data-view` ↔ `*-section` ID convention (SC-AGUI-UI-001 view mutual exclusion) | CRITICAL |
| SC-PLANNING-EVO-008 | Every PR closing the loop MUST attach 9 diagrams (graphviz → PNG) to the journal | MEDIUM |
| SC-PLANNING-EVO-009 | Every PR MUST keep DAG-Q triple-transport parity (WS == SSE == HTTP within ±1) | HIGH |
| SC-PLANNING-EVO-010 | Mathematical gates: H ≥ 2.5, CCM ≥ 0.90, ITQS ≥ 0.85, D_EA ≤ 0.10, λ ≥ 0, ΣRPN reduction ≥ 40 % | CRITICAL |

## AOR rules

| ID | Rule |
|----|------|
| AOR-PLANNING-EVO-001 | NEVER toggle a view mode without verifying that exactly one `*-section` becomes visible |
| AOR-PLANNING-EVO-002 | NEVER ship a `/planning` change without re-running the full Playwright sweep |
| AOR-PLANNING-EVO-003 | ALWAYS author the closure pack (journal + analysis HTML + deck + 9 diagrams) under `docs/journal/<task-id>/` |
| AOR-PLANNING-EVO-004 | ALWAYS bump the CPIG matrix subsystem score after email closure |
| AOR-PLANNING-EVO-005 | NEVER commit uncommitted JS / router / engine deltas without the closure pack |
| AOR-PLANNING-EVO-006 | ALWAYS use `gleam run -m scripts/verify/<gate>` (no shell scripts) per SC-SCRIPT-GLEAM-001 |

## Closure pack manifest (`docs/journal/<task-id>/`)

```
journal.md                       # 13-section narrative
fractal-criticality-matrix.md    # L0-L7 × 10 components × {STAMP,RETE-UL,FMEA}
playwright/playwright-report.md  # E2E coverage matrix
diagrams/dot/01..09.dot          # 9 graphviz sources
diagrams/png/01..09.png          # rendered (≥ 140 dpi)
screenshots/                     # Chromium captures @ 1400/768/375
analysis.html                    # operator-facing summary
deck.html                        # slide deck (10-12 slides)
task-<id>-links.json             # link registry (delivery)
```

Plus:
- `specs/allium/planning_page.allium` (formal spec)
- `docs/test-plans/planning/{README,phase-1..7}.md` (phased test plan)
- `.claude/rules/planning-page-evolution.md` (this rule)
- `.gemini/rules/planning-page-evolution.md` (mirror, SC-SYNC-DOC-007)

## Verification recipe (one-liner)

```bash
TID=<task-id>
cd /home/an/dev/ver/c3i/lib/cepaf_gleam && gleam build && gleam test
cd /home/an/dev/ver/c3i/sub-projects/scripts-gleam && \
  gleam run -m scripts/verify/page_checker && \
  gleam run -m scripts/verify/data_quality_scan
# Playwright via mcp__playwright (operator orchestrated)
ls /home/an/dev/ver/c3i/docs/journal/task-$TID/{journal.md,analysis.html,deck.html,fractal-criticality-matrix.md,diagrams/png,screenshots,playwright}
sa-plan-daemon ingest-docs
sa-plan-daemon send-email -a journal.md -a analysis.html -a deck.html
```

## Cross-references
- SC-AGUI-UI-001..015 — agentic responsive design (parent)
- SC-FRAC-RRF-001..010 — fractal criticality matrix
- SC-PAGE-SPEC-001..008 — page-spec runtime checker
- SC-VALUE-GUARD-001..008 — Tasks table enum integrity
- SC-FEAT-EVO-001..013 + SC-FEAT-EVO-LIB-001..008 — feature evolution
- SC-SCRIPT-EVO-001 + SC-SCRIPT-GLEAM-001 — orchestrator authoring
- SC-NOTIFY-JOURNAL-001..004 — email closure
- SC-WIRE-001..007 — wiring guard
- SC-CPIG-001..015 — cross-pass invariant gates
- SC-MATH-COV-001..008 — mathematical gates
- SC-PI-EVO-001..010 — Pi symbiosis verify

## Governance parity
Mirror at `.gemini/rules/planning-page-evolution.md` per SC-SYNC-DOC-007.

## Pass history
- **pass-1** (2026-04-30): closure of `/planning` JS / router / RETE-UL deltas + Allium spec + journal + 9 diagrams + 7-phase test plan + governance. 9 230 tests, 17/17 Playwright components, ΣRPN −58 %, CPIG Gleam-UI 5/5.
- **pass-2** (2026-04-30, same task): closed all 5 next-pass items. Cross-browser Playwright (`tests/playwright/planning.spec.ts`, 5 cases × 5 projects, 15/15 on Chromium + Firefox + mobile-Chromium; WebKit env-blocked → libicudata install required). Federated multi-region CPIG (`scripts/verify/cpig_federation.gleam` + `common/crypto.gleam` + `scripts_crypto_ffi.erl`, Ed25519 + 2oo3 + freshness, 10 new tests). Service-worker offline cache (`priv/static/sw.js` + `sw-register.js`, wired in `shell.gleam`, registered scope `/`). Pi RPC persistent daemon (`bridge/pi_daemon.gleam`, OTP supervised port-spawn). Drag-drop kanban + true server-push (`planning-grid.js` HTML5 DnD + `POST /api/v1/plan/update` + WS broadcaster). System CPIG score: 95.0 % (57/60 gates).

