# TLC — TLA+ Tools + Model Checker (subproject)

**STAMP:** SC-SCHED-TELE-TLA-001

Bundled TLA+ toolchain (TLC, SANY, TLATeX, PlusCal translator) for c3i
formal specs. Called by `scripts/verify/formal_check` as an optional second
model checker alongside Apalache.

## Layout

```
sub-projects/tlc/
├── README.md
├── .gitignore              # gitignores the jar (4 MB)
├── bin/
│   ├── tlc                 # thin launcher → java -cp tla2tools.jar tlc2.TLC
│   └── tla2sany            # TLA+ syntax analyzer
└── tla2tools/
    └── tla2tools.jar       # fetched, NOT tracked in git
```

## Invocation

```bash
./sub-projects/tlc/bin/tlc -config specs/tla/SchedTele.cfg specs/tla/SchedTele.tla
./sub-projects/tlc/bin/tla2sany specs/tla/SchedTele.tla
```

`scripts/verify/formal_check` auto-resolves this launcher when present.

## Install / refresh

```bash
gleam run -m scripts/tools/install_apalache   # installs both TLC + Apalache
```

Or manually:
- Download: https://github.com/tlaplus/tlaplus/releases
- Place as `sub-projects/tlc/tla2tools/tla2tools.jar`.

## Notes

- Requires `java` (>= 11). Already provided by devenv.
- Current version: v1.8.0 tla2tools.jar (TLC 2026.04.18).
- Companion: `sub-projects/apalache/` for Apalache symbolic checker.
