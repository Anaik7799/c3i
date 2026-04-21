# scripts-gleam — Isolated gleam-only script host (SC-SCRIPT-GLEAM-001)

This is a **standalone** gleam sub-project that exists *only* to host the
c3i project's runnable scripts. It is deliberately isolated from:

- `lib/cepaf_gleam` (the main triple-interface application)
- `sub-projects/c3i/native/planning_daemon` (the Rust sa-plan daemon)
- `sub-projects/pi-mono` (Pi symbiosis node)
- `sub-projects/ferriskey`, `sub-projects/openclaw`, `sub-projects/sutra`, etc.

Adding a new script to this sub-project **cannot** break the main application,
the sa-plan daemon, the TLS services, or any other running service.

## Directory layout

```
sub-projects/scripts-gleam/
├── gleam.toml                       # isolated dependency set
├── src/
│   ├── scripts_gleam.gleam          # host module (prints usage)
│   ├── scripts_sh_ffi.erl           # minimal Erlang FFI (port-spawn only)
│   └── scripts/                     # canonical tree of runnable scripts
│       ├── README.md
│       ├── common/                  # shared helpers (not runnable)
│       │   ├── args.gleam           # typed arg parsing
│       │   ├── paths.gleam          # canonical path resolution
│       │   ├── logx.gleam           # UTC stamp + structured logs
│       │   ├── fsx.gleam            # filesystem (simplifile-backed)
│       │   ├── httpx.gleam          # HTTP client wrapper
│       │   └── saplan.gleam         # sa-plan binary integration
│       ├── probe/                   # network/endpoint probes
│       ├── build/
│       ├── ingest/
│       ├── registry/
│       ├── verify/
│       ├── fractal/
│       ├── tls/
│       ├── pi/
│       └── drift/
└── test/
```

## Running a script

```
cd sub-projects/scripts-gleam
gleam run -m scripts/<category>/<name> -- [--flag value ...]
```

Examples:

```
gleam run -m scripts/probe/public_interface
gleam run -m scripts/probe/public_interface -- --base http://localhost:4200
gleam run -m scripts/registry/saplan_smoke
```

## Output tree (clean, runtime-owned)

```
<repo>/data/script-output/
  _index/README.md                   # tracked
  _index/migration.md                # tracked
  .gitignore                         # tracked (ignores run dirs)
  <category>/<name>/<YYYYMMDD-HHMMSS>/
    stdout.log
    result.json
    artifacts/
```

## System integration

Scripts access the wider system **only** through:

1. `scripts/common/saplan` — invokes the `sa-plan` binary (the single
   authoritative task/job/pref/queue/email surface). Environment variable
   `SAPLAN_BIN` overrides the default binary path.
2. HTTP probes against the running sa-plan HTTP API (via `common/httpx`).
3. Erlang FFI at `src/scripts_sh_ffi.erl` — the only place that spawns OS
   processes in this subproject, using `open_port/2` with
   `{spawn_executable, ...}` (no shell).

No script writes to `planning.db`, `.gitignore`, `/etc/`, or any system path
other than `data/script-output/` or an explicit `--output` directory.

## Rust worker bridge (SC-SCHED-WORK-001)

The sa-plan Rust daemon exposes a `gleam_script` worker in
`native/planning_daemon/src/workers.rs` that invokes:

```
cd sub-projects/scripts-gleam && gleam run -m <module> -- [argv...]
```

Enqueue a gleam script as a job:

```
./sa-plan job-enqueue --queue maintenance --worker gleam_script \
    --args '{"module":"scripts/probe/public_interface"}' \
    --unique-key gleam-probe-$(date -u +%s)
```

## Hard rule referenced

SC-SCRIPT-GLEAM-001 (`.claude/rules/gleam-only-scripting-mandate.md`,
`.gemini/rules/gleam-only-scripting-mandate.md`).
