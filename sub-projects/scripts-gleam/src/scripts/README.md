# scripts/ — Gleam-Only Scripts (SC-SCRIPT-GLEAM-001)

This is the **single canonical area** for all project scripts.  
**Hard rule:** nothing else in the repository may carry script logic — no `.sh`, `.py`, `.mjs`, no inline `bash -c '<logic>'`, `python3 -c '<logic>'`, `node -e '<logic>'`, and no logic-carrying heredocs.

All runnable scripts are Gleam modules in the isolated `scripts-gleam` subproject:

```
cd sub-projects/scripts-gleam
gleam run -m scripts/<category>/<name> -- [--arg value ...]
```

This subproject has no dependency on `lib/cepaf_gleam` or any other system
service; adding a script here cannot break the main application.

## Directory taxonomy

| Dir | Purpose |
|---|---|
| `common/` | shared helpers only (args, paths, httpx, logx, fsx). Never runnable on its own. |
| `probe/` | network/endpoint/health probes (replaces `public_interface_test_suite.sh`, etc.) |
| `build/` | build orchestration (replaces shell build wrappers) |
| `ingest/` | ZK/docs/journal ingestion |
| `registry/` | link + task-id registries (replaces `update_task_link_registry.sh`) |
| `verify/` | verification, convergence, fractal gates (replaces `recursive_feature_convergence.sh`, `fractal_feature_evolution_suite.sh`) |
| `fractal/` | criticality / RPN / FMEA matrix scripts (replaces `generate_fractal_criticality_matrix.sh`) |
| `tls/` | TLS lifecycle helpers (replaces `sa-plan-tls-setup.sh` logic; delegates to `sa-plan tls` binary) |
| `pi/` | Pi symbiosis orchestration (replaces `pi_skills_phase_orchestrator.sh`) |
| `drift/` | drift analysis / reconciliation automation |

## Contract for every runnable script

Each runnable module MUST:
1. Live at `src/scripts/<category>/<name>.gleam`.
2. Export `pub fn main() -> Nil`.
3. Read args via `scripts/common/args`.
4. Resolve paths via `scripts/common/paths`.
5. Write outputs under `<repo>/data/script-output/<category>/<name>/<iso-timestamp>/` using `scripts/common/fsx` helpers.
6. Emit structured log lines via `scripts/common/logx`.
7. Exit with non-zero (panic) on failure, `Nil` return on success.

## Output root layout

Generated artifacts are clean and isolated:

```
data/script-output/
  _index/                             # cross-script index (auto-generated)
  <category>/
    <name>/
      <YYYYMMDD-HHMMSS>/              # one directory per invocation
        stdout.log
        stderr.log
        result.json                   # machine-readable structured result
        artifacts/                    # any files the script produces
```

No script writes outside `data/script-output/` or the explicit `--output` path.

## Forbidden

- New `.sh` / `.py` / `.mjs` files anywhere.
- Shelling out to `bash -c '<logic>'`, `python3 -c '<logic>'`, `node -e '<logic>'`.
- Scripts that live outside `lib/cepaf_gleam/src/scripts/`.
- Outputs scattered across `/tmp`, `/var/tmp`, repo root, or random `docs/` paths.

## Allowed

- Thin binary invocation from gleam scripts: `./sa-plan ...`, `cargo ...`, `git ...`, `curl ...`, `gleam run ...`.
- Systemd `ExecStart` that launches one binary with fixed arguments.

## Registered gleam-run scripts (current)

| Category | Name | Invocation | Replaces |
|---|---|---|---|
| probe | public_interface | `gleam run -m scripts/probe/public_interface` | subset of `scripts/public_interface_test_suite.sh` |
| registry | saplan_smoke | `gleam run -m scripts/registry/saplan_smoke` | (new; integration smoke for sa-plan bridge) |

Full migration index: `data/script-output/_index/migration.md`.
