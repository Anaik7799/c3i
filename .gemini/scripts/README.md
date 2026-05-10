# .claude/scripts

Utility scripts for Claude-side operational safeguards.

## `check-pi-constants.sh`

Purpose: prevent documentation drift between `CLAUDE.md` Pi baselines and `.claude/**` artifacts.

### What it does

- Scans:
  - `.claude/rules`
  - `.claude/commands`
  - `.claude/agents`
- Fails if stale constants are found (examples):
  - `currently 87`
  - `Expected: 87 (14 Pi + 73 C3I MCP)`
  - `Bridge modules: 5/5`
  - `all 5 Pi bridge modules`
  - `currently 44`, `44 registered`
- Requires baseline markers to exist:
  - `93 total (6 Claude + 14 Pi + 73 C3I MCP)`
  - `29 Pi events ↔ 32 AG-UI events`

### Run manually

```bash
.claude/scripts/check-pi-constants.sh
```

### Where it runs automatically

1. Local git hook:
   - `.git/hooks/pre-commit`
2. GitHub Actions CI:
   - `.github/workflows/pi-constants-drift-guard.yml`

### Updating baselines safely

When Pi baselines legitimately change:

1. Update `CLAUDE.md` first (authoritative source).
2. Update `.claude` rule/command/agent docs.
3. Update patterns in `check-pi-constants.sh`:
   - move old baseline to **forbidden** list
   - set new baseline in **required** list
4. Run checker locally.
5. Include a parity report under `docs/analysis/`.

This preserves SC-SYNC-DOC parity and prevents stale constants from reappearing.
