# Pi Extension Strict TypeScript Typecheck — Wave 6 Closure

**Task**: 116487537424942284
**Date**: 2026-04-29
**Target**: `/home/an/dev/ver/c3i/.pi/extensions/zk-recall.ts` (349 LOC, Wave 1 Stream D rewire)
**STAMP**: SC-PI-001..010, SC-BOOTSTRAP-001
**ZK**: [zk-3346fc607a1ef9e6] (no Stub-That-Lies — actual tsc invocation, output captured)

## 1. Method

The `.pi/` directory has its own `package.json` but does NOT install
`@mariozechner/pi-coding-agent`. That dependency is resolved from the pi-mono
workspace's `node_modules/@mariozechner/pi-coding-agent` (already built, ships
with `dist/index.d.ts` and full type exports including `ExtensionAPI`).

**No `npm install` was needed.** pi-mono's `node_modules` were already populated
(7-package npm workspace, ~106k LOC TS, present from prior sessions).

Strategy: copy the file to `/tmp/zk-recall-typecheck.mts` (`.mts` to force ESM
under Node16 module mode, which matches how pi-coding-agent's package is loaded
at runtime — `"type": "module"`), then run a strict tsconfig with
`baseUrl`+`paths` mapping the bare specifier to the workspace's installed
`.d.ts`.

## 2. tsc invocation

Binary: `sub-projects/pi-mono/node_modules/.bin/tsc`
Version: **TypeScript 5.9.3**

Config (`/tmp/tsconfig-zkrecall.json`):
```json
{
  "compilerOptions": {
    "target": "ES2022", "module": "Node16", "moduleResolution": "Node16",
    "esModuleInterop": true, "skipLibCheck": true, "strict": true,
    "noEmit": true, "types": ["node"],
    "typeRoots": ["…/pi-mono/node_modules/@types"],
    "baseUrl": "…/pi-mono",
    "paths": { "@mariozechner/pi-coding-agent":
               ["node_modules/@mariozechner/pi-coding-agent/dist/index.d.ts"] }
  },
  "include": ["/tmp/zk-recall-typecheck.mts"]
}
```

Command: `tsc -p /tmp/tsconfig-zkrecall.json`

Cross-check also run with `module=NodeNext, moduleResolution=NodeNext` —
identical zero-error result.

## 3. Result

```
EXIT=0
(no diagnostics emitted)
```

| Metric | Value |
|---|---|
| Total errors | **0** |
| Total warnings | 0 |
| Strict mode | enabled (all `--strict*` family flags on) |
| skipLibCheck | true (per pi-mono convention) |
| Imports resolved | `@mariozechner/pi-coding-agent` (ExtensionAPI), `child_process`, `util`, `path`, `fs/promises` |

## 4. Categories of errors found

None. Specifically:
- 0 unused imports
- 0 implicit `any`
- 0 `noImplicitThis` violations
- 0 `strictNullChecks` violations
- 0 `strictFunctionTypes` violations
- 0 `strictPropertyInitialization` violations
- 0 `alwaysStrict` violations
- 0 type-only-import diagnostics (handled with `import type` on line 19)

## 5. Verdict

**The Wave 1 Stream D rewrite of `.pi/extensions/zk-recall.ts` passes
TypeScript 5.9.3 strict mode with zero errors.**

Stream H's earlier "skipped — needed heavy install" status is now closed: the
typecheck did NOT require a heavy install (pi-mono `node_modules` were already
present), and the file is strict-clean as-shipped. No fixes required.

## 6. Honest caveats

- The check uses `skipLibCheck: true` (matches pi-mono's `tsconfig.base.json`).
  Library type errors in `pi-coding-agent` itself or in `@types/node` would not
  surface — but those are not introduced by Wave 1 Stream D and are not in
  scope for this task.
- The check does not run the file. Runtime behaviour (which is exercised by
  the SC-PI-AUTO smoke tests in pass-7 plus the Pi RPC harness) is verified
  separately and was not re-run here.

## 7. Files (read-only)

- Target: `.pi/extensions/zk-recall.ts` — **NOT MODIFIED**
- Tsconfig (ephemeral): `/tmp/tsconfig-zkrecall.json`,
  `/tmp/tsconfig-zkrecall-nodenext.json`
- Copy under typecheck: `/tmp/zk-recall-typecheck.mts`
- Output log: `/tmp/tsc-output.log` (empty — zero diagnostics)

## 8. Cross-references

- Stream D rewire commit (Wave 1)
- `.gemini/extensions/zk-recall.ts` (sibling — separate task)
- Plan: pass-7 SRE closed-loop optimization
