# data/script-output/ — Canonical script artifact tree (SC-SCRIPT-GLEAM-001)

All gleam-run scripts write their outputs here under
`<category>/<name>/<YYYYMMDD-HHMMSS>/`.

This directory is **runtime-owned**. Only `_index/` contents (this README and
machine-generated index files) and `.gitignore` are tracked in git; every other
path is ignored.

## Writing to this tree

Scripts MUST use `scripts/common/fsx.run_dir(category, name, stamp)` to allocate
an output directory. Direct path construction outside `paths.output_dir` is not
permitted.

## Cleaning up

- Per-invocation runs accumulate indefinitely by design (full audit trail).
- `gleam run -m scripts/registry/retention -- --keep-days 30` (future migration
  target) prunes runs older than N days.

## Consumers

- `sa-plan` Rust workers that historically spawned shell scripts will instead
  invoke `gleam run -m <category>/<name>` and consume `result.json` from the
  produced run directory via glob `<root>/data/script-output/<category>/<name>/*/result.json`.

## Schema for `result.json`

Minimum fields every script writes:

```jsonc
{
  "script": "probe/public_interface",
  "stamp":  "YYYYMMDD-HHMMSS",
  "status": "ok" | "failed",
  "passed": <int>,
  "total":  <int>,
  "results": [ ... ]     // script-specific payload
}
```
