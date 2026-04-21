# Apalache — Symbolic TLA+ Model Checker (subproject)

**STAMP:** SC-SCHED-TELE-TLA-001

Bundled Apalache symbolic model checker for c3i formal specs (TLA+). Called
by `scripts/verify/formal_check` as the required safety gate alongside Quint.

## Layout

```
sub-projects/apalache/
├── README.md
├── .gitignore              # gitignores the extracted distribution (130 MB)
├── bin/
│   └── apalache-mc         # thin launcher → apalache-<VERSION>/bin/apalache-mc
└── apalache-<VERSION>/     # fetched + extracted, NOT tracked in git
    ├── bin/apalache-mc
    ├── lib/…
    └── LICENSE
```

## Invocation

```bash
./sub-projects/apalache/bin/apalache-mc version
./sub-projects/apalache/bin/apalache-mc check \
    --config=specs/tla/SchedTele.cfg specs/tla/SchedTele.tla
```

`scripts/verify/formal_check` auto-resolves this launcher when present.

## Install / refresh

```bash
gleam run -m scripts/tools/install_apalache -- \
    --version 0.56.1 --dest /home/an/dev/ver/c3i/sub-projects/apalache
```

Or manually:
- Download: https://github.com/apalache-mc/apalache/releases
- Extract into `sub-projects/apalache/apalache-<version>/`

Override version with `APALACHE_VERSION=0.56.1` before running the launcher.

## Notes

- Requires `java` (>= 17). Already provided by devenv.
- Current version: 0.56.1 (SHA256 `a61c07569d7195ddc589f01037fa10fafef4fb0796af2f1c9cb45226375dfbfc`).
- Companion: `sub-projects/tlc/` for TLC model checker.
