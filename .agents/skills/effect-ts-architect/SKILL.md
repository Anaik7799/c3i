---
name: effect-ts-architect
description: Use when creating, reviewing, or migrating TypeScript that must use Effect. Covers core `effect`, Schema, Layer/Context, Schedule, Stream, @effect/platform, @effect/rpc, @effect/sql, @effect/opentelemetry, @effect/ai, browser IIFE constraints, and migration away from fp-ts/Promise/null patterns.
---

# Effect TS Architect

## Trigger

Use for any TypeScript generation, TypeScript refactor, runtime JavaScript replacement, API/RPC/SQL/OTel/AI integration, or review of agent-authored TypeScript.

## Required Rules

- General TS: `.claude/rules/effect-ts-universal.md`
- Gemini mirror: `.gemini/rules/effect-ts-universal.md`
- Browser/IIFE: `.claude/rules/effect-ts-only-js.md`
- Gemini browser/IIFE mirror: `.gemini/rules/effect-ts-only-js.md`
- Detailed references: `.claude/skills/effect-ts-architect/references/`
- Gemini skill mirror: `.gemini/skills/effect-ts-architect/SKILL.md`

## Workflow

1. Classify the boundary: core, async IO, browser IIFE, HTTP, RPC, SQL, OTel, AI, CLI, or tests.
2. Use `effect` first; add `@effect/*` only for concrete platform/RPC/SQL/OTel/AI/CLI/test boundaries.
3. Keep internal APIs as `Effect.Effect<A, E, R>`.
4. Use `Option` for absence, `Schema` for external data, `Layer`/`Context` for services, `Schedule` for retries.
5. Reject new `fp-ts`, untyped JSON, raw Promise internal control flow, and new browser `.js`.
6. Run the nearest local check command.

## Evidence Commands

```bash
rg -n "from ['\"]fp-ts|fp-ts/" .
rg -n "from ['\"]effect['\"]|from ['\"]@effect/" <changed-ts-paths>
rg -n "new Promise|\\.then\\(|\\.catch\\(|setInterval\\(|setTimeout\\(" <changed-ts-paths>
```
