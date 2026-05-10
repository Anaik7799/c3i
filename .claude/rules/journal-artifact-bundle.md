# Journal Artifact Bundle Rule

Any requested journal publication bundle must include Markdown journal, HTML analysis, HTML slide deck, email draft, operator handoff index, links manifest, and sa-plan task-management integration.

## Constraints

- Use Rust/Gleam-only publication tooling: `sa-plan`, Rust/Gleam validators, Gleam/static routes, and shell command glue.
- Do not use Python/Node helper scripts for bundle creation.
- Create or reuse a real sa-plan task and record task ID + URN.
- Move task status through `in_progress` and `completed` when the planner is available.
- Validate all local artifact paths before claiming links are correct.
- Validate route links separately; mark remote/customer links as `verified`, `expected`, or `unavailable`.
- Run `./sa-plan status`, `./sa-plan sync`, and `./sa-plan ingest-docs --dry-run` when available; record exact failures when not available.
- Preserve separate historical evidence and current-pass evidence when planner or route checks are degraded.
- Record workflow/job/schedule evidence when a bundle summarizes plan or task-management system work.
- Do not touch `gdrive/` unless upload/sync is explicitly requested.
- Do not send email without explicit recipient unless a higher-priority local notification rule names the recipient.
- Stage only files belonging to the bundle/rule/skill/agent/command pass.
- Reject staged paths matching `(^|/)gdrive(/|$)`.
