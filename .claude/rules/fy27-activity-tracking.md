# FY27 Activity Tracking Protocol (SC-FY27-TRACK)

## SUPREME MANDATE
**EVERY activity, task, meeting, note, call, email, decision, and insight MUST be logged to the Zettelkasten. The ZK is the single source of truth for instantaneous status at any moment.**

Nothing happens off-the-record. If it's not in ZK, it didn't happen.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FY27-TRACK-001 | ALL activities MUST be logged to activity log before session ends | CRITICAL |
| SC-FY27-TRACK-002 | ALL meetings MUST have pre-brief (from ZK) and post-brief (to ZK) | CRITICAL |
| SC-FY27-TRACK-003 | ALL deal status changes MUST be logged with reason | HIGH |
| SC-FY27-TRACK-004 | ALL contact interactions MUST be logged with outcome | HIGH |
| SC-FY27-TRACK-005 | ALL decisions MUST be logged with rationale and alternatives considered | HIGH |
| SC-FY27-TRACK-006 | Activity log MUST be importable to both FY27-ZK and C3I-ZK | HIGH |
| SC-FY27-TRACK-007 | Status query MUST return current state within 5 seconds | MEDIUM |
| SC-FY27-TRACK-008 | Weekly activity summary MUST be generated every Friday | HIGH |

## Activity Categories
| Category | Tag | Examples |
|----------|-----|---------|
| Meeting | meeting | Customer call, internal review, QBR, demo |
| Email | email | Outreach sent, reply received, introduction |
| LinkedIn | linkedin | Connection request, message, post engagement |
| Call | call | Discovery call, follow-up, reference call |
| Deal Update | deal | Stage change, new opportunity, closed-won/lost |
| Contact | contact | New contact added, relationship change, org map update |
| Task | task | Action item created, completed, blocked |
| Decision | decision | Pricing decision, go/no-go, resource allocation |
| Intel | intel | Competitive intel, market news, customer insight |
| Note | note | Observation, idea, pattern, anti-pattern |
| Proposal | proposal | SOW drafted, proposal sent, pricing submitted |
| Event | event | Conference, trade show, dinner, workshop |
| Internal | internal | Team sync, forecast call, strategy session |
| Escalation | escalation | Risk escalated, exec engagement requested |

## Activity Log Location
All activity files live under FY27-Plan/activities/ and are auto-imported to ZK:
- Daily logs: activities/YYYY-MM-DD-activity-log.md (append-only)
- Meeting notes: activities/meetings/YYYY-MM-DD-account-topic.md
- Decision records: activities/decisions/YYYY-MM-DD-topic.md

## Activity Entry Format
Each entry in the daily log:

### HH:MM -- [CATEGORY] Title
- **Account**: (if applicable)
- **Contacts**: (names from ZK)
- **Action**: What happened
- **Outcome**: Result or next step
- **Follow-up**: Due date and owner
- **Tags**: category, account, topic

## Auto-Import Protocol
After ANY activity is logged:
1. Run FY27-ZK import: cd $ZK_DIR && $ZK import ..
2. Run C3I-ZK ingest: MCP tool knowledge_ingest
3. Both ZKs now have the latest state

## Meeting Protocol

### Pre-Meeting (5 min before)
Run /fy27-zk-brief with account name and contact names.
Review: last interaction, open actions, deal status, relationship score.

### During/After Meeting
Log key points: decisions made, action items, new intel, competitive mentions, next steps.

### Post-Meeting (within 1 hour)
Run /fy27-log meeting account "summary" to create structured meeting record.

## Weekly Activity Summary (every Friday)
Run /fy27-weekly-rhythm to auto-generate:
- Activities by category (count + details)
- Meetings held (with outcomes)
- Deals progressed (stage changes)
- New contacts added
- Decisions made
- Open action items (overdue flagged)
- Next week's planned activities
