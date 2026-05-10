# Functional Runtime Governance + Dirty Worktree Audit + Journal Bundle Handoff

**Date**: 2026-05-10
**Timezone**: Europe/Stockholm
**Operator Directive**: create detailed journal entry, HTML, slides, email, comprehensive journal/HTML/slides/email skills, correct links, sa-plan/task-management integration, add to git, and skip `gdrive/`.
**sa-plan task**: `116548743475798483` (`urn:c3i:task:misc:116548743475798483`)
**Bundle slug**: `20260510-functional-runtime-governance-dirty-worktree-audit`
**Links manifest**: `docs/journal/task-116548743475798483-links.json`
**Handoff index**: `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-index.html`
**Primary repos/surfaces inspected**:

- C3I root: `/home/an/dev/ver/c3i`
- Pi-mono nested repo: `/home/an/dev/ver/c3i/sub-projects/pi-mono`
- C3I daemon nested repo: `/home/an/dev/ver/c3i/sub-projects/c3i`
- Work surface: `/home/an/dev/ver/work`

---

## 1. Scope & Trigger

This entry records the publication and git-staging pass for the functional-runtime governance and dirty-worktree audit bundle. The operator requested a detailed journal, HTML report, slide deck, email draft, comprehensive skills for journal/slides/HTML/email, correct links, full sa-plan/plan/task-management integration, git addition, and explicit avoidance of the Google Drive folder.

The bundle consolidates two states:

| Evidence Type | Meaning |
|---|---|
| Historical closure evidence | Prior governance commits and prior sa-plan ingestion evidence already recorded in the existing untracked bundle. |
| Current-pass evidence | Revalidation performed on 2026-05-10 before staging: local files exist, JSON validates, route checks currently fail because the HTTP service is down and DNS is unavailable, and direct `sa-plan status` currently fails with a SQLite open error in this sandbox/session. |

This journal intentionally does not bulk-stage the entire dirty C3I tree. It stages only the requested journal bundle and journal-publisher rules/skills/agents/commands.

---

## 2. Pre-State Assessment

### Repository state

`/home/an/dev/ver/work` is not a git repository. The canonical repo for durable C3I rules, skills, agents, journal docs, and sa-plan integration is `/home/an/dev/ver/c3i`.

The C3I root was already heavily dirty before this pass. Sample status categories observed:

| Area | State | Interpretation |
|---|---:|---|
| C3I root | many modified/untracked files | Existing/parallel work spanning Gemini mirror files, vault/IAM/FerrisKey work, monitor artifacts, and nested repo markers. |
| Journal bundle | untracked | The requested journal/HTML/deck/email/manifest existed but was not tracked by git. |
| Journal publisher skills/rules/agents/commands | untracked or newly updated | Existing skeletons were present and needed a more comprehensive contract. |
| `sub-projects/work/` | untracked from C3I root | Work surface should not be bulk-added; `gdrive/` explicitly skipped. |

### Existing historical closure evidence

| Repo | Commit | Purpose |
|---|---|---|
| `/home/an/dev/ver/c3i` | `95fdb705 docs: add functional runtime governance` | Root C3I Claude/Gemini/.agents rules, skills, agents, hooks, and supervisor mirrors for Effect TS + fp-core Rust. |
| `/home/an/dev/ver/c3i/sub-projects/pi-mono` | `3c88aa7 feat: enforce Effect and fp-core governance` | Pi-mono Effect dependency, C3I bridge code, rules, skills, agents, and hook mirrors. |
| `/home/an/dev/ver/c3i/sub-projects/pi-mono` | `e29dee2 fix: align Effect runtime parity` | Follow-up parity fix for fp-core references and Effect-based Node builtin lookup. |

### Current planning-route state

Current route and daemon checks did not pass:

| Check | Result | Impact |
|---|---|---|
| `./sa-plan status` | `SQLite error: unable to open database file` | Current-pass task status/sync is blocked; historical task evidence remains recorded. |
| `http://127.0.0.1:4200/...` route check | connection refused | Local route is currently unavailable; local file links still work. |
| `https://vm-1.tail55d152.ts.net/...` route check | DNS resolution failed | Tailscale route cannot be verified in this sandbox/session. |
| `jq empty` on manifest | PASS | Manifest syntax is valid. |
| local artifact file checks | PASS | Local artifact paths exist. |

---

## 3. Execution Detail

