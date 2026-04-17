# Incident Severity Matrix

## Severity Levels

| Level | Definition | Response SLA | Escalation | Communication |
|-------|-----------|-------------|------------|---------------|
| **P0** | System outage, data loss risk, safety-critical failure | 15 min | Immediate: founder + all engineers | Telegram + GChat + Email |
| **P1** | Major feature broken, >50% users affected, SLO violated | 1 hour | On-call engineer + backup | Telegram + GChat |
| **P2** | Minor feature broken, workaround available, SLO at risk | 4 hours | On-call engineer | Telegram |
| **P3** | Cosmetic issue, no user impact, degraded experience | Next business day | Backlog | None |
| **P4** | Enhancement, tech debt, optimization | Sprint planning | Backlog | None |

## Classification Criteria

### P0 Triggers (any one = P0)
- Health endpoint returns non-200 for >5 minutes
- Smriti.db corruption or inaccessible
- Zenoh mesh completely disconnected
- SIL-6 safety invariant violated (Psi-0 through Psi-5)
- Data pipeline dead >10 minutes (SC-TRUTH-004)
- Guard grid Jidoka halt triggered

### P1 Triggers
- SLO error budget exhausted (any of 4 SLOs)
- >3 containers unhealthy simultaneously
- Embedding pipeline failure (no semantic search)
- Planning daemon unresponsive
- >50% API endpoints returning errors

### P2 Triggers
- Single container unhealthy with auto-restart working
- SLO error budget >50% consumed
- Non-critical NIF returning stale data
- Single API endpoint degraded

### P3/P4 Triggers
- UI rendering issues, CSS/layout problems
- Performance degradation <20%
- Stale documentation
