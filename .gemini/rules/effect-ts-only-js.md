# Effect TypeScript Mandatory for All Browser JS (SC-EFFECT-TS-001..005)

## Mandate

**Per operator directive 2026-04-30 (operator-gated H-risk)**: all browser/runtime JavaScript and TypeScript code across C3I (not only `/planning`) MUST use [Effect TypeScript](https://effect.website/) (`effect` package, MIT licence) and MUST ship as bundled IIFE outputs via `esbuild`.

This is a **full IIFE collapse policy**:
- No new raw browser `.js` modules.
- New behavior must be authored in `.ts` + Effect abstractions.
- Delivery artifact must be IIFE bundle for script loading.

Vanilla JS remains legacy-only and must be migrated opportunistically.
Effect-TS provides:
- Structured concurrency (replaces `tokio::select!`-style inline blocking → [zk-c14e1d23afff486c])
- Schedule-based retry (replaces hand-rolled setTimeout retry)
- Layer/Context for DI (no global singletons)
- Cause/Exit for error tracking (no swallowed exceptions → [zk-3346fc607a1ef9e6])

## STAMP Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-EFFECT-TS-001 | All new browser/runtime JS behavior MUST be authored as `.ts` (no new raw `.js` logic) | CRITICAL |
| SC-EFFECT-TS-002 | All new TS MUST use Effect (`effect` package) for async/IO/state | CRITICAL |
| SC-EFFECT-TS-003 | Bundling MUST go through esbuild → bundled JS artifacts only | HIGH |
| SC-EFFECT-TS-004 | Bundle MUST be IIFE format (`--format=iife`) for direct `<script src>` loading | HIGH |
| SC-EFFECT-TS-005 | Selectors MUST live in a typed `Selectors` const, never guessed at runtime ([zk-bb4de67d97f807ac]) | CRITICAL |
| SC-EFFECT-TS-006 | Full IIFE collapse is mandatory for operator-gated H-risk UI/runtime paths | INFINITE |
| SC-EFFECT-TS-007 | Legacy JS touched during feature work MUST include migration delta toward Effect TS | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-EFFECT-TS-001 | NEVER add raw `.js` for new features; author in Effect TS and bundle as IIFE |
| AOR-EFFECT-TS-002 | ALWAYS run `npm run build` in `priv/web-build/` before committing |
| AOR-EFFECT-TS-003 | ALWAYS use `Effect.tryPromise` to wrap fetch (never bare `.then().catch()`) |
| AOR-EFFECT-TS-004 | ALWAYS use `Schedule.exponential` for retry (never hand-rolled timers) |
| AOR-EFFECT-TS-005 | ALWAYS use `Cause.pretty` in error logs (preserves stack + cause chain) |

## Reference Implementation

`lib/cepaf_gleam/priv/web-build/src/planning-grid.ts` (Pass-29) — first
fully-Effect-TS bundle replacing the 2007-LOC vanilla IIFE.

## Operator-Gated H-Risk Approval
Any exception to Effect-TS-only policy requires explicit operator approval and must be logged as H-risk waiver with rollback plan.

## Build Pipeline

```bash
cd lib/cepaf_gleam/priv/web-build
npm install
npm run build      # → priv/static/planning-grid.bundled.js (~244 KB minified)
npm run build:dev  # → with sourcemap, no minify
```

## Guard Implementation (Gleam-only per SC-SCRIPT-GLEAM-001)

The SC-EFFECT-TS-001 guard is implemented as a Gleam module — **no shell scripts**:

- Module: `sub-projects/scripts-gleam/src/scripts/verify/effect_ts_guard.gleam`
- Invocation: `cd sub-projects/scripts-gleam && gleam run -m scripts/verify/effect_ts_guard`
- Hook: `.claude/settings.json` PreToolUse on `Write|Edit` of `lib/cepaf_gleam/priv/static/*.js`
- Exit codes: `0` compliant · `1` violation (lists offenders to stderr)

Per operator directive 2026-04-30 ("no shell scripts, only script-gleam or rust code"),
the prior `.claude/scripts/effect-ts-guard.sh` was removed.

## Cross-references

- `.claude/rules/agentic-ui-responsive-design.md` (SC-AGUI-UI-*) — UI evolution
- `.claude/rules/page-spec-checker.md` (SC-PAGE-SPEC-*) — runtime conformance
- `docs/plans/20260430-1040-ui-refactor-roadmap-4-p1-items.md` §6 — Phase 4 IIFE split
