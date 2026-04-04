---
name: sentinel
description: Sentinel health monitoring — system health, threats, bridge status via MCP
---
---

# Sentinel Health Monitor (SC-IMMUNE-001 to SC-IMMUNE-010)

Digital T-Cell immune system monitoring via native MCP bridge.

## Usage
```
/sentinel health        # Get current system health score (0-100)
/sentinel threats       # List active threats with severity
/sentinel status        # Full bridge status (Zenoh + Sentinel + FFI)
/sentinel monitor       # Continuous monitoring cycle with Zenoh telemetry
/sentinel watch         # Subscribe to real-time threat alerts
```

## Commands

### Health Check (SC-IMMUNE-001)
`sentinel(action: "health")` — Returns:
- Health score (0-100)
- Circuit breaker state
- Memory/CPU utilization
- Error rate calculation
- Quarantine status

### Threat Assessment (SC-IMMUNE-007)
`sentinel(action: "threats")` — Returns:
- Active threat list with severity levels
- Threat scoring (weighted multi-factor per SC-IMMUNE-009)
- Founder's Directive threat status (SC-FOUNDER-007)
- PatternHunter pre-error signatures (SC-BIO-EXT-001)
- SymbioticDefense coordination state

### Bridge Status
`sentinel(action: "status")` — Returns:
- Zenoh FFI bridge connectivity
- Native library loading status (libzenoh_ffi.so)
- Session metrics (27 atomic counters)
- MCP server health
- F# runtime state

### Live Monitoring Workflow
1. Check health: `sentinel(action: "health")`
2. Check threats: `sentinel(action: "threats")`
3. Subscribe to alerts: `zenoh_sub(action: "subscribe", key: "indrajaal/sentinel/threats")`
4. Poll threat stream: `zenoh_sub(action: "poll", id: "{id}", limit: 20)`
5. Query FFI metrics: `zenoh_query(action: "metrics")`
6. Generate health dashboard

### Threat Watch (Real-time)
1. Subscribe: `zenoh_sub(action: "subscribe", key: "indrajaal/sentinel/**")`
2. Poll continuously: `zenoh_sub(action: "poll", id: "{id}")`
3. Correlate with health: `sentinel(action: "health")`
4. Report threat escalation path: green → yellow → orange → red → black

## Immune System Modules
| Module | Role | Key Function |
|--------|------|--------------|
| Guardian | Absolute veto authority | SC-CONST-007 |
| Sentinel | T-Cell health monitoring | SC-IMMUNE-001 |
| PatternHunter | Pre-error detection | SC-IMMUNE-003 |
| SymbioticDefense | Coordinated response | SC-FOUNDER-007 |

## Mathematical Foundation

**Health Score** (weighted multi-factor):

$$H = \frac{\sum_{i} w_i \cdot s_i}{\sum_{i} w_i}$$

where weights $w_i$ and scores $s_i$:

| Factor | Weight $w_i$ | Score $s_i$ |
|--------|-------------|-------------|
| Error rate | 30 | $1 - \min(1, r_{err}/0.5)$ |
| Memory | 20 | $1 - \min(1, m_{used}/m_{total})$ |
| CPU | 15 | $1 - \min(1, c_{sustained}/1.0)$ |
| Queue growth | 10 | $1 - \min(1, q_{growth}/100)$ |
| Recovery | 5 | $r_{success}/r_{total}$ |

**Exponential Decay**: $H(t) = H_0 \cdot e^{-\lambda t}$ — health degrades exponentially without healing

**MTTF**: $\text{MTTF} = \int_0^{\infty} R(t)\, dt = \frac{1}{\lambda}$ — mean time to failure from health trajectory

## Alert Thresholds
| Metric | Yellow | Orange | Red | Black |
|--------|--------|--------|-----|-------|
| Health Score | <80 | <60 | <40 | <20 |
| Error Rate | >5% | >10% | >25% | >50% |
| Memory | >70% | >80% | >90% | >95% |
| Response Time | >100ms | >500ms | >1s | >5s |
