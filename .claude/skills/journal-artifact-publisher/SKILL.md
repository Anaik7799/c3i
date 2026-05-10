---
name: journal-artifact-publisher
description: Use when creating, reviewing, publishing, staging, or handing off C3I journal artifact bundles with Markdown journals, operator HTML reports, slide-deck HTML, email drafts or sa-plan send-email payloads, links manifests, handoff indexes, Zettelkasten ingestion, sa-plan task creation/update/sync/status evidence, PROJECT_TODOLIST synchronization, workflow/job/schedule evidence, L0-L7 fractal closure, and optional upload planning. Enforces Rust/Gleam-only publication tooling: use `sa-plan`, Rust validators, Gleam/static surfaces, and shell only as command glue; never use Python/Node ad hoc scripts.
---

# Journal Artifact Publisher

## Mandate

Create complete, task-linked C3I publication bundles using Rust/Gleam-only tooling. Static Markdown, JSON, and self-contained HTML are allowed outputs. Do not create Python/Node helper scripts for publication logic.

## Required Bundle

Every publication bundle must include:

1. Markdown journal: `*-journal.md` using the 13-section journal protocol.
2. Operator HTML report: `*-analysis.html`.
3. Slide deck HTML: `*-deck.html`.
4. Email draft: `*-email.md` with attachment list and optional `sa-plan send-email` command.
5. Operator handoff index: `*-index.html` linking all bundle artifacts.
6. Links manifest: `task-<id>-links.json` or task-local `links.json`.
7. sa-plan evidence: task ID, URN, priority, status, status/sync/update command evidence, and any degraded-mode notes.
8. Fractal closure evidence when the operator claims full closure, all issues, all blocked items, or L0-L7/component coverage.

## Required Workflow

1. Create or identify the authoritative sa-plan task:
   - `./sa-plan add "<title>" <P0|P1|P2|P3>`
   - record returned task ID and URN.
   - if `sa-plan` is unavailable, record exact command, timestamp, failure, and use an existing task only if it is already evidenced in a manifest or journal.
2. Move the task to `in_progress` before writing artifacts when possible:
   - `./sa-plan update <task-id> in_progress`
3. Create the artifact bundle under `docs/journal/`.
4. Use the 13-section journal protocol for detailed entries.
5. Include local paths, relative links, localhost route, customer Tailscale route, and internal HTTPS route in the links manifest.
6. Validate every local path in the manifest exists.
7. Validate the JSON manifest with `jq empty`.
8. Validate HTML links by checking every local artifact target exists; mark remote URL status as `verified`, `expected`, or `unavailable`, never implied.
9. Run `./sa-plan status`, `./sa-plan sync`, and `./sa-plan ingest-docs --dry-run` when the daemon/database is available.
10. Run full `./sa-plan ingest-docs` only when durable ingestion is requested or existing task evidence shows durable ingestion is part of the closure.
11. Prepare `./sa-plan send-email` with all required attachments; send only when a recipient is explicit or a higher-priority local rule requires a known operator recipient.
12. If upload is requested, use `./sa-plan gdrive-upload`; otherwise mark upload/GDrive as skipped and do not touch `gdrive/`.
13. Before staging, run `git status --short` and stage only bundle/rule/skill/agent/command files belonging to this pass.

## Task-Management Integration

Full integration means recording:

- `sa-plan add`, `update`, `status`, `sync`, `ingest-docs --dry-run`, and optional `ingest-docs` command evidence.
- `PROJECT_TODOLIST.md` sync state or the exact failure that prevented sync.
- task ID, URN, priority, status, owner/operator, parent/related task IDs if known.
- durable workflow/scheduler/job references when the bundle summarizes workflow work: `workflow-start`, `workflow-describe`, `workflow-list`, `schedule-list`, `job-list`, `queue-list`.
- ZK/RAG references when knowledge integration is relevant: `zk-recall`, `knowledge-search`, `count-citations`, `ingest-docs`.
- degraded-mode handling when the planning DB, daemon, network, or route service is unavailable.

## Artifact Contract

Read `references/artifact-contract.md` before creating or reviewing bundle contents.

Read these focused references as needed:

- `references/journal-template.md` for the 13-section Markdown journal.
- `references/html-report.md` for the operator report and handoff index.
- `references/slide-deck.md` for scrollable HTML decks.
- `references/email-payload.md` for email drafts, attachments, and send gates.
- `references/sa-plan-workflow.md` for task, workflow, ingest, email, and upload command evidence.
- `references/link-validation.md` for local, relative, localhost, customer, and internal route checks.
- `references/task-management-integration.md` for plan/task/workflow/job/scheduler evidence mapping.
- `references/fractal-closure-checklist.md` for L0-L7 layers, component closure, multilayer supervision, and full-closure claim semantics.

## Verification

```bash
cd /home/an/dev/ver/c3i
jq empty docs/journal/task-<id>-links.json
for f in docs/journal/<slug>-journal.md docs/journal/<slug>-analysis.html docs/journal/<slug>-deck.html docs/journal/<slug>-email.md docs/journal/<slug>-index.html docs/journal/task-<id>-links.json; do
  test -f "$f" || exit 1
done
rg -n "href=\"[^\"]+\"" docs/journal/<slug>-analysis.html docs/journal/<slug>-deck.html docs/journal/<slug>-index.html
./sa-plan status
./sa-plan sync
./sa-plan ingest-docs --dry-run
```

If route checks are requested:

```bash
/usr/bin/curl -k -fsS "http://127.0.0.1:4200/task-id/<id>/<file>" >/dev/null
/usr/bin/curl -k -fsS "https://vm-1.tail55d152.ts.net/c3i/task-id/<id>/<file>" >/dev/null
```

Record `curl` failure as route unavailable; do not convert it into success by assumption.

## Git Add Boundary

Before and after staging, verify:

```bash
git diff --cached --name-only | rg '(^|/)gdrive(/|$)' && exit 1 || true
git diff --cached --check
git diff --cached --name-only
```

## Guardrails

- Do not bulk commit or stage unrelated dirty files.
- Do not touch `gdrive/` unless the operator explicitly asks for upload/sync.
- Do not send email without a concrete recipient unless a higher-priority local rule names the recipient.
- Do not claim public/Tailscale links are live unless the route was verified during this pass.
- Do not use Python/Node helper scripts; use Rust `sa-plan`, Gleam server/routes, static artifacts, and shell command glue.
- Preserve tool identity: Claude surfaces stay Claude-specific, Gemini surfaces stay Gemini-specific, `.agents` surfaces stay provider-neutral.
- When claiming all issues or all blocked items are fixed, separate verified closure from known warnings, quality-score gaps, expected routes, skipped email, and skipped uploads.
