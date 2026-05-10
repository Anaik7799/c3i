---
description: Create and publish a C3I journal bundle with journal, HTML, slides, email, handoff index, links, and sa-plan/task-management integration.
---

# Journal Bundle

Use `.claude/skills/journal-artifact-publisher/SKILL.md`.

Required Rust/Gleam-only flow:

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

Validate:

```bash
jq empty docs/journal/task-<id>-links.json
test -f docs/journal/<slug>-journal.md
test -f docs/journal/<slug>-analysis.html
test -f docs/journal/<slug>-deck.html
test -f docs/journal/<slug>-email.md
test -f docs/journal/<slug>-index.html
git diff --cached --name-only | rg '(^|/)gdrive(/|$)' && exit 1 || true
```

Send only with explicit recipient or higher-priority notification rule:

```bash
./sa-plan send-email --to "<recipient>" \
  --subject "<subject>" \
  --body "$(cat docs/journal/<slug>-email.md)" \
  -a docs/journal/<slug>-journal.md \
  -a docs/journal/<slug>-analysis.html \
  -a docs/journal/<slug>-deck.html \
  -a docs/journal/<slug>-index.html \
  -a docs/journal/task-<id>-links.json
```
