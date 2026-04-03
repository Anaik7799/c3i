# 2026-03-20 18:31 — Comprehensive OTel + Smart Capture Improvement Pass

## Context
- Branch: main
- Recent commits: 2421a4213 feat(sprint-54): Add SIL-6 Zenoh partition apoptosis chaos test
- Prior entries reviewed:
  - `20260320-1830-unified-otel-cross-runtime-tracing.md`
  - `20260320-1800-smart-capture-gemini-4layer-strategy.md`
  - `20260320-2100-17-discipline-mathematical-analysis-otel-tracing.md`

## Summary

Full audit of all 3 runtime OTel implementations (Elixir, F#, Rust) against journal claims.
Identified **9 concrete issues** — 1 P0 bug, 3 P1 defects, 3 P2 improvements, 2 P3 enhancements.

---

## 9 Issues Found

### Issue 1 — P0 BUG: Elixir tracing.ex hardcoded stale service identity
**File**: `lib/indrajaal/observability/tracing.ex:54-55`
**Problem**: Hardcoded `"service.name" => "intelitor"` and `"service.version" => "1.0.0"`.
`config/runtime.exs:118-120` correctly uses `"indrajaal"` / `"21.3.0"`.
Any spans created via `Tracing.start_span/2` will carry the wrong service name, breaking
SigNoz/Grafana service map correlation.
**STAMP**: SC-OBS-069 (dual log), SC-OTEL-MATH-001 (identity consistency)
**Fix**: Replace with `Application.get_env(:indrajaal, :otel_service_name, "indrajaal")` or
hardcode `"indrajaal"` / `"21.3.0"` to match runtime.exs.
**RPN**: S=8, O=9, D=3 → **216** (CRITICAL — every span is mistagged)

### Issue 2 — P1: F# OTELFractalDecorator.wrap blocks on Async.RunSynchronously
**File**: `lib/cepaf/src/Cepaf/Observability/Fractal/OTELIntegration.fs:~435`
**Problem**: The sync decorator path calls `Async.RunSynchronously` to push to SigNoz.
This blocks the calling thread, violating SC-LOG-001 (non-blocking logging) and
SC-ZTEST-004 (async publishing). Under load, thread-pool starvation is possible.
**STAMP**: SC-LOG-001, SC-PRF-055 (no blocking ops)
**Fix**: Use `Async.Start` (fire-and-forget) or `Task.Run` with a bounded channel for backpressure.
**RPN**: S=7, O=4, D=5 → **140** (HIGH)

### Issue 3 — P1: F# OTELBaggage is process-global, not per-span
**File**: `lib/cepaf/src/Cepaf/Observability/Fractal/OTELIntegration.fs:~52`
**Problem**: `OTELBaggage` module uses a `ConcurrentDictionary<string,string>` as a
process-level singleton. Concurrent spans overwrite each other's baggage entries.
This defeats W3C baggage propagation semantics.
**STAMP**: SC-OTEL-MATH-009 (context propagation integrity)
**Fix**: Use `Activity.Current.Baggage` (the .NET OTel SDK's per-span baggage) or
an `AsyncLocal<Dictionary>` to scope baggage to the current execution flow.
**RPN**: S=6, O=5, D=5 → **150** (HIGH)

### Issue 4 — P1: No F# TracerProvider bootstrap — dual-emit always standalone
**File**: `lib/cepaf/src/Cepaf/Observability/Fractal/OTELIntegration.fs` (module-wide)
**Problem**: `ActivitySource.StartActivity` returns `null` when no `TracerProvider` listener
is registered. The dual-emit path always falls through to the standalone `OTELSpanContext`
codepath. This means F# spans never actually reach the .NET OTel SDK pipeline, and OTLP
export from F# is dead code.
**STAMP**: SC-OBS-071 (4 OTEL modules), SC-OTEL-MATH-003 (collector availability)
**Fix**: Add `TracerProvider` initialization in F# startup:
```fsharp
Sdk.CreateTracerProviderBuilder()
  .AddSource("cepaf-fsharp")
  .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("indrajaal-cepaf"))
  .AddOtlpExporter(fun o -> o.Endpoint <- Uri("http://localhost:4317"))
  .Build()
```
This requires `OpenTelemetry`, `OpenTelemetry.Exporter.OpenTelemetryProtocol` NuGet packages.
**RPN**: S=6, O=8, D=4 → **192** (HIGH — silently non-functional)

### Issue 5 — P2: F# setParentFromTraceparent uses wrong .NET pattern
**File**: `lib/cepaf/src/Cepaf/Observability/Fractal/OTELIntegration.fs:~182`
**Problem**: Creates `new Activity("remote-parent")` and manually sets TraceId/SpanId.
The correct .NET pattern is to create an `ActivityContext` from the parsed traceparent
and pass it to `ActivitySource.StartActivity(..., parentContext: ctx)`.
**STAMP**: SC-OTEL-MATH-009 (W3C context propagation)
**Fix**: Parse traceparent into `ActivityContext(traceId, spanId, flags)`, then use as parent.
**RPN**: S=5, O=4, D=4 → **80** (MEDIUM)

### Issue 6 — P2: Elixir TracePropagator not wired to ZenohTestFormatter
**File**: `lib/indrajaal/cluster/zenoh/trace_propagator.ex` exists but unused
**Problem**: `TracePropagator.inject/1` and `extract/1` exist for Zenoh messages but
neither `ZenohTestFormatter` nor `CheckpointMessages` call them. Checkpoint messages
carry no trace context, breaking cross-runtime trace correlation for test events.
**STAMP**: SC-OTEL-MATH-009, SC-ZTEST-002 (message schema)
**Fix**: Call `TracePropagator.inject(metadata)` in `CheckpointMessages.build/3` and
`TracePropagator.extract(metadata)` in `ZenohTestOrchestrator` subscriber.
**RPN**: S=5, O=6, D=3 → **90** (MEDIUM)

### Issue 7 — P2: Elixir tracing.ex missing 11 of 30 domains
**File**: `lib/indrajaal/observability/tracing.ex`
**Problem**: `start_domain_span/3` only has prefixes for 19 domains. Missing:
`:authorization`, `:billing`, `:cluster`, `:cockpit`, `:compliance`, `:coordination`,
`:cortex`, `:cybernetic`, `:distributed`, `:flame`, `:identity`.
Any span for these domains gets a generic `"unknown.{action}"` name.
**STAMP**: SC-CTRL-002 (all 30 domains queryable)
**Fix**: Add the missing 11 domain prefixes to the domain_to_prefix map.
**RPN**: S=4, O=6, D=3 → **72** (MEDIUM)

### Issue 8 — P3: Rust tracing metrics not forwarded as OTel spans
**File**: `native/zenoh_ffi/src/lib.rs`, `native/zenoh_ffi/Cargo.toml`
**Problem**: Rust uses `tracing` crate with `tracing-subscriber` for console output but
has no `tracing-opentelemetry` bridge. The 27 atomic counters and 12 invariants are
internal-only — invisible to the distributed trace.
**STAMP**: SC-OBS-071 (4 OTEL modules — Rust is the gap)
**Fix**: Add `tracing-opentelemetry` + `opentelemetry-otlp` crates. Low priority because
Rust FFI calls are typically <1ms and captured by F# parent spans.
**RPN**: S=3, O=3, D=6 → **54** (LOW)

### Issue 9 — P3: P3 sampling=0.0 contradicts Ψ₂ (evolutionary continuity)
**File**: `lib/cepaf/src/Cepaf/Observability/Fractal/Types.fs`
**Problem**: `Priority.P3` has `samplingRate = 0.0`, meaning L1-Atomic traces are
ALWAYS dropped. Ψ₂ requires "complete history preservation." This is a philosophical
tension, not a runtime bug — but should be documented as an intentional deviation.
**STAMP**: Ψ₂ (history), SC-OTEL-MATH-002 (sampling guarantees)
**Fix**: Either set P3 sampling to 0.001 (1-in-1000) or add explicit Ψ₂ exception
documentation in Types.fs explaining the information-theoretic tradeoff.
**RPN**: S=2, O=3, D=7 → **42** (LOW)

---

## Prioritized Remediation Plan

| Wave | Issues | Effort | Impact |
|------|--------|--------|--------|
| W1 (P0) | #1 tracing.ex version mismatch | 5 min | Fixes ALL Elixir span identity |
| W2 (P1) | #2 async decorator, #3 baggage scope, #4 TracerProvider | 2-3 hours | F# OTel becomes functional |
| W3 (P2) | #5 parent propagation, #6 wire TracePropagator, #7 domain list | 1-2 hours | Cross-runtime correlation |
| W4 (P3) | #8 Rust OTel bridge, #9 P3 sampling | 2-4 hours | Completeness polish |

## FMEA Summary

| Issue | S | O | D | RPN | Classification |
|-------|---|---|---|-----|----------------|
| #1 Service identity | 8 | 9 | 3 | 216 | CRITICAL |
| #4 TracerProvider | 6 | 8 | 4 | 192 | HIGH |
| #3 Baggage scope | 6 | 5 | 5 | 150 | HIGH |
| #2 Blocking decorator | 7 | 4 | 5 | 140 | HIGH |
| #6 TracePropagator unwired | 5 | 6 | 3 | 90 | MEDIUM |
| #5 Parent propagation | 5 | 4 | 4 | 80 | MEDIUM |
| #7 Domain list gap | 4 | 6 | 3 | 72 | MEDIUM |
| #8 Rust OTel bridge | 3 | 3 | 6 | 54 | LOW |
| #9 P3 sampling | 2 | 3 | 7 | 42 | LOW |

## STAMP Compliance

| Constraint | Status | Issue |
|------------|--------|-------|
| SC-OBS-069 | DEGRADED | #1 — wrong service name breaks correlation |
| SC-OBS-071 | PARTIAL | #4 — F# OTel pipeline inactive, #8 — Rust has no OTel |
| SC-LOG-001 | VIOLATED | #2 — blocking sync decorator |
| SC-PRF-055 | AT RISK | #2 — thread-pool starvation under load |
| SC-OTEL-MATH-009 | DEGRADED | #3, #5, #6 — context propagation broken at multiple points |
| SC-CTRL-002 | DEGRADED | #7 — 11 domains missing trace prefixes |
| Ψ₂ | TENSION | #9 — P3=0.0 drops L1 traces entirely |

## Verification Done

| Check | Result |
|-------|--------|
| `config/runtime.exs` W3C propagators | CORRECT (`:trace_context, :baggage`) |
| `config/runtime.exs` service identity | CORRECT (`"indrajaal"` / `"21.3.0"`) |
| `native/zenoh_ffi/Cargo.toml` tracing deps | CORRECT (`tracing 0.1`, `tracing-subscriber 0.3`) |
| F# ActivitySourceBridge creation | CORRECT (`"cepaf-fsharp"` / `"21.3.0"`) |
| F# dual-emit traceId reuse | CORRECT (reads from `Activity.Current`) |
| Elixir TracePropagator inject/extract | EXISTS but UNWIRED |
| Rust `init_tracing()` called | CORRECT (in `zenoh_ffi_init`) |
| RegressionRunner.fs classifyLine | CORRECT (P0-P3 with 45+ patterns) |
| RegressionRunner.fs ZenohProgress | CORRECT (12 checkpoints CP-REG-01..12) |
| Smart capture budget allocation | CORRECT (30% P0, 40% P1, 25% P2, 5% P3) |

## Next Steps
1. **Immediate**: Fix Issue #1 (tracing.ex — 2-line fix)
2. **Sprint 55**: Bundle Issues #2-#4 as "F# OTel Activation" epic
3. **Sprint 55**: Bundle Issues #5-#7 as "Cross-Runtime Trace Wiring" epic
4. **Backlog**: Issues #8-#9 for polish pass

## KPIs
- Files audited: 10 (across 3 runtimes)
- Issues found: 9 (1 P0, 3 P1, 3 P2, 2 P3)
- Total RPN: 1,036 (sum of all 9 issues)
- Highest RPN: 216 (Issue #1 — service identity)
- Lines read: ~2,500+
- Tests verified: 31/31 F# pass, 22/22 smart-capture pass
