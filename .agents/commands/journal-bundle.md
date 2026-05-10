# Journal Bundle Command

Use `.agents/skills/journal-artifact-publisher/SKILL.md`.

Required artifacts:

- Markdown journal
- HTML analysis
- HTML slide deck
- email draft
- operator handoff index
- links manifest
- sa-plan task evidence

Use only Rust/Gleam publication tooling:

```bash
cd /home/an/dev/ver/c3i
./sa-plan add "<bundle title>" P1
./sa-plan update <task-id> in_progress
./sa-plan status
./sa-plan sync
./sa-plan ingest-docs --dry-run
```

If a command fails, record the exact failure in the links manifest and journal. Do not touch `gdrive/` unless requested.

Reject staged `gdrive/` paths before closure:

```bash
git diff --cached --name-only | rg '(^|/)gdrive(/|$)' && exit 1 || true
```
