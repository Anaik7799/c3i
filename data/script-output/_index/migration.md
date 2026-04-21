# Gleam-Only Script Migration Index (SC-SCRIPT-GLEAM-001)

Authoritative map from legacy script files to their `gleam run` replacements.

Status legend:
- `DONE`: gleam module exists and is the canonical entry point.
- `PENDING`: legacy file still invoked somewhere; no gleam replacement yet.
- `ARCHIVED`: legacy file deleted, gleam replacement is the only entry.

| Legacy path | Target gleam module | Category | Status | Notes |
|---|---|---|---|---|
| `sub-projects/c3i/scripts/public_interface_test_suite.sh` | `scripts/probe/public_interface` | probe | DONE (HTTP subset) | HTTPS self-signed + WS upgrade probes pending (MIG-SCRIPT-P1 httpc SSL) |
| `sub-projects/c3i/scripts/update_task_link_registry.sh` | `scripts/registry/task_link_registry` | registry | PENDING | Rust worker `run_link_registry_refresh` to switch after migration |
| `sub-projects/c3i/scripts/fractal_feature_evolution_suite.sh` | `scripts/verify/feature_evolution_suite` | verify | PENDING | multi-phase orchestrator |
| `sub-projects/c3i/scripts/recursive_feature_convergence.sh` | `scripts/verify/feature_convergence` | verify | PENDING | cache + iterate |
| `sub-projects/c3i/scripts/generate_fractal_criticality_matrix.sh` | `scripts/fractal/criticality_matrix` | fractal | PENDING | RPN matrix generator |
| `sub-projects/c3i/scripts/pi_skills_phase_orchestrator.sh` | `scripts/pi/skills_phase` | pi | PENDING | phase-N orchestrator |
| `sub-projects/c3i/scripts/sa-plan-tls-setup.sh` | `scripts/tls/setup` | tls | PENDING | delegates to `sa-plan tls ...` binary |
| `sub-projects/c3i/scripts/visual_verify_task.mjs` | `scripts/verify/visual_task` | verify | PENDING | playwright bridge TBD |
| `sub-projects/c3i/scripts/cpu-governor.sh` | `scripts/common/cpu_governor` | common | PENDING | system helper |
| `sub-projects/c3i/scripts/capture-ignition.sh` | `scripts/verify/capture_ignition` | verify | PENDING | |
| `sub-projects/c3i/scripts/verification/constraint_sync_check.sh` | `scripts/verify/constraint_sync` | verify | PENDING | |
| `sub-projects/c3i/scripts/verification/agda_typecheck_ci.sh` | `scripts/verify/agda_typecheck` | verify | PENDING | |
| `sub-projects/c3i/scripts/substrate/sanitize_treesitter.sh` | `scripts/ingest/treesitter_sanitize` | ingest | PENDING | |
| `sub-projects/c3i/scripts/containers/entrypoint.sh` | n/a | — | RETAIN | systemd/container ExecStart; trivial, thin invoker (allowed) |
| `sub-projects/c3i/scripts/timestamp/indrajaal-timestamp-sync.sh` | `scripts/common/timestamp_sync` | common | PENDING | |
| `scripts/exhaustive_parity_audit.py` | `scripts/verify/parity_audit` | verify | PENDING | |
| `scripts/enable_https_443_via_tailscale.sh` | `scripts/tls/tailscale_443_enable` | tls | PENDING | requires privileged operator path; stays a thin caller |
| `scripts/xvfb-record.sh` | `scripts/verify/xvfb_record` | verify | PENDING | |
| `scripts/test-openclaw-comprehensive.sh` | `scripts/verify/openclaw_comprehensive` | verify | PENDING | |
| `scripts/generators/swarm_generator.py` | `scripts/build/swarm_generator` | build | PENDING | |

## Tracking tasks (sa-plan)

| Task ID | Title | Priority |
|---|---|---|
| 116442088826964959 | SC-SCRIPT-GLEAM-001 Rule registered | P0 |
| 116442088828961872 | MIG-SCRIPT-P0 full migration | P0 |
| 116442088830605564 | MIG-SCRIPT-P0a sub-project hot scripts | P0 |
| 116442088832096008 | MIG-SCRIPT-P0b root scripts | P0 |
| 116442088833762315 | MIG-SCRIPT-P1 Rust workers invoke gleam run | P1 |
| 116442088835288142 | MIG-SCRIPT-P1 pre-commit + CI enforcement | P1 |
| 116442088840360060 | MIG-SCRIPT-P1 gleam on daemon PATH | P1 |
| 116442088842034221 | MIG-SCRIPT-P1 httpc SSL for self-signed | P1 |

## Update protocol

Whenever a script is migrated:
1. Create the gleam module under `lib/cepaf_gleam/src/scripts/<category>/<name>.gleam`.
2. Run `gleam build` and a smoke invocation.
3. Update this table from PENDING → DONE.
4. Update any Rust worker / systemd unit / CI pipeline to call `gleam run -m <module>`.
5. Delete the legacy file → change status to ARCHIVED.
6. Update `PROJECT_TODOLIST` task state.
