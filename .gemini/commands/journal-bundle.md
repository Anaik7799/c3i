---
description: Gemini journal bundle command for journal, HTML, slides, email, handoff index, links, and sa-plan/task-management integration.
---

# Journal Bundle

Use `.gemini/skills/journal-artifact-publisher/SKILL.md`.

Rust/Gleam-only flow:

```bash
cd /home/an/dev/ver/c3i
./sa-plan add "<bundle title>" P1
./sa-plan update <task-id> in_progress
./sa-plan status
./sa-plan sync
./sa-plan ingest-docs --dry-run
```

Create:

- `docs/journal/<slug>-journal.md`
- `docs/journal/<slug>-analysis.html`
- `docs/journal/<slug>-deck.html`
- `docs/journal/<slug>-email.md`
- `docs/journal/<slug>-index.html`
- `docs/journal/task-<id>-links.json`

Do not send email without explicit recipient or higher-priority local notification rule. Do not touch `gdrive/` unless requested.

Before closure, reject any staged `gdrive/` path:

```bash
git diff --cached --name-only | rg '(^|/)gdrive(/|$)' && exit 1 || true
```
