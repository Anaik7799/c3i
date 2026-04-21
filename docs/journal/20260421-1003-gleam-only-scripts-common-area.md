# https://vm-1.tail55d152.ts.net:8443/task-id/1a92520c

# SC-SCRIPT-GLEAM-001 — Common Scripts Area + Clean Outputs (detailed pass)

**UTC:** 2026-04-21 10:03
**Context:** hard rule reinforcement adding common-area + clean-organization requirements.

---

## 1. Canonical script area (single common home)

```
lib/cepaf_gleam/src/scripts/
  README.md                # conventions doc (tracked)
  common/                  # shared helpers (not runnable)
    args.gleam             # minimal typed arg parser
    paths.gleam            # repo + output path resolution
    logx.gleam             # UTC stamp + structured log lines
    fsx.gleam              # simplifile-backed filesystem (Result semantics)
    httpx.gleam            # HTTP probe wrapper
  probe/    build/    ingest/   registry/
  verify/   fractal/  tls/      pi/       drift/
```

All runnable scripts live in a category subdir and expose `pub fn main() -> Nil`.

## 2. Clean output tree (single artifact home)

```
data/script-output/
  .gitignore               # tracked: ignore run dirs
  _index/README.md         # tracked: conventions
  _index/migration.md      # tracked: legacy → gleam migration table
  <category>/<name>/<stamp>/
    stdout.log
    result.json
    artifacts/
```

Outputs are runtime artifacts, not tracked per-run; only `_index/` and the
`.gitignore` are committed.

## 3. Working example (proven live)

- Module: `lib/cepaf_gleam/src/scripts/probe/public_interface.gleam`
- Invocation: `gleam run -m scripts/probe/public_interface`
- Result: **10/10 pass** on `http://vm-1.tail55d152.ts.net:4200`
- Outputs persisted at `data/script-output/probe/public_interface/20260421-100301/{stdout.log, result.json, artifacts/}`
- Example `result.json` shape:
  ```json
  {
    "base": "http://vm-1.tail55d152.ts.net:4200",
    "stamp": "20260421-100301",
    "passed": 10,
    "total": 10,
    "results": [{"name":"health.root","ok":true,"code":200,"detail":"..."} , ...]
  }
  ```

## 4. Migration index published

`data/script-output/_index/migration.md` — authoritative table mapping every
legacy `.sh` / `.py` / `.mjs` to its target gleam module + status
(`PENDING` | `DONE` | `ARCHIVED`). Currently one `DONE` entry:

| Legacy | Gleam module | Status |
|---|---|---|
| `scripts/public_interface_test_suite.sh` (HTTP subset) | `scripts/probe/public_interface` | DONE |

20 other scripts listed as `PENDING` with explicit target module names.

## 5. Rule updates

- `.claude/rules/gleam-only-scripting-mandate.md` and `.gemini/...` mirror
  updated to:
  - name the canonical tree,
  - declare the contract (main + args + paths + fsx + logx panic-on-fail),
  - pin the output-tree layout,
  - reference the migration index.

## 6. Gleam deps added (this pass)

- `argv` 1.0.2 — argument access
- `gleam_httpc` 5.0.0 — HTTP client
- `simplifile` ≥ 2.4.0 — clean filesystem Result semantics

## 7. Forbidden outside the common area

- No `.sh` / `.py` / `.mjs` with logic anywhere.
- No outputs under `/tmp`, repo root, or arbitrary `docs/` paths.
- No `bash -c '<logic>'`, `python3 -c '<logic>'`, `node -e '<logic>'`.

## 8. Mainline stability

All pre-existing services remain up:
- HTTP :4200 → 200
- HTTPS :8443 → 200
- task-id pages reachable
- No runtime behaviour regressed by the rule.

## 9. Next actions (Fractal TPS one-piece flow)

1. Provision `gleam` on daemon PATH (fixes 55+ legacy cron discards).
2. Migrate the hot sub-project scripts (`public_interface_test_suite.sh` full parity,
   `update_task_link_registry.sh`, `generate_fractal_criticality_matrix.sh`,
   `fractal_feature_evolution_suite.sh`, `recursive_feature_convergence.sh`,
   `pi_skills_phase_orchestrator.sh`).
3. Switch Rust worker `run_link_registry_refresh` to `gleam run -m scripts/registry/task_link_registry`.
4. Add CI guard rejecting new `.sh/.py/.mjs` in `scripts/` trees.
5. Archive legacy files when their gleam replacement hits `DONE` status in migration.md.
