# SC-SCRIPT-GLEAM-001 — Gleam-Only Scripting Mandate (HARD RULE)

**Status:** MANDATORY. No exceptions without explicit human override logged in the journal with SC-HINT-006 approval.

## Rule

All project scripts — including automation, orchestration, verification, ingestion,
reporting, CI/CD glue, link-registry, ZK maintenance, matrix generation, and test-suite
drivers — **MUST** be implemented as Gleam modules and invoked via `gleam run`.

**Forbidden** (in new work and for migration of existing work):
- `.sh` / `.bash` / `.zsh` scripts with logic
- `.py` scripts with logic (any heredoc or module that exists primarily to execute code)
- `.mjs` / `.js` scripts with logic
- `bash -c '<logic>'`, `sh -c '<logic>'`, `python3 -c '<logic>'`, `node -e '<logic>'`
- Inline shell heredocs with non-trivial conditionals, loops, or data transformations

**Allowed** (purely thin invocation of binaries, no logic):
- Invoking a compiled binary: `./sa-plan ...`, `cargo ...`, `git ...`, `curl ...`, `gleam run ...`
- Systemd unit `ExecStart` that launches a single binary with fixed arguments

**Required form**:
```
gleam run -m <module_path> -- [--arg ...]
```
Example:
```
cd lib/cepaf_gleam && gleam run -m scripts/update_task_link_registry -- --task-id 1a92520c
```

## Project structure for scripts

All runnable gleam scripts MUST live under:
```
lib/cepaf_gleam/src/scripts/<script_name>.gleam
```
or, if a script carries OTP supervision / richer structure, under:
```
lib/cepaf_gleam/src/cepaf_gleam/<subsystem>/<script>.gleam
```

Each runnable script MUST expose:
```gleam
pub fn main() -> Nil { ... }
```

## Migration rule

Existing `.sh` / `.py` / `.mjs` files in `scripts/`, `sub-projects/c3i/scripts/`,
`docs/`, and anywhere else:
1. MUST be migrated to gleam modules.
2. The original file MUST be deleted (not wrapped).
3. Any tool (Rust worker, systemd unit, CI pipeline) that invoked the legacy script
   MUST be updated to invoke `gleam run -m <module>` instead.
4. Until all scripts are migrated, NEW script-like work is only allowed in Gleam.

## Enforcement

- Pre-commit hook MUST refuse new `.sh` / `.py` / `.mjs` files in `scripts/` trees.
- CI MUST fail if any forbidden file is introduced under `scripts/`.
- `wiring_guard` MUST verify that Rust workers (`src/workers.rs::dispatch`) do not
  spawn forbidden interpreters for script-like work.

## Rationale

- **Type safety + Wiring Guard**: Gleam's type system + project's existing
  `ui/domain.gleam` + `wiring_guard` produce safer scripts than untyped shell/python.
- **Triple-interface parity (SC-GLM-UI-001)**: unifies script surface with the
  existing Lustre + Wisp + TUI stack.
- **Fractal TPS (one-piece flow)**: one language for scripts = less context switching,
  less muda, deterministic reproducibility under `gleam run`.
- **Fractal Jidoka**: compile-time errors are better stop-the-line signals than
  runtime bash errors.
- **Audit trail**: `gleam run` invocations emit structured logs compatible with Zenoh
  OTel spans (SC-GLM-ZEN-001).

## Related constraints

- SC-GLM-UI-001 — triple-interface mandate
- SC-SCHED-WORK-001 — single `workers::dispatch` for execution
- SC-HINT-006 — human intent override for exceptions
- SC-DRIFT-001..008 — drift remediation
- SC-JNL-001..006 — journal governance
