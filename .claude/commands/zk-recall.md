# Zettelkasten Recall — Search brain before acting

Before starting work on "$ARGUMENTS", search the Zettelkasten knowledge base for:
1. Prior patterns related to this task
2. Anti-patterns to avoid
3. Related journal entries with RCA findings
4. STAMP constraints that apply

Run these searches:
```bash
sa-plan-daemon knowledge-search "$ARGUMENTS"
sa-plan-daemon knowledge-search "$ARGUMENTS anti-pattern"
sa-plan-daemon knowledge-search "$ARGUMENTS journal RCA"
```

Then:
- Summarize what the Zettelkasten knows about this topic
- List any anti-patterns to avoid
- Identify which prior decisions are still relevant
- Only then proceed with the task

This is SC-ZK-CLAUDE-001: Claude MUST search Zettelkasten BEFORE starting ANY task.
