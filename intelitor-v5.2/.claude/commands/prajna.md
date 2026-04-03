---
description: Prajna C3I cockpit — health dashboard, threat monitoring, Guardian proposals via MCP
allowed-tools: mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_query, mcp__sentinel-zenoh__zenoh_sub, mcp__sentinel-zenoh__zenoh_pub, Read, Grep, Glob, Bash(curl:*)
argument-hint: [health|threats|guardian|copilot|metrics|dashboard]
---

# Prajna C3I Command Cockpit (SC-PRAJNA-001 to SC-PRAJNA-005)

Unified command-and-control interface for system health, threat monitoring, and AI-assisted operations.

## Usage
```
/prajna health         # System health dashboard with Sentinel
/prajna threats        # Active threat assessment
/prajna guardian       # Guardian proposal queue
/prajna copilot        # AI Copilot recommendations
/prajna metrics        # KPI dashboard
/prajna dashboard      # Full cockpit view
```

## Health Dashboard
1. Sentinel health: `sentinel(action: "health")`
2. Threat scan: `sentinel(action: "threats")`
3. Zenoh metrics: `zenoh_query(action: "metrics")`
4. Bridge status: `sentinel(action: "status")`
5. Web health: `curl -sf http://localhost:4000/api/health`
6. Prajna metrics: `curl -sf http://localhost:4000/api/prajna/metrics`

## Threat Monitoring
1. Subscribe: `zenoh_sub(action: "subscribe", key: "indrajaal/sentinel/**")`
2. Poll threats: `zenoh_sub(action: "poll", id: "{id}", limit: 20)`
3. Correlate with health score
4. Generate threat escalation report

## Guardian Proposals
1. Query pending: `zenoh_query(action: "get", key: "indrajaal/guardian/proposals")`
2. Validate proposal: `sentinel(action: "health")` — check system stable enough for change
3. Publish verdict: `zenoh_pub(key: "indrajaal/guardian/verdict", payload: "{json}")`

## Mathematical Foundation

**Health Score Aggregation**: $H_{prajna} = \frac{\sum_{i} w_i \cdot H_i}{\sum_{i} w_i}$ across all subsystems

**Threat Priority**: $P = \frac{S \times O}{D}$ — severity times occurrence over detectability

**SLA Compliance**: $SLA = \frac{t_{healthy}}{t_{total}} \times 100\%$ — percentage time in healthy state

**Decision Latency**: $L_{decision} = L_{observe} + L_{orient} + L_{decide} + L_{act} < 30s$ (OODA cycle)

## Prajna Web Pages
| Page | URL | Purpose |
|------|-----|---------|
| Main | /prajna | Health score, threats, agents |
| Copilot | /prajna/copilot | AI assistant chat |
| Alarms | /prajna/alarms | Alarm management |
| Access | /prajna/access_control | Permission audit |
| Analytics | /prajna/analytics | Report metrics |
| Compliance | /prajna/compliance | Audit trail |
| Devices | /prajna/devices | Health matrix |
| Video | /prajna/video | Stream health |

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-PRAJNA-001 | Guardian gate for commands |
| SC-PRAJNA-002 | Copilot aligns with Founder's Directive |
| SC-PRAJNA-003 | State mutations logged to Register |
| SC-PRAJNA-004 | SmartMetrics sync with Sentinel 30s |
| SC-PRAJNA-005 | Two-step commit for destructive actions |
