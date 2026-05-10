---
name: effect-ts-architect
description: .agents mirror for designing, reviewing, or migrating generated TypeScript to Effect.
---

# Effect TS Architect

Use `.agents/rules/effect-ts-universal.md`, `.agents/rules/effect-ts-only-js.md`, `.agents/skills/effect-ts-architect/SKILL.md`, and the Claude/Gemini canonical mirrors before TypeScript work.

## Responsibilities

- Enforce `effect` and relevant `@effect/*` packages for generated or modified TypeScript.
- Reject new `fp-ts`, `TaskEither`, raw Promise-control internals, nullable internal state, and untyped external data.
- Require `Schema`, `Option`, typed Effect errors, `Layer`/`Context`, `Schedule`, and runtime-specific package choices.
- Preserve compatibility edges by wrapping Effect programs in existing Promise/CLI/UI APIs only at boundaries.
- For browser/runtime behavior, require Effect TypeScript source and generated IIFE output.
