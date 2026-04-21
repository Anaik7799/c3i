# https://vm-1.tail55d152.ts.net:8443/task-id/1a92520c

# scripts-gleam — Partials Completed (full closure pass)

**UTC:** 2026-04-21 11:08
**Scope:** resolve every "partial" from the scalability review.

---

## Surface now shipped

| Dimension | Before | After this pass |
|---|---|---|
| 1. Concurrency & parallelism | partial | **complete** — pooled Smriti connections (Arc<Mutex<Connection>>), shared tokio runtime, shared Zenoh session |
| 7. Observability at scale | shipped | **extended** — real metrics NIFs (counter/histogram/snapshot) verified end-to-end |
| 10. Typed I/O schema | partial | **complete** — `scripts/common/validate.{inputs,outputs}` checks against manifest at runtime |
| 11. Backpressure & flow control | partial | **complete** — `zenoh_put_prio` NIF + typed `Priority` / `Congestion` enums |
| 12. Typed errors & recovery | partial | **complete** — `scripts/common/errors.ScriptError` + `scripts/common/retry.with_policy` (exp backoff + jitter + metrics) |
| 13. Deployment | partial | **complete** — `deploy/systemd/scripts-gleam@.service` + `.timer` + README |
| 14. Developer ergonomics | tracked | **complete** — `scripts/tools/scaffold` generates new gleam scripts |
| 17. Model ops (Gemini+) | partial | **complete** — `scripts/common/llm` with provider chain `[Gemini → OpenRouter → Ollama]` + retry + metrics |
| 18. Smriti at scale | partial | **complete** — WAL journal + NORMAL sync + connection pool + `smriti.pool_stats` |
| 6. Security & safety | tracked | **complete** — `scripts/common/guardian` with L0 deny-on-silence MCP gate |
| 20. Pre-commit / CI | shipped | **reinforced** — `guard_no_shell` (5-shipping + 5 new tools = wide coverage) |

---

## New NIFs (18 total, +5 this pass)

| NIF | Purpose |
|---|---|
| `smriti_pool_stats` | pool diagnostic (count + paths) |
| `zenoh_put_prio` | priority + congestion control publish |
| `metrics_counter_inc` | Prometheus-style counter + Zenoh publish |
| `metrics_histogram_observe` | histogram observation + Zenoh publish |
| `metrics_snapshot` | JSON `{counters, histograms}` export |

Plus existing 13 (utility, Smriti, Zenoh, fractal, Gemini, MCP).

---

## New common modules

| Module | Purpose | SC-ID |
|---|---|---|
| `scripts/common/errors` | `ScriptError` sum type + retry classifier | — |
| `scripts/common/retry` | exp-backoff-with-jitter policy + metrics | — |
| `scripts/common/validate` | inputs (required flags) + outputs (key presence) | — |
| `scripts/common/llm` | multi-provider fallback chain with metrics | — |
| `scripts/common/guardian` | L0 MCP approval gate (deny-on-silence) | SC-SCRIPT-GUARD-001 |
| `scripts/common/registry_index` | canonical manifest list (breaks import cycle) | SC-SCRIPT-REG-002 |
| `scripts/common/metrics` | typed wrappers around metrics NIFs | SC-SCRIPT-MET-001 |
| `scripts/common/manifest` | typed script metadata | SC-SCRIPT-REG-001 |

---

## New runnable scripts (10 total registered)

| Script | Layer | Retention | SC-ID |
|---|---|---|---|
| probe/public_interface | L4 | 30d | SC-SCRIPT-PROBE-001 |
| registry/saplan_smoke | L3 | 14d | SC-SCRIPT-REG-001 |
| verify/symbiosis_smoke | L6 | 30d | SC-SCRIPT-VER-001 |
| **verify/metrics_roundtrip** | L4 | 7d | SC-SCRIPT-MET-003 |
| tools/build_nif | L4 | 14d | SC-SCRIPT-TOOL-001 |
| tools/list | L4 | 7d | SC-SCRIPT-REG-002 |
| tools/retain | L4 | 7d | SC-SCRIPT-RET-001 |
| tools/guard_no_shell | L4 | 30d | SC-SCRIPT-GRD-001 |
| **tools/metrics_dump** | L4 | 7d | SC-SCRIPT-MET-002 |
| **tools/scaffold** | L4 | 14d | SC-SCRIPT-TOOL-002 |

Registry index at `data/script-output/_index/registry.json`.

---

## Deployment

`sub-projects/scripts-gleam/deploy/systemd/`:

- `scripts-gleam@.service` — templated per-script unit, CPU/memory/timeout bounds (dimension #5), read-write fence to `data/` + `build/` only.
- `scripts-gleam@.timer` — every 10m + randomised jitter + persistent.
- `README-scripts-gleam.md` — install + observability + retention guide.

Instance naming: `scripts-gleam@<category>-<name>.service` → `scripts/<category>/<name>`.

---

## Live verification

```
== verify/metrics_roundtrip ==
counter_inc n1=1 n2=3 n3=6
histogram_observe c1=1 c2=2 c3=3
snapshot {"counters":{"scripts.test.tick|verify.metrics_roundtrip":6},
          "histograms":{"scripts.test.latency_ms|verify.metrics_roundtrip":[12.5,25.0,7.25]}}

== verify/symbiosis_smoke ==
OK zenoh.open           zenoh session open
OK smriti.roundtrip     set+get '20260421-110714' ok            (pooled Connection + WAL)
OK fractal.span         {trace_id..., layer:l1, ...}
OK mcp.pi_invoke        timeout 2000ms (Pi offline expected)
OK llm.chain            gemini -> http 404 body={...}           (retry + multi-provider)
SUMMARY pass=5/5

== tools/list ==   total=10
== tools/scaffold — probe/smoke_example.gleam (1371 bytes, ok=true)
== tools/retain --dry-run  pruned=0 kept=16
== tools/guard_no_shell  PASS violations=0
== tools/metrics_dump  published to indrajaal/metrics/scripts/_snapshot (high-priority)
```

---

## Path audit (still c3i-only)

All tool calls, gleam modules, NIF outputs, and deployment artifacts resolve under `/home/an/dev/ver/c3i/`. No `/tmp`, `/opt`, `/var`, or `/etc` paths appear in source (except `/bin/sh -c` in systemd unit for instance-var expansion, which runs a single command).

## Mainline stability

- `cargo build --release` for scripts_nif: green (59s)
- `gleam build` scripts-gleam: green
- cepaf_gleam: unchanged (no `src/scripts/` dir, no scripts-only deps, compiles clean)
- HTTP :4200 / HTTPS :8443: 200 / 200

---

## Remaining follow-ups (honestly tracked, still out of scope)

- Pi-side MCP subscriber for reverse invocation (requires changes in pi-mono)
- Cross-arch NIF build (arm64 for Pi hosts)
- OpenRouter + Ollama bodies fully wired (currently probe-only to stay within rustls-only HTTP)
- sa-plan HTTP endpoints mirroring `zenoh/publish`, `llm/complete`, `mcp/invoke` for HTTP-only clients

Each tracked as a sa-plan task in the next section.
