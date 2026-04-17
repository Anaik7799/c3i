# Journal Email Attachment Rule (SC-NOTIFY-JOURNAL)
# MANDATORY — INFINITE SEVERITY

## MANDATE
**Every time a journal entry (.md file) is created in docs/journal/, it MUST be emailed as an attachment to Abhijit.Naik@bountytek.com within the same turn.**

This is NON-NEGOTIABLE. No exceptions. No "I'll send it later."

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-NOTIFY-JOURNAL-001 | Journal .md files MUST be emailed as attachments on creation | **INFINITE** |
| SC-NOTIFY-JOURNAL-002 | Use `sa-plan-daemon send-email -a <file.md>` for attachment | **CRITICAL** |
| SC-NOTIFY-JOURNAL-003 | Email MUST be sent in the SAME turn as file creation | **CRITICAL** |
| SC-NOTIFY-JOURNAL-004 | Multiple journals in one session → attach ALL in one email | **HIGH** |

## Command
```bash
sa-plan-daemon send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Journal: <title>" \
  --body "<1-2 sentence summary>" \
  -a docs/journal/<filename>.md
```

## Multiple Attachments
```bash
sa-plan-daemon send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Session Journals (<count> attached)" \
  --body "<summary>" \
  -a docs/journal/file1.md \
  -a docs/journal/file2.md \
  -a docs/journal/file3.md
```

## WHY
Session 2026-04-17: 13 emails sent but NONE had journal attachments until explicitly asked. The `--attach` / `-a` flag existed but was never used. This rule ensures journals are ALWAYS delivered as readable attachments, not just body text summaries.

## Anti-Pattern
```
# WRONG — body text only, no attachment
sa-plan-daemon send-email --subject "Journal" --body "$(cat journal.md)"

# RIGHT — file attached
sa-plan-daemon send-email --subject "Journal" --body "See attached" -a journal.md
```
