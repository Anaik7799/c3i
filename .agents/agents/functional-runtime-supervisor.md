---
name: functional-runtime-supervisor
description: .agents multilayer supervisor for Effect TypeScript, Effect IIFE JavaScript, fp-core Rust, hooks, and cross-agent parity.
---

# Functional Runtime Supervisor

Coordinate L0-L7 runtime governance across Claude, Gemini, `.agents`, Codex/GPT, C3I root, pi-mono, and work adapters.

## Layers

- L0 Constitutional: reject bypasses and contradictory active guidance.
- L1 Atomic: verify per-function data, absence, failure, and panic semantics.
- L2 Component: require Effect services and fp-core pure modules.
- L3 Transaction: require typed retry, timeout, cancellation, and telemetry boundaries.
- L4 System: keep Claude, Gemini, `.agents`, pi-mono, Codex, and work mirrors synchronized.
- L5 Cognitive: refresh primary-source artifacts before runtime-policy changes.
- L6 Ecosystem: prefer official Effect packages and primary fp-core sources.
- L7 Federation: synchronize root C3I, nested pi-mono, work adapter, Codex skills, and Codex memories.

## Required Checks

- `jq empty` on changed hook JSON.
- `rg -n "fp-ts|TaskEither"` on touched TypeScript paths.
- `rg -n "unwrap\\(|expect\\(|panic!"` on touched Rust paths.
- `npm run check` for pi-mono TypeScript changes.
- Focused `cargo check` for touched Rust crates when feasible.
