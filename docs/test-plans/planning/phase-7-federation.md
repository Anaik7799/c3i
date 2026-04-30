# Phase 7 — Federation (L7)

## Scope

CPIG matrix bump, multi-region voting, governance parity, ZK ingest, attestation, federated cron.

## Test cases

1. **CPIG matrix update** — bump Gleam UI Triple-Interface (subsystem #10) from 4/5 to 5/5 after email closure (SC-CPIG-001..015). Verify by reading `docs/journal/task-116480247290237220/cpig-matrix.json`.
2. **System-wide CPIG score recompute** — `[Σ score(s)] / (5×|registry|)` recomputes; target ≥ 53 % baseline maintained or improved.
3. **`.claude` ↔ `.gemini` parity** — diff `rules/`, `agents/`, `skills/` between `.claude` and `.gemini`. SC-SYNC-DOC-007.
4. **Federated CPIG attestation** — sign mesh CPIG score with Ed25519 (SC-CPIG-FED-002), publish to `indrajaal/l7/fed/cpig/attest/<peer>`. Verify signature.
5. **Multi-region quorum** — emulate 3 regions (eu, us-west, asia); require 2oo3 vote on hypothetical CPIG promotion (SC-CPIG-FED-004).
6. **ZK ingest of journal + analysis + deck + Allium spec + test plan** — `sa-plan-daemon ingest-docs` returns success and reports new holon IDs (SC-ZETTEL-001).
7. **Email closure** — `sa-plan-daemon send-email -a journal.md -a analysis.html -a deck.html -a links.json` returns `0` (SC-NOTIFY-JOURNAL-001).
8. **Link registry** — `task-116492319530224001-links.json` lists ≥ 5 entries (journal, analysis, deck, screenshots/, diagrams/png/, Allium, test plan).
9. **Page-spec checker cron** — runs every 3 min via gleam_run worker. SC-PAGE-SPEC-002 + SC-DISP-REGISTRY-001..010.
10. **CPIG validator agent** — `.claude/agents/cpig-validator.md` invocation reproduces same matrix; no manual diff.

## Exit criteria

- CPIG subsystem #10 = 5/5; system-wide score recomputed.
- ZK ingest success; ≥ 5 new holon IDs.
- Email receipt logged.
- ΣRPN reduction ≥ 58 %.
- λ ≥ 0; H ≥ 2.5.
