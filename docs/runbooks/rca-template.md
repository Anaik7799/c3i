# Root Cause Analysis Template

## Incident Summary
- **Incident ID**: INC-YYYY-MM-DD-NNN
- **Severity**: P0/P1/P2
- **Duration**: start_time — end_time (Xh Ym)
- **Impact**: services affected, users affected, data loss
- **Incident Commander**: name

## Timeline
| Time (UTC) | Event | Actor |
|------------|-------|-------|
| HH:MM | First alert fired | Automated |
| HH:MM | IC declared incident | Name |
| HH:MM | Root cause identified | Name |
| HH:MM | Fix deployed | Name |
| HH:MM | Service restored | Automated |
| HH:MM | Monitoring confirmed stable | Name |

## 5 Whys Analysis
1. **Why** did the service fail? → [immediate cause]
2. **Why** did [immediate cause] happen? → [contributing factor]
3. **Why** did [contributing factor] exist? → [systemic issue]
4. **Why** wasn't [systemic issue] caught? → [detection gap]
5. **Why** did [detection gap] exist? → [root cause]

## Root Cause
[Single clear statement of the root cause]

## Contributing Factors
- Factor 1: [description]
- Factor 2: [description]

## Action Items
| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 1 | [prevent recurrence] | name | YYYY-MM-DD | Open |
| 2 | [improve detection] | name | YYYY-MM-DD | Open |
| 3 | [update runbook] | name | YYYY-MM-DD | Open |

## Lessons Learned
- What went well: [detection, response, communication]
- What could improve: [gaps found during incident]
- Action: Ingest to Zettelkasten as anti-pattern holon
