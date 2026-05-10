# Effect TypeScript Mandatory for All TypeScript (SC-EFFECT-TS-008..020)

## Mandate

Per operator directive 2026-05-09, all TypeScript generated or modified by users or agents MUST use [Effect](https://effect.website/) as the functional runtime and standard library. This supersedes the prior fp-ts instruction.

Use `effect` for core data and control flow:

- `Effect` for async, sync throwable work, resource lifecycles, timeouts, retries, and error channels.
- `Option` for nullable or missing values.
- `Either`, `Exit`, and `Cause` for explicit failures and diagnostic boundaries.
- `Schema` for untrusted JSON, MCP payloads, CLI/config/env inputs, API responses, and generated contracts.
- `Layer` and `Context` for services instead of global singletons.
- `Schedule`, `Duration`, `Stream`, `Queue`, `PubSub`, and `Fiber` for retry, streaming, and concurrency.

## Scope

This rule applies to:

- C3I browser/runtime TypeScript and the existing IIFE pipeline.
- Pi-mono TypeScript under `sub-projects/pi-mono`.
- Node/Bun/CLI TypeScript, generated TypeScript, provider integrations, bridge modules, and tests authored or modified by users/agents.
- Agent-authored TypeScript snippets in docs when intended to be copied into production code.

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-EFFECT-TS-008 | All new or modified TS logic MUST import from `effect` or an `@effect/*` package | CRITICAL |
| SC-EFFECT-TS-009 | Async IO MUST be represented as `Effect.Effect<A, E, R>` until the outermost boundary | CRITICAL |
| SC-EFFECT-TS-010 | Promise boundaries MUST use `Effect.runPromise`, `Effect.runPromiseExit`, or runtime-specific runners only at API edges | CRITICAL |
| SC-EFFECT-TS-011 | Throwable sync work MUST use `Effect.try`; promise work MUST use `Effect.tryPromise` | CRITICAL |
| SC-EFFECT-TS-012 | Nullable values MUST use `Option`; do not add new ad hoc `null`/`undefined` control flow | HIGH |
| SC-EFFECT-TS-013 | Validation of external data MUST use `Schema` and typed parse/decode effects | CRITICAL |
| SC-EFFECT-TS-014 | Retries, polling, and backoff MUST use `Schedule`; no hand-rolled timer loops | HIGH |
| SC-EFFECT-TS-015 | Services MUST use `Context.Tag` + `Layer` when dependencies cross module boundaries | HIGH |
| SC-EFFECT-TS-016 | Error logs MUST preserve `Cause`/`Exit` context; no swallowed exceptions | CRITICAL |
| SC-EFFECT-TS-017 | Browser behavior still MUST ship through Effect TS + IIFE bundles per `.gemini/rules/effect-ts-only-js.md` | CRITICAL |
| SC-EFFECT-TS-018 | Do not introduce `fp-ts` in generated/agent-authored TypeScript; migrate touched fp-ts code to Effect | CRITICAL |
| SC-EFFECT-TS-019 | Generated TS data modules MUST expose Effect-compatible schemas/types when consumed by runtime logic | HIGH |
| SC-EFFECT-TS-020 | Effect ecosystem package choice MUST match runtime: core `effect` first, then `@effect/platform`, `@effect/rpc`, `@effect/sql`, `@effect/opentelemetry`, or `@effect/ai` only when needed | MEDIUM |

## Authoring Rules

- Prefer `import { Effect, Option, Schema, pipe } from "effect"` for core modules.
- Prefer `Effect.gen(function* () { ... })` for multi-step workflows where failures short-circuit.
- Return `Effect.Effect<A, E, R>` from internal APIs; provide legacy `Promise` wrappers only at compatibility boundaries.
- Model domain failures as tagged classes or tagged objects; never throw raw strings.
- Decode untrusted data at module boundaries, not deep inside business logic.
- For browser bundles, keep selectors in typed constants and build through the IIFE path.
- For package additions, use `effect` before adding narrower ecosystem packages. Add `@effect/*` only when the package owns a concrete boundary such as HTTP, RPC, SQL, OTel, AI, CLI, or runtime platform.

## Anti-Patterns

| Anti-pattern | Replacement |
|--------------|-------------|
| `async function internal() { ... }` with `try/catch` | `const internal = Effect.gen(...)` or `Effect.tryPromise(...)` |
| `value ?? null` / `return null` for missing business data | `Option.fromNullable(value)` and `Option.match` |
| `throw new Error(...)` inside effectful code | `Effect.fail(new DomainError(...))` or `Effect.try({ try, catch })` |
| `.then(...).catch(...)` chains | `Effect.flatMap`, `Effect.map`, `Effect.catchAll` |
| `setTimeout` retry or polling loops | `Effect.retry(..., Schedule.exponential(...))` / `Effect.repeat` |
| Global mutable service clients | `Context.Tag` service + `Layer` implementation |
| Zod/io-ts/fp-ts for newly-authored contracts | `Schema` from `effect` |

## Verification

Use targeted checks before merging:

```bash
rg -n "from ['\"]fp-ts|fp-ts/" .
rg -n "new Promise|\\.then\\(|\\.catch\\(|setInterval\\(|setTimeout\\(" <changed-ts-paths>
rg -n "from ['\"]effect['\"]|from ['\"]@effect/" <changed-ts-paths>
```

Then run the package-specific compile/check command defined by the local `AGENTS.md`.

## Source References

- Effect website: https://effect.website/
- Effect documentation: https://effect.website/docs/
- Effect monorepo and package matrix: https://github.com/Effect-TS/effect
- API reference: https://effect-ts.github.io/effect/
- Effect RPC: https://effect-ts.github.io/effect/docs/rpc
- Effect Platform: https://effect-ts.github.io/effect/docs/platform
- Effect OpenTelemetry: https://effect-ts.github.io/effect/docs/opentelemetry
