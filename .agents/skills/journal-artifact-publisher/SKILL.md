---
name: journal-artifact-publisher
description: .agents/Codex-compatible skill for creating, validating, staging, and handing off C3I journal bundles with Markdown journal, HTML analysis, slide deck, email draft/send payload, handoff index, links manifest, sa-plan/task/workflow integration, and L0-L7 fractal closure evidence. Enforces Rust/Gleam-only publication tooling: `sa-plan`, Rust/Gleam validators, static artifacts, and shell glue only; no Python/Node helpers.
---

# Journal Artifact Publisher

## Required Outputs

- Markdown journal using the C3I 13-section protocol.
- Self-contained HTML analysis report.
- Scrollable HTML slide deck.
- Email draft with subject, recipients/placeholders, attachment list, and send gate.
- Operator handoff index HTML linking every local artifact.
- Links manifest with local paths, relative links, expected routes, and validation status.
- sa-plan task ID, URN, priority, status, sync/status/ingest evidence, and degraded-mode notes.
- L0-L7 fractal closure matrix when claiming full closure, all issues fixed, all blocked items fixed, or multilayer supervision.

## Workflow

1. Work from `/home/an/dev/ver/c3i`.
2. Create or reuse a real sa-plan task with `./sa-plan add "<title>" P1`; if unavailable, record the exact failure.
3. Move the task through `in_progress` and `completed` with `./sa-plan update` when possible.
4. Write artifacts under `docs/journal/`; do not touch `gdrive/`.
5. Use the canonical Claude references for bundle contracts:
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/artifact-contract.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/journal-template.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/html-report.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/slide-deck.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/email-payload.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/sa-plan-workflow.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/link-validation.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/task-management-integration.md`
   - `/home/an/dev/ver/c3i/.claude/skills/journal-artifact-publisher/references/fractal-closure-checklist.md`
6. Validate local files and `jq empty` on the manifest.
7. Validate links as local file targets plus route status: `verified`, `expected`, or `unavailable`.
8. Run `./sa-plan status`, `./sa-plan sync`, and `./sa-plan ingest-docs --dry-run` when available.
9. Prepare `./sa-plan send-email`; send only with explicit recipient or higher-priority local notification rule.
10. Stage only requested bundle/rule/skill/agent/command files.

## Fractal Closure Gate

When the user asks for "all issues", "all blocked items", "full fractal layers", "fractal components", or "multilayer supervisors":

- Include an L0-L7 matrix in the journal and HTML report.
- Include every publication component: journal, report, deck, email, index, manifest.
- Distinguish verified current-pass evidence from historical evidence.
- Record warnings, quality scores, route checks, send gates, and skipped uploads as explicit gaps instead of hiding them.
- Do not invent running supervisors; name reviewer responsibilities by layer unless actual agents were launched and reported.

## Hard Rules

- Rust/Gleam-only publication tooling.
- No Python or Node helper scripts.
- No bulk commit/stage of unrelated dirty files.
- No `gdrive/` changes unless explicitly requested.
- Do not claim live public links unless route checks passed in this turn.
- If `sa-plan` fails, record degraded-mode evidence and keep current-pass task claims false.