### Phase A — Rule/skill discovery

Read the local work-surface bridge and canonical C3I guidance. Confirmed:

- `/home/an/dev/ver/work` is a work surface, not a git repo.
- durable C3I artifacts belong in `/home/an/dev/ver/c3i`.
- TypeScript work remains Effect-only.
- Rust work remains fp-core functional style where Rust is touched.
- journal bundles must use the 13-section protocol and task/notification integration.

### Phase B — Existing bundle inspection

Inspected the existing untracked bundle:

- `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-journal.md`
- `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-analysis.html`
- `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-deck.html`
- `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-email.md`
- `docs/journal/task-116548743475798483-links.json`

The bundle was useful but incomplete against the stricter publication contract because it lacked:

- a mandatory operator handoff index;
- explicit route-status distinction between local file links and unavailable HTTP/Tailscale routes;
- a fully enforced 13-section journal structure;
- comprehensive artifact-specific skill references for journal, HTML, slides, and email;
- explicit degraded-mode capture for the current `sa-plan` failure.

### Phase C — Skill/rule/agent expansion

Expanded the journal publisher system across Claude, Gemini, and `.agents`:

- required journal, analysis HTML, deck HTML, email draft, handoff index, links manifest, and sa-plan evidence;
- added task-management integration with status/update/sync/ingest/workflow/job/schedule references;
- added route validation semantics: `verified`, `expected`, `unavailable`, `local-only`;
- added GDrive skip rule unless explicitly requested;
- added focused reference files for journal template, HTML report, slide deck, email payload, and sa-plan workflow.

### Phase D — Artifact update

Updated this journal into the 13-section format, added a handoff index, and refreshed the email/manifest to include the index and current validation status.

### Phase E — Validation and staging boundary

Validated local files and JSON. Route checks were attempted and recorded as unavailable rather than claimed live. Git staging is limited to the bundle and journal-publisher governance surfaces; `gdrive/` and unrelated dirty files are excluded.

### Phase F — Second detailed pass

The second pass deepened the skill system and artifact evidence rather than expanding the staging scope:

- added `link-validation.md` to define local path, relative href, localhost route, customer Tailscale route, internal HTTPS route, and failure-status semantics;
- added `task-management-integration.md` to define task, todo, workflow, scheduler, job, queue, knowledge, recommendation, session, and email evidence requirements;
- updated Claude, Gemini, and `.agents` skills to reference the new validation and task-management files;
- updated rules and commands to reject staged `gdrive/` paths and preserve separate historical/current-pass evidence;
- updated the artifacts to make the second-pass validation state visible without claiming current route or planner success.

---

## 4. Root Cause Analysis

### Why was this bundle not already safely git-added?

1. **Why was it untracked?** The prior artifact bundle was created during a larger governance/dirty-audit pass and remained outside the commit boundary.
2. **Why was the commit boundary narrow?** The C3I root had substantial unrelated dirty state, making bulk staging unsafe.
3. **Why is bulk staging unsafe?** Dirty files include generated provider registries, Gemini identity drift, vault/IAM/FerrisKey runtime work, logs, monitor JSON, and nested repo changes.
4. **Why does the bundle need stronger validation?** Existing links mixed expected internal routes with local paths without current route-liveness evidence.
5. **Why did sa-plan revalidation fail now?** The current `sa-plan` invocation resolves to the nested Rust daemon and currently reports `SQLite error: unable to open database file`; this appears tied to the current nested daemon/data-path state and sandbox access behavior, not to the static journal artifacts.

### Pattern-level cause

The underlying pattern is an artifact-publication boundary problem: durable publication artifacts were created in the correct repo but were not yet isolated, indexed, route-validated, and staged as a bounded git changeset.

---

## 5. Fix Taxonomy

| Fix Pattern | Applied Change | Reuse Rule |
|---|---|---|
| Contract tightening | Expanded journal publisher skills/rules/agents/commands. | Any future bundle must include journal, HTML, deck, email, index, links, and task evidence. |
| Local-first links | Added relative/local link requirements and explicit route status. | Never claim route liveness from path shape alone. |
| Degraded task evidence | Recorded current `sa-plan` failure separately from historical task evidence. | Planning integration can be degraded but must never be silent. |
| Staging isolation | Stage only artifact/governance files. | Do not bulk-stage dirty trees. |
| GDrive exclusion | Mark GDrive skipped and exclude `gdrive/` paths. | Upload only on explicit operator request. |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns

