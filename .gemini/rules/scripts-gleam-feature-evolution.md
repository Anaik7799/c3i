# scripts-gleam Feature-Evolution Protocol (SC-SCRIPT-EVO-001)

## MANDATE
**Every time a new feature is delivered inside `sub-projects/scripts-gleam/` (new gleam script, new NIF, new common module), the corresponding feature-evolution artefact pack MUST be generated via the reusable libraries — no copy-paste, no shell scripts.**

## Single entrypoint

```
cd sub-projects/scripts-gleam
gleam run -m scripts/verify/feature_evolution -- --task-id <sa-plan-task-id>
```

That command:

1. Renders 5 canonical graphviz diagrams via `scripts/common/diagrams.render_standard_set`.
2. Writes a 13-section journal via `scripts/common/journal`.
3. Writes a consistent analysis HTML via `scripts/common/html_doc`.
4. Writes the companion slide deck via `scripts/common/html_deck`.
5. Writes the task-id link registry via `scripts/common/delivery.write_links_registry`.
6. Emails the full pack via `scripts/common/delivery.send` (`sa-plan send-email -a …`).
7. Ingests into ZK via `scripts/common/delivery.ingest_zk` (`sa-plan ingest-docs`).
8. Publishes Zenoh progress spans on `indrajaal/l5/scripts/evolution/<tid>/start` + `/complete`.
9. Records fractal span, metrics counter, and a Smriti stamp.

All artefacts land under
`sub-projects/c3i/docs/journal/` so the sa-plan task-id page serves them at
`http://vm-1.tail55d152.ts.net:4200/task-id/<tid>/<file>` and
`https://vm-1.tail55d152.ts.net:8443/task-id/<tid>/<file>`.

## Reusable library tier (SC-FEAT-EVO-LIB)

| Module | Responsibility |
|---|---|
| `scripts/common/artifact` | canonical filename + URL builders |
| `scripts/common/journal` | 13-section journal writer |
| `scripts/common/html_doc` | consistent feature HTML (prompt/features/impl/usage/testing/summary + KPIs + diagrams) |
| `scripts/common/html_deck` | slide deck writer |
| `scripts/common/diagrams` | DOT → PNG rendering + 5 canned diagram builders |
| `scripts/common/delivery` | email pack + ZK ingest + task-id links JSON |

**Do not duplicate these behaviours in ad-hoc gleam code.** New orchestrators MUST import these libraries.

## STAMP constraints

| ID | Constraint | Severity |
|---|---|---|
| SC-SCRIPT-EVO-001 | Feature evolution orchestrator runs via `gleam run -m scripts/verify/feature_evolution` only | CRITICAL |
| SC-FEAT-EVO-LIB-001 | `scripts/common/{artifact,journal,html_doc,html_deck,diagrams,delivery}` are single sources of truth | HIGH |
| SC-FEAT-EVO-LIB-002 | Orchestrators MUST NOT author shell / python / heredoc code | CRITICAL |
| SC-FEAT-EVO-LIB-003 | All artefacts land under `sub-projects/c3i/docs/journal/` (task-id page convention) | HIGH |
| SC-FEAT-EVO-LIB-004 | Tailscale HTTPS link MUST be the first line of the journal `.md` | HIGH |
| SC-FEAT-EVO-LIB-005 | Journal MUST follow the 13-section structure from `journal-protocol.md` | CRITICAL |
| SC-FEAT-EVO-LIB-006 | Email pack MUST attach journal + analysis + deck + links + diagrams (absolute paths) | CRITICAL |
| SC-FEAT-EVO-LIB-007 | Zenoh progress spans on start + complete under `indrajaal/l5/scripts/evolution/<tid>/*` | HIGH |
| SC-FEAT-EVO-LIB-008 | ZK ingest fires after delivery so new artefacts become searchable | HIGH |

## When to run

- Every time a new runnable script is added under `src/scripts/<category>/`.
- Every time the NIF surface expands (`native/scripts_nif/src/lib.rs`).
- Every time a common module is added or changes its public API.
- On every `git push` that touches `sub-projects/scripts-gleam/src/` — add to CI.

## CI hook (proposed)

```
pre-push:
  cd sub-projects/scripts-gleam
  gleam build                                       # typecheck
  gleam run -m scripts/tools/guard_no_shell         # block shell/python re-entry
  gleam run -m scripts/tools/list                   # regenerate registry.json
  # feature_evolution runs on the sa-plan feature task, not on every push,
  # but the guard + registry MUST be green to push.
```

## Governance parity

This rule is mirrored at `.gemini/rules/scripts-gleam-feature-evolution.md`.
