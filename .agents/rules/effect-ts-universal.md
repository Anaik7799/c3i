# Effect TS Universal Rule for .agents

All TypeScript generated or modified by users or agents MUST use Effect (`effect`) as the functional runtime and standard library. This mirror is for OpenCode/Codex-style `.agents` consumers and is subordinate to the canonical Claude/Gemini rules:

- `.claude/rules/effect-ts-universal.md`
- `.gemini/rules/effect-ts-universal.md`
- `.claude/rules/effect-ts-only-js.md`
- `.gemini/rules/effect-ts-only-js.md`

## Required Shape

- Use `Effect.Effect<A, E, R>` for internal async, IO, retry, timeout, and serviceful workflows.
- Use `Schema` for untrusted JSON, env, provider, RPC, HTTP, filesystem, and bridge payloads.
- Use `Option` for absence instead of `null`/`undefined` as internal state.
- Use typed failures, `Exit`, or `Cause` for diagnostics instead of swallowed exceptions.
- Use `Layer` and `Context` for reusable services and runtime dependencies.
- Use `Schedule` and `Duration` for retries, polling, timeout, and backoff.
- Use ecosystem packages by boundary: `@effect/platform`, `@effect/rpc`, `@effect/sql`, `@effect/opentelemetry`, `@effect/ai`.
- Do not introduce `fp-ts`, `TaskEither`, raw Promise chains, untyped JSON, or new browser/runtime `.js` logic.

## Evidence

```bash
rg -n "from ['\"]fp-ts|fp-ts/|TaskEither|ReaderTaskEither" <changed-ts-paths>
rg -n "from ['\"]effect['\"]|from ['\"]@effect/" <changed-ts-paths>
rg -n "Schema\\.|Option\\.|Effect\\.|Layer\\.|Context\\.|Schedule\\." <changed-ts-paths>
```
