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
cd sub-projects/scripts-gleam && gleam run -m <module_path> -- [--arg ...]
```
Example:
```
cd sub-projects/scripts-gleam
gleam run -m scripts/probe/public_interface
gleam run -m scripts/registry/saplan_smoke
```

## Project structure for scripts (canonical, single common area)

**All runnable gleam scripts live in the isolated `scripts-gleam` subproject:**
```
sub-projects/scripts-gleam/
  gleam.toml                         # isolated dependency set
  README.md                          # subproject overview
  src/
    scripts_gleam.gleam              # host module
    scripts_sh_ffi.erl               # port-spawn FFI (only here)
    scripts/
      README.md                      # conventions
      common/                        # shared helpers; not runnable
        args.gleam
        paths.gleam
        logx.gleam
        fsx.gleam
        httpx.gleam
        saplan.gleam                 # sa-plan binary integration
      probe/ build/ ingest/ registry/
      verify/ fractal/ tls/ pi/ drift/
```

**Hard isolation invariants:**
- `lib/cepaf_gleam` MUST NOT depend on `scripts-gleam`.
- Other subprojects (`pi-mono`, `ferriskey`, `openclaw`, `sutra`) MUST NOT depend on `scripts-gleam`.
- `scripts-gleam` MUST NOT import from any other sub-project or from `lib/cepaf_gleam`.
- The only way scripts interact with system services is via the `sa-plan` binary (thin invocation) or the sa-plan HTTP API.

Each runnable module MUST:
1. Live at `src/scripts/<category>/<name>.gleam`.
2. Export `pub fn main() -> Nil`.
3. Parse args via `scripts/common/args`.
4. Resolve paths via `scripts/common/paths`.
5. Write outputs via `scripts/common/fsx.run_dir(category, name, stamp)`.
6. Log via `scripts/common/logx`.
7. Panic on failure (non-zero exit), return `Nil` on success.

## Output tree (clean + organized)

```
<repo>/data/script-output/
  _index/                          # tracked: README + migration.md
  .gitignore                       # tracked: ignores all run dirs
  <category>/
    <name>/
      <YYYYMMDD-HHMMSS>/           # one dir per invocation, gitignored
        stdout.log
        result.json                # machine-readable payload
        artifacts/                 # script-produced files
```

No script writes outside `data/script-output/` or its explicit `--output` path.
No tmp files in `/tmp`, repo root, or random docs paths.

## Migration rule

Existing `.sh` / `.py` / `.mjs` files in `scripts/`, `sub-projects/c3i/scripts/`,
`docs/`, and anywhere else:
1. MUST be migrated to gleam modules under `lib/cepaf_gleam/src/scripts/<category>/`.
2. The original file MUST be deleted (not wrapped).
3. Any tool (Rust worker, systemd unit, CI pipeline) that invoked the legacy script
   MUST be updated to invoke `gleam run -m <category>/<name>` instead.
4. Until all scripts are migrated, NEW script-like work is only allowed in Gleam.
5. Migration progress tracked in `data/script-output/_index/migration.md`.

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
