# Session Toolcall & Path Failure Analysis — 2026-04-20

## Scope
Analyze this session’s tool calls and path lookups, identify failures and bottlenecks, harden lookup-free runtime behavior, and optimize for token/time efficiency with Pi integration.

## 1) Toolcall inventory (major)
- `sa-plan add/update/status/sync/ingest-docs/send-email/list-prefs/knowledge-search`
- `bash` orchestration: server lifecycle, diagnostics (`ss`, `ps`, `curl`), file copies
- scripts executed:
  - `sub-projects/c3i/scripts/fractal_feature_evolution_suite.sh`
  - `sub-projects/c3i/scripts/recursive_feature_convergence.sh`
  - `sub-projects/c3i/scripts/update_task_link_registry.sh`
  - `sub-projects/c3i/scripts/visual_verify_task.mjs`
- media tools: `playwright`, `ffmpeg`, `dot`

## 2) Lookup/path problems observed

### P1 — Root path ambiguity (`/home/an/dev/ver/c3i` vs `sub-projects/c3i`)
Symptoms:
- wrong LOG_DIR path (`sub-projects/sub-projects/c3i/...`)
- artifacts generated in one root, served from another root
Impact:
- false “not found”, visual verifier showing missing content

### P2 — Server runtime CWD mismatch
Symptoms:
- `sa-plan serve` launched from different directories served different `docs/journal`
- same task-id page showed different templates and task counts
Impact:
- task-link resolution inconsistent; convergence false negatives

### P3 — Ingestion from non-canonical roots
Symptoms:
- ingest-docs warnings for missing dirs depending on CWD
Impact:
- unnecessary scans and latency, partial indexing expectations

### P4 — Visual verifier static assumptions
Symptoms:
- checked workspace docs while runtime server served sub-project docs
- convergence failed despite valid artifacts
Impact:
- redundant reruns, longer OODA cycle

### P5 — Link registry stale/overbroad
Symptoms:
- registry initially included huge unrelated set; not task-focused
Impact:
- noisy lookup and weak “fast availability”

## 3) Hardening performed (no-search / no-lookup runtime)

### H1 — Runtime journal dir resolution from active server process
- `update_task_link_registry.sh` now reads active PID (`sa-plan-daemon serve --port 4200`) and `/proc/<pid>/cwd`
- determines authoritative `docs/journal` from actual runtime context

### H2 — Multi-root mirroring
- registry output mirrored to all detected journal roots to avoid path misses

### H3 — Signature cache for link registry
- introduced `docs/cache/task-<id>-links.sig`
- skips regeneration when source signature unchanged (fast path)

### H4 — Visual verifier runtime alignment
- `visual_verify_task.mjs` now resolves runtime journal root from active serve process
- deduplicates URLs
- writes cache copy: `docs/cache/visual-checklist-<task>.json`

### H5 — Suite metrics cache
- `fractal_feature_evolution_suite.sh` now logs per-step duration and status to:
  - `sub-projects/c3i/docs/cache/suite-metrics-<task>.json`

### H6 — Convergence iteration metrics
- `recursive_feature_convergence.sh` now writes:
  - `sub-projects/c3i/docs/cache/convergence-<task>-iter-<n>.json`

## 4) Functional bottlenecks and improvements

### B1 — `pi_build` (high latency)
- dominant step due to multi-package TS build chain
Improvement:
- keep current full build for release certainty
- add future `--fast` mode: changed-package only + periodic full build

### B2 — `ingest-docs` (long scan)
- broad repository walk, repeated dedup checks
Improvement:
- incremental ingest mode by mtime/hash cache (future)
- current sig cache on registry already reduces part of overhead

### B3 — repeated server restarts/manual sync
Improvement:
- canonicalize one runtime: release `serve --port 4200` from workspace root
- avoid mixed debug/release and mixed CWD

### B4 — convergence false negatives
Improvement:
- runtime-root-aware verifier + richer structure heuristics

## 5) Pi-specific optimization notes
- keep `pi_build` and `pi_integration` gate mandatory
- caching files now provide fast state recall for repeated Pi evolution loops
- reduce token churn by referencing cached JSON summaries instead of re-printing full logs

## 6) Token utilization strategy (target <=50% window)
- Emit compact deltas only:
  - from `suite-metrics-<task>.json`
  - from `convergence-<task>-iter-*.json`
  - from `visual-checklist-<task>.json`
- avoid replaying full tool logs unless failure occurs
- prioritize summary objects and links over raw traces

## 7) Actionable workflow (optimized)
1. Launch canonical serve once (release, cwd=/home/an/dev/ver/c3i, port 4200)
2. `fractal_feature_evolution_suite.sh <task>`
3. `recursive_feature_convergence.sh <task> 2`
4. `update_task_link_registry.sh <task>` (fast if unchanged via signature cache)
5. consume only cache summaries for reporting
6. send email with tailscale links and attached artifacts

## 8) Key files updated in this hardening pass
- `sub-projects/c3i/scripts/update_task_link_registry.sh`
- `sub-projects/c3i/scripts/visual_verify_task.mjs`
- `sub-projects/c3i/scripts/fractal_feature_evolution_suite.sh`
- `sub-projects/c3i/scripts/recursive_feature_convergence.sh`

## 9) Recommended next evolution
- Add `sa-plan` subcommand: `feature-autopilot --task <id> --fast` to unify scripts and reduce shell overhead.
- Add Smriti cache table for path/runtime resolution and last-good artifact index.
- Add one-shot “runtime fingerprint” endpoint to eliminate PID introspection.
