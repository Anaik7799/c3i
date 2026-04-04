---
name: datadog
description: Compare observability stack against Datadog products with live metrics
---
---

# Datadog Comparison Command

Compare Indrajaal observability against Datadog's product suite.

## Usage
```
/datadog all
/datadog apm
/datadog "log management"
/datadog lib/indrajaal/observability/
```

## Datadog Product Categories (47 products)
1. **Infrastructure** (5): Host Maps, Container, Serverless, Network, Cost
2. **APM** (5): APM, Profiler, Database, Data Streams, Service Monitoring
3. **Logs** (5): Log Management, Sensitive Data, Audit Trail, Pipelines, Archives
4. **Digital Experience** (5): RUM, Session Replay, Synthetic, Mobile, Error Tracking
5. **Security** (5): Cloud Posture, App Security, Workload, Composition, Threats
6. **AI/ML** (3): Watchdog, Bits AI, LLM Observability
7. **Collaboration** (3): Dashboards, Notebooks, Incidents
8. **Developers** (4): CI Visibility, Test Visibility, Code Analysis, IDE
9. **Platform** (5): API, Marketplace, Single Pane, Automation, Control
10. **Integrations** (5): Cloud, Containers, Frameworks, Databases, Custom
11. **Service Management** (2): Service Catalog, SLO Monitoring

## Steps
1. Identify target category: $ARGUMENTS
2. Map Indrajaal modules to Datadog products
3. Calculate coverage percentage
4. Identify unique Indrajaal advantages
5. Generate competitive positioning

## Live Metrics Comparison
1. Get Indrajaal health baseline: `sentinel(action: "health")`
2. Query Zenoh metrics: `zenoh_query(action: "metrics")`
3. Compare latency/throughput against Datadog benchmarks

## Mathematical Foundation

**SLA Comparison**: $\frac{A_{indrajaal}}{A_{datadog}}$ where $A = \frac{MTBF}{MTBF + MTTR}$

**Latency Percentiles**: $P_{99} = F^{-1}(0.99)$ from Zenoh telemetry histogram

**TCO Model**: $TCO = C_{license} + C_{infra} + C_{ops} + C_{opportunity}$

**Feature Coverage**: $\mathcal{F} = \frac{|\text{Indrajaal features} \cap \text{Datadog features}|}{|\text{Datadog features}|}$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-OBS-069 | Dual Log (Term+Zenoh) |
| SC-OBS-071 | 4 OTEL modules |
| SC-PRF-050 | Response < 50ms |

## Output
- Feature matrix with coverage %
- Gap analysis (critical, high, medium)
- Live Sentinel health comparison
- Unique advantages (Constitutional AI, Zenoh mesh, etc.)
- Cost comparison (85% TCO savings)
- Build vs buy recommendations
