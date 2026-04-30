---
name: planning-page-evolution
description: Run the canonical /planning page closure pack — gleam build/test, page-spec checker, value-guard scan, Playwright sweep across 4 view modes + 3 viewports, fractal-criticality matrix, Allium spec, 9 graphviz diagrams, 13-section journal, analysis HTML, slide deck, link registry, ZK ingest, email, governance parity, and CPIG matrix bump. Triggers SC-PLANNING-EVO-001..010.
trigger: PR or commit touches lib/cepaf_gleam/priv/static/planning-grid.js, lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam (planning routes), rules/engine.gleam UI domain, or web/domain_views.gleam.
---

# planning-page-evolution skill

## When to invoke

After any change to `/planning` source files (JS, Wisp router, RETE-UL UI domain, Lustre views) — before commit/push.

## What it does

1. **P0 gates** — `gleam build`, `gleam test` (≥ 9 000 / 0 fail).
2. **P0 wiring** — `wiring_guard_test`, `gleam run -m scripts/verify/page_checker`, `gleam run -m scripts/verify/data_quality_scan`.
3. **sa-plan task** — allocate URN, transition `in_progress`.
4. **P1 Playwright** — Chromium @ 1400/768/375 × {grid, kanban, timeline, analytics} + WS + freshness + AI search + fractal chips.
5. **P1 fractal-criticality matrix** — score 8 × 10 cells, RETE-UL salience, ruliology, FMEA RPN.
6. **P1 Allium spec** — `specs/allium/planning_page.allium` updated.
7. **P2 9 diagrams** — graphviz `dot` → PNG.
8. **P2 closure pack** — 13-section journal, analysis HTML, slide deck.
9. **P2 7-phase test plan** — `docs/test-plans/planning/{README,phase-1..7}.md`.
10. **P2 governance parity** — `.claude / .gemini` rules mirror.
11. **P0 close-out** — link registry, ZK ingest, SMTP email, ICP v2.0 commit, ff-only push.
12. **P0 CPIG bump** — Gleam UI Triple-Interface 4/5 → 5/5 in `cpig-matrix.json` after email confirmed.

## Math gates (must hold at exit)

```
Shannon H ≥ 2.5  ·  CCM ≥ 0.90  ·  ITQS ≥ 0.85  ·  D_EA ≤ 0.10  ·  λ ≥ 0  ·  ΣRPN reduction ≥ 40 %
```

## Rule
See `.claude/rules/planning-page-evolution.md` (SC-PLANNING-EVO-001..010).

## Prior closure
`urn:c3i:task:misc:116492319530224001` (2026-04-30) closed with 9 225 tests, 17/17 components, ΣRPN −58 %.
