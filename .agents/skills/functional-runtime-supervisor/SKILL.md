---
name: functional-runtime-supervisor
description: Use to coordinate cross-agent enforcement of Effect TypeScript, Effect IIFE JavaScript, fp-core Rust, hooks, rules, skills, and Codex/GPT compatibility across C3I and pi-mono.
---

# Functional Runtime Supervisor

Apply the same L0-L7 gate used by `.claude/agents/functional-runtime-supervisor.md` and `.gemini/agents/functional-runtime-supervisor.md`.

## Procedure

1. Read the nearest `AGENTS.md`.
2. For TypeScript, read `effect-ts-universal.md` and require `effect` instead of `fp-ts`.
3. For browser/runtime JavaScript, read `effect-ts-only-js.md` and require Effect TypeScript plus IIFE output.
4. For Rust, read `fp-core-rust-universal.md` and require `fp-core = "0.1.9"` where applicable.
5. Check Claude/Gemini/Codex/Pi mirrors before finalizing governance changes.
6. Validate JSON hooks and run focused code checks for touched files.

## Hard Stops

- New generated `fp-ts` import.
- New raw `.js` runtime logic without generated-IIFE waiver.
- New runtime Rust `unwrap`, `expect`, or `panic!`.
- Untyped external data crossing without Effect `Schema` or Rust typed decoder/domain type.
