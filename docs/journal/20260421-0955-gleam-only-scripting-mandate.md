# https://vm-1.tail55d152.ts.net:8443/task-id/1a92520c

# Gleam-Only Scripting Mandate (SC-SCRIPT-GLEAM-001)

**UTC:** 2026-04-21 09:55
**Status:** HARD PROJECT RULE enacted.

## Rule
All project scripts MUST be implemented as Gleam modules and invoked via `gleam run -m <module> -- [args]`.
Forbidden: new `.sh`, `.py`, `.mjs` scripts with logic; inline `bash -c '<logic>'`,
`python3 -c '<logic>'`, `node -e '<logic>'`; logic-carrying heredocs.

## Governance files
- `.claude/rules/gleam-only-scripting-mandate.md`
- `.gemini/rules/gleam-only-scripting-mandate.md`

## Working example (proven)
- `lib/cepaf_gleam/src/scripts/public_interface_probe.gleam`
- `gleam run -m scripts/public_interface_probe` → **10/10 pass** on `http://vm-1.tail55d152.ts.net:4200`

## Violations found in workspace
- 33 `.sh`/`.py`/`.mjs` files across `scripts/`, `sub-projects/c3i/scripts/` trees
- Rust worker `run_link_registry_refresh` currently shells out to legacy `update_task_link_registry.sh`; must be retargeted to `gleam run` once migrated

## Sa-plan tasks registered
- `116442088826964959` Rule registration (P0)
- `116442088828961872` MIG-SCRIPT-P0 full migration (P0)
- `116442088830605564` MIG-SCRIPT-P0a sub-project hot scripts (P0)
- `116442088832096008` MIG-SCRIPT-P0b root scripts (P0)
- `116442088833762315` MIG-SCRIPT-P1 Rust workers must invoke gleam run (P1)
- `116442088835288142` MIG-SCRIPT-P1 pre-commit/CI enforcement (P1)
- `116442088840360060` MIG-SCRIPT-P1 gleam on daemon PATH (P1)
- `116442088842034221` MIG-SCRIPT-P1 httpc SSL for self-signed probes (P1)

## Migration order (Fractal TPS one-piece flow)
1. Provision gleam on daemon PATH (unblock all downstream).
2. Migrate sub-project hot scripts (MIG-SCRIPT-P0a).
3. Update Rust worker bindings to `gleam run -m <module>`.
4. Delete legacy `.sh` originals after each migration.
5. Add CI guard rejecting new `.sh/.py/.mjs` in `scripts/` trees.
6. Migrate remaining root scripts (MIG-SCRIPT-P0b).
7. Full audit: `rg -n "^#!/usr/bin/env (bash|python|node)"` must return 0 matches under tracked `scripts/` trees.

## FMEA-style RPN
- Severity 8 (mixed-language drift), Occurrence 10 (33 instances exist), Detectability 3 → RPN 240.
- Priority P0 for enforcement + P0a migration; P1 for automation/CI.

## Mainline stability
No main-branch runtime behavior changed by this rule; existing binaries and services keep running.
The rule constrains future work and pending migrations.
