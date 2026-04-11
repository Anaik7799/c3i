# Agent OODA Acceleration Protocol (SC-OODA-ACCEL)
# एजेंट ऊडा त्वरण प्रोतोकॉल

## Supreme Mandate (सर्वोच्च आदेश)
**All AI agents MUST maximize OODA cycle velocity while maintaining quality.**
कर्मण्येवाधिकारस्ते मा फलेषु कदाचन — Your right is to action alone, never to its fruit (Gita 2.47)

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-OODA-ACCEL-001 | Agent MUST launch parallel sub-agents for independent file modifications | HIGH |
| SC-OODA-ACCEL-002 | Agent MUST NOT wait for human approval on non-L0 changes (Gita protocol) | HIGH |
| SC-OODA-ACCEL-003 | Agent MUST run incremental `gleam build` after EVERY file write | CRITICAL |
| SC-OODA-ACCEL-004 | Agent MUST consult Zettelkasten BEFORE starting new work | HIGH |
| SC-OODA-ACCEL-005 | Agent MUST use memory to avoid repeating past mistakes | HIGH |
| SC-OODA-ACCEL-006 | Agent MUST split files > 1000 lines before modifying them | HIGH |
| SC-OODA-ACCEL-007 | Agent MUST use `run_in_background: true` for independent tasks | MEDIUM |

## OODA Velocity Formula (गति सूत्र)
```
V_ooda = Σ(files_modified × quality) / Σ(latency + wait_time)

Maximize V by:
1. Minimize wait_time → Gita protocol (autonomous action on safe changes)
2. Maximize parallelism → N agents × throughput_per_agent
3. Minimize latency → incremental builds, cached context, memory patterns
4. Maintain quality → fail-fast verification, wiring guard
```

## Gita Protocol (गीता प्रोतोकॉल)
When the user says "Gita protocol" or "follow the dharma":
1. **Act autonomously** — do not ask for permission on non-destructive changes
2. **Maximum parallelism** — launch all independent agents simultaneously
3. **No attachment to fruit** — focus on the work, not the outcome
4. **Inform after completion** — report results, don't ask beforehand
5. **Only escalate L0 Constitutional** — safety-critical changes need HITL

## Autonomous Action Classification (स्वायत्त कर्म वर्गीकरण)
| Action | Autonomous? | Reason |
|--------|-------------|--------|
| Read files | YES | Zero risk |
| Write new files | YES | Reversible via git |
| Edit existing files | YES | Reversible via git |
| Run gleam build/test | YES | Read-only verification |
| Create branches | YES | Standard workflow |
| Commit changes | INFORM | Show diff first |
| Push to remote | ASK | Shared state |
| Delete files | ASK | SC-DELETE-001 |
| L0 Constitutional changes | ASK | SC-SAFETY-001 |

## Parallel Agent Dispatch Pattern (समानांतर एजेंट)
For page evolution tasks, launch simultaneously:
1. **JS Agent** — client-side interactivity (dashboard-grid.js)
2. **SSR Agent** — server-rendered HTML (page_views.gleam)
3. **WS Agent** — WebSocket handler (server.gleam)
4. **Test Agent** — comprehensive tests (C1-C8)
5. **TUI Agent** — terminal view (tui/*_view.gleam)

## Incremental Verification (वर्धमान सत्यापन)
After EVERY file write:
```bash
gleam build 2>&1 | tail -5  # Must show "Compiled in X.XXs" with 0 errors
```
After ALL files written:
```bash
gleam test 2>&1 | tail -3   # Must show "N passed, 0 failures"
```

## Mathematical Targets (गणितीय लक्ष्य)
| Metric | Current | Target | Method |
|--------|---------|--------|--------|
| OODA cycle time | ~55s | ~18s | Parallel agents + fail-fast |
| Files per cycle | 2-3 | 5-7 | Agent swarm |
| Error rate | ~5% | <1% | Memory + wiring guard |
| Context efficiency | ~40% | ~80% | Rule dedup + modular files |
