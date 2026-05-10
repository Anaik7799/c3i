# Autonomous OODA Enforcement (SC-OODA-CLAUDE)
# स्वायत्त ऊडा प्रवर्तन

## MANDATE
**Claude MUST operate in continuous OODA loops. Every action follows: Observe -> Orient -> Decide -> Act -> Verify.**
This is NOT optional. The hooks ENFORCE observation. The rules ENFORCE orientation. Claude DECIDES and ACTS.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-OODA-CLAUDE-001 | Claude MUST observe system state before acting (SessionStart hook) | CRITICAL |
| SC-OODA-CLAUDE-002 | Claude MUST orient via Zettelkasten recall (UserPromptSubmit hook) | CRITICAL |
| SC-OODA-CLAUDE-003 | Claude MUST decide using NIF compute, not manual reasoning | HIGH |
| SC-OODA-CLAUDE-004 | Claude MUST act autonomously on non-L0 changes (Gita protocol) | HIGH |
| SC-OODA-CLAUDE-005 | Claude MUST verify via gleam test after every change | CRITICAL |
| SC-OODA-CLAUDE-006 | Claude MUST learn — ingest findings to Zettelkasten (Stop hook) | CRITICAL |

## OODA Budget (per cycle)
| Phase | Budget | Tool | Enforcement |
|-------|--------|------|-------------|
| Observe | <3s | SessionStart hook + /observe | AUTOMATIC |
| Orient | <5s | UserPromptSubmit hook (ZK search) | AUTOMATIC |
| Decide | <2s | Gleam NIF compute | Claude must call |
| Act | varies | Code changes | Claude executes |
| Verify | <30s | PostToolUse hook (build+test) | AUTOMATIC |
| Learn | <10s | Stop hook (ingest) | AUTOMATIC |

## Autonomous Action Classification
| Action | Autonomous? | Enforcement |
|--------|:-----------:|-------------|
| Read files | YES | No approval needed |
| Edit .gleam files | YES | Auto-build + auto-test hooks verify |
| Run gleam build/test | YES | Always allowed |
| Search Zettelkasten | YES | Hook does it automatically |
| Create rules | YES | /learn-rule command |
| Render diagrams | YES | /render command |
| Send email | YES | SC-NOTIFY |
| Ingest to ZK | YES | Stop hook does it automatically |
| L0 Constitutional changes | ASK | Guardian approval required |
| Delete files | ASK | SC-DELETE-001 |
| Push to remote | ASK | Shared state |

## Biomorphic Properties
| Property | How Claude Exhibits It |
|----------|----------------------|
| Homeostasis | Dark Cockpit — suppress noise when healthy |
| Metabolism | Context window = energy. Compact = digest. ZK = store fat. |
| Growth | Test count increases. Holon count increases. Rule count increases. |
| Response | UserPromptSubmit hook < 8s. PostToolUse hook < 30s. |
| Adaptation | /learn-rule creates new rules from session findings |
| Evolution | Each session starts smarter (ZK recall of prior patterns) |
| Reproduction | Templates generate pages. Tests verify. Rules guide. |
