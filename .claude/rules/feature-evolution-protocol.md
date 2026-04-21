# Feature Evolution Protocol (SC-FEAT-EVO)
# विशेषता विकास प्रोतोकॉल

## SUPREME MANDATE
**Every new feature MUST go through the fractal evolution pipeline. No feature is complete until dashboard, tests, journal, SVG diagrams, and email are all delivered.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FEAT-EVO-001 | Every feature MUST have regression tests before marking complete | CRITICAL |
| SC-FEAT-EVO-002 | Every feature MUST update KPI dashboard at https://vm-1.tail55d152.ts.net:4200/kpi | HIGH |
| SC-FEAT-EVO-003 | Every feature MUST have a 13-section journal entry (.md) | HIGH |
| SC-FEAT-EVO-004 | Journal MUST be emailed as attachment to Abhijit.Naik@bountytek.com | CRITICAL |
| SC-FEAT-EVO-005 | HTML dashboard MUST be served on sa-plan-daemon port 4200 | HIGH |
| SC-FEAT-EVO-006 | Full regression (1302+ tests) MUST pass before marking complete | CRITICAL |
| SC-FEAT-EVO-007 | Feature knowledge MUST be ingested to Zettelkasten | HIGH |
| SC-FEAT-EVO-008 | Tailscale link MUST be included in email | MEDIUM |
| SC-FEAT-EVO-009 | Task page MUST have inline SVG diagrams (architecture, message sequence, state machine) | HIGH |
| SC-FEAT-EVO-010 | All generated HTML/MD links MUST be stored in ZK for dynamic discovery | HIGH |
| SC-FEAT-EVO-011 | Task page URL: https://vm-1.tail55d152.ts.net:4200/task-id/{task_id}/{filename} | CRITICAL |
| SC-FEAT-EVO-012 | Full prompt summary MUST be embedded in the task page | HIGH |
| SC-FEAT-EVO-013 | Screenshots MUST be captured and verified against spec | HIGH |

## Pipeline Steps (executed EVERY time a new feature is implemented)

1. **Implement** — Write the feature code
2. **Test** — Create regression + DAG scenario tests
3. **Diagrams** — Create inline SVG diagrams:
   - Architecture (control plane, data plane, modules)
   - Message sequence (numbered steps)
   - State machine (states + transitions)
   - Fractal structure (L0-L7 layers impacted)
4. **Dashboard** — Update KPI HTML with new metrics
5. **Journal** — Write 13-section journal entry (.md)
6. **Task Page** — Create/update HTML at /task-id/{task_id}/
   - Embed full prompt summary
   - Include all SVG diagrams inline
   - Link to journal .md and all HTML files
   - Include FMEA, analytics, coverage data
7. **Screenshot** — Capture PNG with Chromium headless, verify alignment
8. **Email** — Send journal + Tailscale task link
9. **Regress** — Run ALL test suites (must be green)
10. **Ingest** — Store links + knowledge in Zettelkasten
11. **Verify** — Confirm page accessible via Tailscale
12. **Fractal-Criticality Matrix** — Generate L0-L7 × components × RETE-UL/ruliology × STAMP × FMEA/FEMA matrix and execute in P0→P3 order (SC-FRAC-RRF-001..010).

## URL Pattern
```
https://vm-1.tail55d152.ts.net:4200/task-id/{task_id}           → Task index (SVG, prompt, files)
https://vm-1.tail55d152.ts.net:4200/task-id/{task_id}/{file.md} → Journal rendered as HTML
https://vm-1.tail55d152.ts.net:4200/task-id/{task_id}/{file.html} → HTML served directly
```

## SVG Diagram Requirements
Every task page MUST include these inline SVGs:
1. **Architecture** — Modules, connections, data flow (boxes + arrows)
2. **Control Plane** — CLI → dispatch → handlers → response
3. **Data Plane** — HTTP → axum → API → DB → response
4. **Message Sequence** — Numbered client-server interactions
5. **State Machine** — States + transitions with labels
6. **Fractal Structure** — L0-L7 layers with coverage bars

## ZK Link Storage
After creating any HTML or MD file:
```bash
sa-plan-daemon knowledge-search "task page <task_id>"  # Check if exists
# If new, ingest:
sa-plan-daemon ingest-docs
```

## Email Command
```bash
sa-plan-daemon send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Feature: <name> — <test_count> tests, 0 failures" \
  --body "Task Page: https://vm-1.tail55d152.ts.net:4200/task-id/<task_id>" \
  -a docs/journal/<journal_file>.md
```

## Screenshot Command
```bash
chromium --headless --no-sandbox --screenshot=/tmp/screenshots/<name>.png \
  --window-size=1400,900 http://localhost:4200/task-id/<task_id>
```