- **Artifact bundles need an index**: an operator handoff page prevents fragmented navigation across Markdown, HTML, deck, email, and JSON.
- **Route status is a first-class field**: `verified`, `expected`, `unavailable`, and `local-only` prevent false link claims.
- **Task integration needs degraded modes**: when `sa-plan` fails, the manifest should record the failure and preserve prior task evidence rather than pretending sync happened.
- **Provider-specific mirrors need identity preservation**: Claude, Gemini, and `.agents` surfaces can share a contract while preserving provider-specific semantics.

### Anti-patterns

- **Bulk staging dirty C3I root**: would mix unrelated runtime, generated, vault, and mirror changes.
- **Claiming Tailscale links are live without curl evidence**: route shape is not liveness.
- **Treating a work surface as a repo**: `/home/an/dev/ver/work` can be operationally important without being the commit target.
- **Touching `gdrive/` while publishing docs**: unnecessary and explicitly excluded by the operator.

---

## 7. Verification Matrix

| Gate | Current Result | Evidence |
|---|---|---|
| Local journal exists | PASS | `test -f docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-journal.md` |
| Local analysis HTML exists | PASS | `test -f docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-analysis.html` |
| Local deck HTML exists | PASS | `test -f docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-deck.html` |
| Local email draft exists | PASS | `test -f docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-email.md` |
| Local links manifest exists | PASS | `test -f docs/journal/task-116548743475798483-links.json` |
| Local handoff index exists | PASS | `test -f docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-index.html` |
| Manifest JSON | PASS | `jq empty docs/journal/task-116548743475798483-links.json` |
| Relative index hrefs | PASS | All same-directory links in the handoff index resolve to existing files. |
| Localhost route | UNAVAILABLE | `/usr/bin/curl` returned connection refused for `127.0.0.1:4200`. |
| Tailscale route | UNAVAILABLE | `/usr/bin/curl` reported DNS resolution failure for `vm-1.tail55d152.ts.net`. |
| sa-plan status | BLOCKED CURRENT PASS | `./sa-plan status` returned SQLite open error. |
| GDrive skipped | PASS | No `gdrive/` files are part of this bundle/staging boundary. |
| Email sent | NOT SENT CURRENT PASS | Email draft and command prepared; send blocked by current `sa-plan` failure unless a working daemon is restored. |

Historical validation from the prior bundle remains recorded: task `116548743475798483`, durable `ingest-docs` evidence, and governance commit evidence. This pass does not re-assert those gates as current successes where current commands failed.

---

## 8. Files Modified

### Journal bundle artifacts

| Path | Purpose |
|---|---|
| `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-journal.md` | 13-section journal and current-pass validation record. |
| `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-analysis.html` | Operator HTML analysis report. |
| `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-deck.html` | Scrollable HTML slide deck. |
| `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-email.md` | Email draft with attachment/send details. |
| `docs/journal/20260510-functional-runtime-governance-dirty-worktree-audit-index.html` | Operator handoff index linking all artifacts. |
| `docs/journal/task-116548743475798483-links.json` | Links manifest with route status, local paths, task evidence, and validation state. |

### Journal publisher skills/rules/agents/commands

| Surface | Paths |
|---|---|
| Claude | `.claude/skills/journal-artifact-publisher/**`, `.claude/rules/journal-artifact-bundle.md`, `.claude/commands/journal-bundle.md`, `.claude/agents/journal-artifact-publisher.md` |
| Gemini | `.gemini/skills/journal-artifact-publisher/SKILL.md`, `.gemini/rules/journal-artifact-bundle.md`, `.gemini/commands/journal-bundle.md`, `.gemini/agents/journal-artifact-publisher.md` |
| `.agents` | `.agents/skills/journal-artifact-publisher/SKILL.md`, `.agents/rules/journal-artifact-bundle.md`, `.agents/commands/journal-bundle.md`, `.agents/agents/journal-artifact-publisher.md` |

### Second-pass reference additions

| Path | Purpose |
|---|---|
| `.claude/skills/journal-artifact-publisher/references/link-validation.md` | Defines link classes, validation commands, route-status semantics, and working-link definitions. |
| `.claude/skills/journal-artifact-publisher/references/task-management-integration.md` | Defines sa-plan/task/workflow/scheduler/job/knowledge/email evidence mapping and degraded-mode handling. |

