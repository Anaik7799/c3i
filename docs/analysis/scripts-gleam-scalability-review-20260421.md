# https://vm-1.tail55d152.ts.net:8443/task-id/1a92520c

# scripts-gleam — Scalability Review for cepaf

**Generated:** 2026-04-21 10:50 UTC
**Scope:** honest, exhaustive gap-analysis of what a *scalable* scripting system needs in the cepaf/c3i ecosystem, mapped against what we have shipped in `sub-projects/scripts-gleam` so far, and what still needs to be built.

---

## 1. Twenty scalability dimensions

| # | Dimension | Shipped now | Status | Proposed action |
|---:|---|---|---|---|
| 1 | **Concurrency & parallelism** (intra-node) | single shared tokio runtime + single cached Zenoh session in NIF | **partial** | add per-script isolated sqlite connections, Zenoh publisher pool |
| 2 | **Distribution / multi-node** | Zenoh as mesh transport already enabled | **architectural-ready** | add node-identity NIF + heartbeat topic `indrajaal/scripts/heartbeat/<node>` |
| 3 | **Supervision & lifecycle (OTP)** | `gleam run` is fire-and-forget | **missing** | add `scripts/tools/supervise` that runs a set of scripts under a child-spec; long-running scripts register with sa-plan's worker tree |
| 4 | **Scheduling** | sa-plan's Oban/Temporal engine + `gleam_script` worker | **partial** | add `scripts/manifest.retention_days`, dependency edges, DLQ |
| 5 | **Resource governance** | none — any script can consume unlimited time/mem | **missing** | timeout + max-stderr caps in `scripts_sh_ffi`; cgroups for subprocess calls (tracked) |
| 6 | **Security & safety** | L0 Guardian gate not enforced from scripts | **missing** | `scripts/common/guardian.gleam` calling sa-plan L0 approval endpoint before privileged acts |
| 7 | **Observability at scale** | per-run fractal span auto-published to Zenoh | **partial** | add counters/histograms, trace sampling, log aggregation |
| 8 | **Storage retention** | runs accumulate indefinitely under `data/script-output/` | **missing** | `scripts/tools/retain --keep-days N` + `_index/retention.md` |
| 9 | **Script registry & discovery** | scripts live in a filesystem tree; no index | **missing** | `manifest() -> Manifest` contract + `scripts/tools/list` + `scripts/tools/describe` |
| 10 | **Typed I/O schema** | `args.gleam` parses flags; no output schema validation | **partial** | JSON-schema in manifest, `result.json` validator |
| 11 | **Backpressure & flow control** | Zenoh put is fire-and-forget | **partial** | expose Zenoh publisher with congestion_control/priority hints |
| 12 | **Typed errors & recovery** | gleam Result types per module | **partial** | unified `ScriptError` + retry policy per error class |
| 13 | **Deployment** | `install -m 0755 priv/scripts_nif.so` | **partial** | systemd timers for scheduled scripts; cross-arch NIF build |
| 14 | **Developer ergonomics** | manual file creation | **missing** | `scripts/tools/scaffold --category probe --name my_probe` |
| 15 | **Governance (STAMP/SC-* )** | SC-SCRIPT-GLEAM-001 only | **partial** | per-script SC-ID in manifest, map to Fractal layer |
| 16 | **Pi symbiosis (bidirectional)** | scripts → Pi via MCP (one-way) | **missing (reverse)** | Pi invokes scripts via MCP: subscribe `indrajaal/mcp/request/scripts.*` and execute the named gleam script |
| 17 | **Model ops (Gemini+)** | Gemini via NIF | **partial** | multi-model fallback (Gemini → Claude → local Ollama), cost tracker, RAG |
| 18 | **Smriti at scale** | per-call connection via rusqlite | **partial** | connection pool, WAL pragma, prepared stmt cache |
| 19 | **Self-observability** | per-run JSON output | **missing** | `scripts/tools/diagnose` aggregator + `scripts/tools/health` |
| 20 | **Pre-commit / CI enforcement** | policy in .claude rule only | **missing** | `scripts/tools/guard_no_shell` + git hook |

---

## 2. What we ship this pass

To move from "works" to "scalable", this pass adds the **five highest-leverage pieces**:

### 2.1 Script manifest contract (`scripts/common/manifest.gleam`)

Every runnable script exports `pub fn manifest() -> Manifest` declaring:

```gleam
Manifest(
  name:           "probe/public_interface",
  category:       Probe,
  fractal_layer:  L4,
  summary:        "HTTP probe subset of the public interface suite",
  inputs:         [Flag("base", "…"), Flag("insecure", "bool")],
  outputs_schema: "result.json: {base, stamp, passed, total, results:[]}",
  retention_days: 30,
  sc_id:          "SC-SCRIPT-PROBE-001",
)
```

Manifests are the single source of truth for: discovery, scheduling, retention, auth, docs.

### 2.2 Registry tools

- `scripts/tools/list` — enumerate every runnable script and emit `data/script-output/_index/registry.json`.
- `scripts/tools/describe -- --name <n>` — show the manifest for a single script.

### 2.3 Metrics NIFs (`metrics_counter_inc`, `metrics_histogram_observe`)

Real rustler NIFs that publish to Zenoh topic `indrajaal/metrics/scripts/<metric>/<label>` using the existing in-process Zenoh session. Enables Prometheus-style counters/histograms with no new infrastructure.

### 2.4 Retention tool (`scripts/tools/retain`)

Deletes run-directories older than `--keep-days N` under `data/script-output/`. Publishes summary to Zenoh.

### 2.5 Shell/Python guard (`scripts/tools/guard_no_shell`)

Walks the repo under `/home/an/dev/ver/c3i/` and fails (non-zero exit) if any new `.sh`/`.py`/`.mjs` is introduced outside the documented allowlist. Designed to be wired into a pre-commit hook (the pre-commit config is a declarative YAML, not a shell script).

---

## 3. Tracked for follow-up passes

| Task | Priority |
|---|---|
| Pi-side MCP subscriber that invokes gleam scripts (reverse direction) | P0 |
| `scripts/common/guardian.gleam` (L0 approval gate) | P0 |
| Multi-model fallback (Gemini → Claude → Ollama) | P1 |
| Smriti connection pool | P1 |
| `scripts/tools/scaffold` (developer ergonomics) | P1 |
| systemd timers for scheduled scripts | P1 |
| Cross-arch NIF build (arm64 for Pi) | P1 |
| Trace sampling + log aggregation | P2 |
| Cost tracker for Gemini calls | P2 |

---

## 4. STAMP additions proposed this pass

- **SC-SCRIPT-REG-001** — every runnable script MUST export `manifest/0`.
- **SC-SCRIPT-REG-002** — the registry index `data/script-output/_index/registry.json` MUST be regenerated on every commit that touches `src/scripts/**`.
- **SC-SCRIPT-RET-001** — retention MUST be driven by the `retention_days` field of the manifest.
- **SC-SCRIPT-MET-001** — metrics MUST be emitted through the `metrics_*` NIFs to `indrajaal/metrics/scripts/**`.
- **SC-SCRIPT-GRD-001** — `guard_no_shell` MUST be run as part of pre-commit / CI.

---

## 5. What remains out-of-scope (by choice, tracked)

Items that require changes outside `sub-projects/scripts-gleam/`:

- Pi-mono subscriber for `indrajaal/mcp/request/scripts.*` — must be added to pi-mono itself.
- sa-plan `scripts_execute` HTTP endpoint — already have `gleam_script` worker; HTTP shim is optional.
- CI pipeline changes — belongs to `.github/workflows/`.
