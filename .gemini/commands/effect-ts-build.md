---
name: effect-ts-build
description: Build the Effect-TS browser bundle from `priv/web-build/src/*.ts` to `priv/static/*.bundled.js` via esbuild. Verifies SC-EFFECT-TS-001..007 compliance, runs `node -c` syntax check, and emits the bundle size. Use after any TS edit; required before merging.
---

# Effect-TS Build & Verify Skill

## When to use

- After editing any `lib/cepaf_gleam/priv/web-build/src/*.ts`
- Before merging changes touching browser-loaded JS
- When the chip / view-toggle / weather bar behaves unexpectedly on `/planning`
- As part of any `/feature-evolution` or `/c3i-page-evolution` cycle

## Steps

```bash
# 1. Build the IIFE bundle
cd lib/cepaf_gleam/priv/web-build
npm install --no-audit --no-fund   # idempotent; only first run
npm run build

# 2. Syntax-validate the bundle
node -c ../static/planning-grid.bundled.js
ls -la ../static/planning-grid.bundled.js

# 3. Run the SC-EFFECT-TS guard (Gleam-only per SC-SCRIPT-GLEAM-001)
cd ../../../../sub-projects/scripts-gleam && gleam run -m scripts/verify/effect_ts_guard
cd -

# 4. Verify Gleam build still green
cd ../../  # back to lib/cepaf_gleam
gleam build
gleam test --target erlang | grep -E "passed|failures" | tail -1
```

## Acceptance criteria

| Gate | Expected |
|---|---|
| `npm run build` exit | 0 |
| `node -c bundled.js` | OK |
| `effect_ts_guard` Gleam module | exit 0 (no SC-EFFECT-TS-001 violation) |
| `gleam build` | Compiled, 0 errors |
| `gleam test` | 9349+ passed, 0 failures |
| Bundle size | < 500 KB (current: ~385 KB) |

## STAMP refs

- SC-EFFECT-TS-001..007 (`.claude/rules/effect-ts-only-js.md`)
- SC-FILESIZE-001
- SC-AGUI-UI-013

## Reference TS source

`lib/cepaf_gleam/priv/web-build/src/planning-grid.ts` — first
fully-Effect-TS module (525 LOC source → 385 KB minified IIFE).