No `gdrive/` files were modified for this pass.

---

## 9. Architectural Observations

The work folder and C3I repo serve different roles:

- `/home/an/dev/ver/work` is an operational work surface with local tools, DBs, caches, adapters, screenshots, and Google Drive mount support.
- `/home/an/dev/ver/c3i` is the canonical git repository for durable C3I rules, skills, agents, docs, and planning infrastructure.

This means the publication pattern should be:

```text
operator request
  -> work surface context can be inspected
  -> durable journal/rule/skill artifacts land in C3I git
  -> local paths validated
  -> route status recorded
  -> sa-plan task evidence recorded or degraded
  -> only bounded files staged
```

The sa-plan route currently has two layers:

- static artifacts are valid on disk;
- route and task daemon integration are unavailable in the current pass and must be repaired separately before claiming live task browsing or new planner mutations.

---

## 10. Remaining Gaps

| Priority | Gap | Recommended Next Action |
|---|---|---|
| P0 | `sa-plan status` currently fails with SQLite open error. | Repair nested daemon/data path or run from an environment with planner DB access, then re-run status/sync/ingest. |
| P0 | HTTP/Tailscale routes are not currently reachable. | Restart/verify `c3i-sa-plan-http` and Tailscale Serve, then update route statuses to `verified`. |
| P1 | Large unrelated C3I dirty state remains. | Do separate reviewed staging passes by domain: Gemini mirror repair, vault/IAM, nested C3I daemon, generated runtime artifacts. |
| P1 | Email was not sent in current pass because `sa-plan send-email` depends on the failing planner path. | Send once sa-plan is restored, with journal, analysis, deck, index, and manifest attached. |
| P2 | Codex home skill exists outside git. | Mirror changes into repo-owned `.agents` and documented Codex installation process; avoid pretending home skill is git-tracked. |

---

## 11. Metrics Summary

| Metric | Value |
|---|---:|
| Journal protocol sections | 13/13 |
| Bundle artifacts required by updated skill | 6/6 |
| Local file existence checks | 5/5 before index; index added in this pass |
| Manifest JSON validation | PASS |
| Route liveness checks | 0/10 verified; service/DNS unavailable |
| GDrive files touched | 0 |
| Existing governance commits verified in git log | 3 |
| Current-pass sa-plan command success | 0; blocked by SQLite open error |
| Dirty worktree bulk-staged | 0 |
| Dedicated skill reference files after second pass | 8 |
| GDrive staged paths | 0 |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Alignment |
|---|---|
| SC-JOURNAL / AOR-JOURNAL-001 | Journal now follows all 13 mandatory sections. |
| SC-SYNC-DOC-002 | Documentation and task-linked artifact bundle created for the plan update. |
| SC-NOTIFY-JOURNAL | Email draft and attachment command prepared; actual send currently blocked by sa-plan runtime failure and should be retried after repair. |
| SC-FP-RUST | No Rust code was modified in this pass. |
| SC-EFFECT-TS | No TypeScript code was modified in this pass. |
| C3I workflow safety | No unrelated dirty files or `gdrive/` paths are intentionally staged. |
| Truth/freshness | Current route and sa-plan failures are recorded explicitly rather than reported as successes. |

---

## 13. Conclusion

The requested publication system is now converted from a lightweight skeleton into a comprehensive journal/HTML/slides/email bundle contract. The C3I-owned Claude, Gemini, and `.agents` surfaces now require a Markdown journal, analysis HTML, deck HTML, email draft, handoff index, links manifest, task evidence, route-status evidence, and bounded git staging.

The static artifact bundle is ready for git staging as a bounded changeset, with `gdrive/` skipped. Local file paths are valid and the manifest JSON validates. Public/customer and localhost route links are structurally recorded but currently unavailable; they must not be described as live until the sa-plan HTTP service and Tailscale DNS/Serve path are repaired and rechecked.

The remaining operational blocker is the current `sa-plan` SQLite open error. Historical sa-plan task and ingestion evidence is preserved for task `116548743475798483`, but current-pass task mutation/sync/ingest/email should be retried after the planner database path is restored.

Second-pass conclusion: the static bundle is now stronger than the live service state. The links that can be made to work without the runtime service are working locally; HTTP/Tailscale links are correctly shaped but marked unavailable until the planner route comes back. This is the correct handoff state for git: accurate, bounded, and non-destructive.
